#!/usr/bin/env python3
"""
Template handler for LXC Compose
Handles loading and merging template configurations and library includes
"""

import os
import yaml
from typing import Dict, Any, List

class TemplateHandler:
    def __init__(self, templates_dir: str = '/srv/lxc-compose/templates', 
                 library_dir: str = '/srv/lxc-compose/library'):
        """Initialize template handler with templates and library directories"""
        self.templates_dir = templates_dir
        self.library_dir = library_dir
        
        # Fallback to local directories if system directories not found
        if not os.path.exists(self.templates_dir):
            # Try relative path from CLI directory
            cli_dir = os.path.dirname(os.path.abspath(__file__))
            self.templates_dir = os.path.join(os.path.dirname(cli_dir), 'templates')
        
        if not os.path.exists(self.library_dir):
            cli_dir = os.path.dirname(os.path.abspath(__file__))
            self.library_dir = os.path.join(os.path.dirname(cli_dir), 'library')
    
    def load_template(self, template_name: str) -> Dict[str, Any]:
        """Load a template configuration file"""
        template_file = os.path.join(self.templates_dir, f"{template_name}.yml")
        
        if not os.path.exists(template_file):
            raise ValueError(f"Template not found: {template_name}")
        
        with open(template_file, 'r') as f:
            template_config = yaml.safe_load(f)
        
        # Check if this is an alias template
        if 'alias' in template_config:
            # Load the actual template it points to
            actual_template = template_config['alias']['template']
            return self.load_template(actual_template)
        
        # Return the template configuration
        if 'template' not in template_config:
            raise ValueError(f"Invalid template file: {template_name}")
        
        return template_config['template']
    
    def resolve_template_to_path(self, template_name: str) -> str:
        """Resolve a template name to its library path"""
        # Map template names to library paths
        template_to_path = {
            'alpine-3.19': 'alpine/3.19',
            'alpine': 'alpine/3.19',  # alias
            'ubuntu-24.04': 'ubuntu/24.04',
            'ubuntu-22.04': 'ubuntu/22.04',
            'ubuntu-lts': 'ubuntu/24.04',  # alias
            'ubuntu-noble': 'ubuntu/24.04',  # alias
            'ubuntu-jammy': 'ubuntu/22.04',  # alias
            'ubuntu-minimal-24.04': 'ubuntu-minimal/24.04',
            'ubuntu-minimal-22.04': 'ubuntu-minimal/22.04',
            'ubuntu-minimal-lts': 'ubuntu-minimal/24.04',  # alias
            'ubuntu-minimal-noble': 'ubuntu-minimal/24.04',  # alias
            'ubuntu-minimal-jammy': 'ubuntu-minimal/22.04',  # alias
            'debian-12': 'debian/12',
            'debian-11': 'debian/11',
            'debian-bookworm': 'debian/12',  # alias
            'debian-bullseye': 'debian/11',  # alias
        }
        
        return template_to_path.get(template_name, '')
    
    def load_library_service(self, template_name: str, service_name: str) -> Dict[str, Any]:
        """Load a service configuration from the library"""
        # Resolve template to library path
        template_path = self.resolve_template_to_path(template_name)
        if not template_path:
            raise ValueError(f"Unknown template for library lookup: {template_name}")
        
        # Build path to service config
        service_file = os.path.join(self.library_dir, template_path, service_name, 'lxc-compose.yml')
        
        if not os.path.exists(service_file):
            # Service not found in library
            return None
        
        # Load the service configuration
        with open(service_file, 'r') as f:
            service_config = yaml.safe_load(f)
        
        # Extract the container configuration
        if 'containers' in service_config:
            containers = service_config['containers']
            if isinstance(containers, dict):
                # Return the first container (library services typically have one)
                container = list(containers.values())[0]
                # Store the library service path for test resolution
                if container:
                    container['__library_service_path__'] = os.path.dirname(service_file)
                return container
            elif isinstance(containers, list) and len(containers) > 0:
                container = containers[0]
                # Store the library service path for test resolution
                if container:
                    container['__library_service_path__'] = os.path.dirname(service_file)
                return container
        
        return None
    
    def merge_configs(self, base: Dict[str, Any], overlay: Dict[str, Any]) -> Dict[str, Any]:
        """Merge two configurations with proper ordering"""
        merged = base.copy()
        
        # Handle packages - combine and deduplicate
        if 'packages' in overlay:
            base_packages = merged.get('packages', [])
            for pkg in overlay['packages']:
                if pkg not in base_packages:
                    base_packages.append(pkg)
            merged['packages'] = base_packages
        
        # Handle environment - overlay overrides base
        if 'environment' in overlay:
            if 'environment' not in merged:
                merged['environment'] = {}
            merged['environment'].update(overlay['environment'])
        
        # Handle post_install - append overlay to base
        if 'post_install' in overlay:
            if 'post_install' not in merged:
                merged['post_install'] = []
            merged['post_install'].extend(overlay['post_install'])
        
        # Handle tests - merge with path metadata
        if 'tests' in overlay:
            if 'tests' not in merged:
                merged['tests'] = {}
            
            # Merge each test type
            for test_type in ['internal', 'external', 'port_forwarding']:
                if test_type in overlay['tests']:
                    if test_type not in merged['tests']:
                        merged['tests'][test_type] = []
                    
                    # Add tests with library path metadata if available
                    library_path = overlay.get('__library_service_path__')
                    for test in overlay['tests'][test_type]:
                        if library_path and isinstance(test, str) and ':' in test:
                            # Add library path metadata to test definition
                            test_with_path = f"{test}@library:{library_path}"
                            merged['tests'][test_type].append(test_with_path)
                        else:
                            merged['tests'][test_type].append(test)
        
        # Handle other fields - overlay overrides base
        for key, value in overlay.items():
            if key not in ['packages', 'environment', 'post_install', 'tests', 'template', 'includes', '__library_service_path__']:
                merged[key] = value
        
        # Preserve library path metadata if present
        if '__library_service_path__' in overlay:
            merged['__library_service_path__'] = overlay['__library_service_path__']
        
        return merged
    
    def merge_with_template_and_includes(self, container_config: Dict[str, Any]) -> Dict[str, Any]:
        """Merge container configuration with its template and includes"""
        
        # Start with empty merged config
        merged = {}
        
        # Store the container name if present
        if 'name' in container_config:
            merged['name'] = container_config['name']
        
        # Store template name for container naming
        template_name = container_config.get('template', '')
        
        # Step 1: Apply template if specified
        if 'template' in container_config:
            template_name = container_config['template']
            template = self.load_template(template_name)
            
            # Start with the image from the template
            if 'image' in template:
                merged['image'] = template['image']
            
            # Add template's base packages
            if 'base_packages' in template:
                merged['packages'] = template['base_packages'].copy()
            
            # Add template's environment
            if 'environment' in template:
                merged['environment'] = template['environment'].copy()
            
            # Add template's init commands as post_install
            if 'init_commands' in template:
                merged['post_install'] = []
                for cmd in template['init_commands']:
                    merged['post_install'].append({
                        'name': f"[Template] {cmd.get('name', 'Init command')}",
                        'command': cmd.get('command', '')
                    })
        elif 'image' in container_config:
            # If no template, use image directly
            merged['image'] = container_config['image']
        
        # Step 2: Apply includes (library services)
        if 'includes' in container_config and 'template' in container_config:
            for include in container_config['includes']:
                # Load the library service for this template
                library_service = self.load_library_service(container_config['template'], include)
                
                if library_service:
                    # This is a library service - merge it
                    # Mark included commands for clarity
                    if 'post_install' in library_service:
                        marked_post_install = []
                        for cmd in library_service['post_install']:
                            marked_cmd = cmd.copy()
                            marked_cmd['name'] = f"[{include}] {cmd.get('name', 'Setup')}"
                            marked_post_install.append(marked_cmd)
                        library_service = library_service.copy()
                        library_service['post_install'] = marked_post_install
                    
                    # Remove template/image from library service to avoid conflicts
                    if 'template' in library_service:
                        del library_service['template']
                    if 'image' in library_service:
                        del library_service['image']
                    
                    merged = self.merge_configs(merged, library_service)
                else:
                    # Library service not found - this is an error
                    print(f"Warning: Library service '{include}' not found for template '{container_config['template']}'")
                    # Could raise an error here if we want to be strict
                    # raise ValueError(f"Library service '{include}' not found in library/{self.resolve_template_to_path(container_config['template'])}/")
        
        # Step 3: Apply packages if specified (separate from includes)
        if 'packages' in container_config:
            if 'packages' not in merged:
                merged['packages'] = []
            for pkg in container_config['packages']:
                if pkg not in merged['packages']:
                    merged['packages'].append(pkg)
        
        # Step 4: Apply local configuration (excluding template, includes, and packages which were already handled)
        local_config = container_config.copy()
        for key in ['template', 'includes', 'packages', 'name']:
            if key in local_config:
                del local_config[key]
        
        # Mark local post_install commands
        if 'post_install' in local_config:
            marked_post_install = []
            for cmd in local_config['post_install']:
                marked_cmd = cmd.copy()
                if not cmd.get('name', '').startswith('['):
                    marked_cmd['name'] = f"[Local] {cmd.get('name', 'Setup')}"
                marked_post_install.append(marked_cmd)
            local_config['post_install'] = marked_post_install
        
        merged = self.merge_configs(merged, local_config)
        
        return merged
    
    def process_compose_file(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Process an entire compose file, expanding templates and includes for all containers"""
        
        if 'containers' not in config:
            return config
        
        processed_config = config.copy()
        processed_containers = {}
        
        # Process each container
        containers = config['containers']
        if isinstance(containers, dict):
            for name, container in containers.items():
                # Ensure container has a name field
                if 'name' not in container:
                    container['name'] = name
                
                # Merge with template and includes
                processed_containers[name] = self.merge_with_template_and_includes(container)
        
        elif isinstance(containers, list):
            # Convert list to dict format after processing
            for container in containers:
                name = container.get('name', f'container_{len(processed_containers)}')
                processed_containers[name] = self.merge_with_template_and_includes(container)
        
        processed_config['containers'] = processed_containers
        return processed_config