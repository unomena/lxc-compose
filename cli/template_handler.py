#!/usr/bin/env python3
"""
Template handler for LXC Compose
Handles loading and merging template configurations
"""

import os
import yaml
from typing import Dict, Any, List

class TemplateHandler:
    def __init__(self, templates_dir: str = '/srv/lxc-compose/templates'):
        """Initialize template handler with templates directory"""
        self.templates_dir = templates_dir
        # Fallback to local templates if system templates not found
        if not os.path.exists(self.templates_dir):
            # Try relative path from CLI directory
            cli_dir = os.path.dirname(os.path.abspath(__file__))
            self.templates_dir = os.path.join(os.path.dirname(cli_dir), 'templates')
    
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
    
    def merge_with_template(self, container_config: Dict[str, Any]) -> Dict[str, Any]:
        """Merge container configuration with its template"""
        
        # If no template specified, return as-is (uses image directly)
        if 'template' not in container_config:
            return container_config
        
        # Load the template
        template_name = container_config['template']
        template = self.load_template(template_name)
        
        # Create merged configuration
        merged = {}
        
        # Start with the image from the template
        if 'image' in template:
            merged['image'] = template['image']
        
        # Copy container name and remove template reference
        if 'name' in container_config:
            merged['name'] = container_config['name']
        
        # Don't include the template field in the final config
        container_config_copy = container_config.copy()
        if 'template' in container_config_copy:
            del container_config_copy['template']
        
        # Merge packages: template's base_packages first, then container's packages
        packages = []
        if 'base_packages' in template:
            packages.extend(template['base_packages'])
        if 'packages' in container_config:
            # Add container packages that aren't already in the list
            for pkg in container_config.get('packages', []):
                if pkg not in packages:
                    packages.append(pkg)
        if packages:
            merged['packages'] = packages
        
        # Merge environment variables: template first, then container (container overrides)
        env = {}
        if 'environment' in template:
            env.update(template['environment'])
        if 'environment' in container_config:
            env.update(container_config['environment'])
        if env:
            merged['environment'] = env
        
        # Merge post_install commands: template's init_commands first, then container's post_install
        post_install = []
        
        # Add template's init commands first
        if 'init_commands' in template:
            for cmd in template['init_commands']:
                post_install.append({
                    'name': f"[Template] {cmd.get('name', 'Init command')}",
                    'command': cmd.get('command', '')
                })
        
        # Add container's post_install commands
        if 'post_install' in container_config:
            post_install.extend(container_config['post_install'])
        
        if post_install:
            merged['post_install'] = post_install
        
        # Copy all other container fields (they override or add to template)
        for key, value in container_config_copy.items():
            if key not in ['packages', 'environment', 'post_install', 'name']:
                merged[key] = value
        
        return merged
    
    def process_compose_file(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Process an entire compose file, expanding templates for all containers"""
        
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
                
                # Merge with template if needed
                processed_containers[name] = self.merge_with_template(container)
        
        elif isinstance(containers, list):
            # Convert list to dict format after processing
            for container in containers:
                name = container.get('name', f'container_{len(processed_containers)}')
                processed_containers[name] = self.merge_with_template(container)
        
        processed_config['containers'] = processed_containers
        return processed_config