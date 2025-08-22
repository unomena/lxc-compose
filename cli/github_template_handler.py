#!/usr/bin/env python3
"""
GitHub-based Template Handler for LXC Compose
Fetches templates and services directly from GitHub without caching
"""

import os
import yaml
import subprocess
import tempfile
from typing import Dict, Any, Optional, List
from urllib.parse import urlparse

class GitHubTemplateHandler:
    def __init__(self, 
                 repo_url: str = "https://github.com/unomena/lxc-compose",
                 branch: str = "main"):
        """
        Initialize with GitHub repository details
        
        Args:
            repo_url: GitHub repository URL
            branch: Branch/tag/commit to use
        """
        self.repo_url = repo_url.rstrip('/')
        self.branch = branch
        
        # Extract owner and repo from URL
        parsed = urlparse(repo_url)
        parts = parsed.path.strip('/').split('/')
        self.owner = parts[0] if len(parts) > 0 else "unomena"
        self.repo = parts[1].replace('.git', '') if len(parts) > 1 else "lxc-compose"
    
    def get_github_raw_url(self, path: str) -> str:
        """Generate GitHub raw content URL"""
        return f"https://raw.githubusercontent.com/{self.owner}/{self.repo}/{self.branch}/{path}"
    
    def fetch_from_github(self, path: str) -> Optional[str]:
        """
        Fetch a file from GitHub and return its contents
        
        Args:
            path: Path within the repository
            
        Returns:
            File contents as string, or None if failed
        """
        url = self.get_github_raw_url(path)
        try:
            result = subprocess.run(
                ['curl', '-sL', url],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                content = result.stdout
                # Check if it's a valid response (not 404)
                if '404: Not Found' not in content and '<html>' not in content[:100]:
                    return content
        except (subprocess.TimeoutExpired, subprocess.SubprocessError) as e:
            print(f"Error fetching {url}: {e}")
        
        return None
    
    def load_template(self, template_name: str) -> Dict[str, Any]:
        """Load a template from GitHub"""
        # Fetch from library/templates/
        github_path = f"library/templates/{template_name}.yml"
        content = self.fetch_from_github(github_path)
        
        if content:
            config = yaml.safe_load(content)
            
            # Handle alias templates
            if 'alias' in config:
                actual_template = config['alias']['template']
                return self.load_template(actual_template)
            
            if 'template' in config:
                return config['template']
        
        raise ValueError(f"Template not found on GitHub: {template_name} (tried {github_path})")
    
    def resolve_template_to_path(self, template_name: str) -> str:
        """Resolve template name to service path"""
        # Template to OS/version mapping
        template_map = {
            'alpine-3.19': 'alpine/3.19',
            'alpine': 'alpine/3.19',
            'ubuntu-24.04': 'ubuntu/24.04',
            'ubuntu-22.04': 'ubuntu/22.04',
            'ubuntu-lts': 'ubuntu/24.04',
            'ubuntu-noble': 'ubuntu/24.04',
            'ubuntu-jammy': 'ubuntu/22.04',
            'ubuntu-minimal-24.04': 'ubuntu-minimal/24.04',
            'ubuntu-minimal-22.04': 'ubuntu-minimal/22.04',
            'ubuntu-minimal-lts': 'ubuntu-minimal/24.04',
            'ubuntu-minimal-noble': 'ubuntu-minimal/24.04',
            'ubuntu-minimal-jammy': 'ubuntu-minimal/22.04',
            'debian-12': 'debian/12',
            'debian-11': 'debian/11',
            'debian-bookworm': 'debian/12',
            'debian-bullseye': 'debian/11',
        }
        return template_map.get(template_name, '')
    
    def load_library_service(self, template_name: str, service_name: str) -> Dict[str, Any]:
        """Load a library service from GitHub"""
        # Resolve template to path
        template_path = self.resolve_template_to_path(template_name)
        if not template_path:
            return None
        
        # Fetch from library/services/{os}/{version}/{service}/
        github_path = f"library/services/{template_path}/{service_name}/lxc-compose.yml"
        content = self.fetch_from_github(github_path)
        
        if content:
            config = yaml.safe_load(content)
            
            # Extract container configuration
            if 'containers' in config:
                containers = config['containers']
                if isinstance(containers, dict) and containers:
                    container = list(containers.values())[0]
                    # Store the GitHub path for test resolution
                    container['__library_service_path__'] = f"library/services/{template_path}/{service_name}"
                    return container
                elif isinstance(containers, list) and len(containers) > 0:
                    container = containers[0]
                    container['__library_service_path__'] = f"library/services/{template_path}/{service_name}"
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
        
        # Handle exposed_ports - combine and deduplicate
        if 'exposed_ports' in overlay:
            base_ports = merged.get('exposed_ports', [])
            for port in overlay['exposed_ports']:
                if port not in base_ports:
                    base_ports.append(port)
            merged['exposed_ports'] = base_ports
        
        # Handle mounts - append overlay to base
        if 'mounts' in overlay:
            if 'mounts' not in merged:
                merged['mounts'] = []
            merged['mounts'].extend(overlay['mounts'])
        
        # Handle services - merge
        if 'services' in overlay:
            if 'services' not in merged:
                merged['services'] = {}
            merged['services'].update(overlay['services'])
        
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
                            # Add library path metadata to test
                            name, path = test.split(':', 1)
                            merged['tests'][test_type].append(f"{test}@library:{library_path}")
                        else:
                            merged['tests'][test_type].append(test)
        
        # Handle logs - append
        if 'logs' in overlay:
            if 'logs' not in merged:
                merged['logs'] = []
            merged['logs'].extend(overlay['logs'])
        
        # Copy over any other fields not explicitly handled
        for key, value in overlay.items():
            if key not in ['packages', 'environment', 'exposed_ports', 'mounts', 
                          'services', 'post_install', 'tests', 'logs', '__library_service_path__']:
                merged[key] = value
        
        return merged
    
    def process_container(self, container_config: Dict[str, Any]) -> Dict[str, Any]:
        """Process a single container configuration with template and includes"""
        # Start with empty merged config
        merged = {}
        
        # Store the container name if present
        if 'name' in container_config:
            merged['name'] = container_config['name']
        
        # Step 1: Apply template if specified
        if 'template' in container_config:
            template_name = container_config['template']
            try:
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
            except ValueError as e:
                print(f"Warning: {e}")
                # Continue without template
        elif 'image' in container_config:
            # If no template, use image directly
            merged['image'] = container_config['image']
        
        # Step 2: Apply includes (library services)
        if 'includes' in container_config and 'template' in container_config:
            for include in container_config['includes']:
                # Load the library service for this template
                library_service = self.load_library_service(container_config['template'], include)
                
                if library_service:
                    # Mark included commands for clarity
                    if 'post_install' in library_service:
                        marked_post_install = []
                        for cmd in library_service['post_install']:
                            marked_cmd = cmd.copy() if isinstance(cmd, dict) else {'command': cmd}
                            marked_cmd['name'] = f"[{include}] {marked_cmd.get('name', 'Setup')}"
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
                    print(f"Warning: Library service '{include}' not found for template '{container_config['template']}'")
        
        # Step 3: Apply local configuration (excluding template and includes)
        local_config = container_config.copy()
        
        # Remove already processed fields
        for field in ['template', 'includes', 'name']:
            if field in local_config:
                del local_config[field]
        
        # Mark local post_install commands
        if 'post_install' in local_config:
            marked_post_install = []
            for cmd in local_config['post_install']:
                marked_cmd = cmd.copy() if isinstance(cmd, dict) else {'command': cmd}
                marked_cmd['name'] = f"[Local] {marked_cmd.get('name', 'Custom command')}"
                marked_post_install.append(marked_cmd)
            local_config['post_install'] = marked_post_install
        
        # Merge local config last (highest priority)
        merged = self.merge_configs(merged, local_config)
        
        # Restore the container name
        if 'name' in container_config:
            merged['name'] = container_config['name']
        
        return merged
    
    def process_compose_file(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Process an entire compose file, expanding templates and includes"""
        processed = config.copy()
        
        if 'containers' in processed:
            containers = processed['containers']
            
            # Process each container
            if isinstance(containers, dict):
                for name, container in containers.items():
                    # Ensure container has a name
                    if 'name' not in container:
                        container['name'] = name
                    
                    # Process the container
                    processed['containers'][name] = self.process_container(container)
            
            elif isinstance(containers, list):
                processed_list = []
                for container in containers:
                    processed_list.append(self.process_container(container))
                processed['containers'] = processed_list
        
        return processed