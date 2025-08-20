#!/usr/bin/env python3
"""
LXC Compose - Simple container orchestration for LXC
Commands: up, down, list, destroy (with --all support)
"""

import os
import sys
import time
import json
import yaml
import click
import subprocess
import re
from typing import Dict, Any, Optional, List

# Terminal colors
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
BOLD = '\033[1m'
NC = '\033[0m'  # No Color

DEFAULT_CONFIG = 'lxc-compose.yml'
DEFAULT_ENV_FILE = '.env'

# Data directory setup
if os.geteuid() == 0:
    DATA_DIR = '/etc/lxc-compose'
else:
    XDG_DATA_HOME = os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share'))
    DATA_DIR = os.path.join(XDG_DATA_HOME, 'lxc-compose')

# Shared hosts file location
SHARED_HOSTS_DIR = '/srv/lxc-compose/etc'
SHARED_HOSTS_FILE = os.path.join(SHARED_HOSTS_DIR, 'hosts')

# Container IP tracking file
CONTAINER_IPS_FILE = os.path.join(DATA_DIR, 'container-ips.json')

class LXCCompose:
    def __init__(self, config_file: str = None, all_containers: bool = False):
        self.all_containers = all_containers
        self.config_file = config_file
        self.env_vars = {}
        
        if not all_containers:
            if not config_file or not os.path.exists(config_file):
                click.echo(f"{RED}✗{NC} Config file not found: {config_file}")
                sys.exit(1)
            
            # Load .env file if it exists
            self.load_env_file()
            
            # Load and parse config
            self.config = self.load_config()
            self.containers = self.parse_containers()
        else:
            self.config = {}
            self.containers = []
        
        # Initialize hosts file if it doesn't exist
        self.init_hosts_file()
    
    def load_env_file(self):
        """Load environment variables from .env file"""
        config_dir = os.path.dirname(os.path.abspath(self.config_file))
        env_file = os.path.join(config_dir, DEFAULT_ENV_FILE)
        
        if os.path.exists(env_file):
            click.echo(f"  Loading environment from {DEFAULT_ENV_FILE}")
            with open(env_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    # Skip comments and empty lines
                    if line and not line.startswith('#'):
                        if '=' in line:
                            key, value = line.split('=', 1)
                            # Remove quotes if present
                            key = key.strip()
                            value = value.strip().strip('"').strip("'")
                            self.env_vars[key] = value
                            # Also set in current environment for variable expansion
                            os.environ[key] = value
            
    def load_config(self) -> Dict:
        """Load configuration from YAML file"""
        with open(self.config_file, 'r') as f:
            content = f.read()
            
            # Expand environment variables in the YAML content
            for key, value in self.env_vars.items():
                content = content.replace(f'${{{key}}}', value)
                content = content.replace(f'${key}', value)
            
            return yaml.safe_load(content)
    
    def parse_containers(self):
        """Parse containers from either list or dictionary format"""
        containers_config = self.config.get('containers', {})
        
        if isinstance(containers_config, list):
            # List format: containers with 'name' field
            return containers_config
        elif isinstance(containers_config, dict):
            # Dictionary format: container names as keys
            containers = []
            for name, config in containers_config.items():
                container = config.copy() if config else {}
                container['name'] = name
                containers.append(container)
            return containers
        else:
            return []
    
    def run_command(self, cmd, check: bool = True):
        """Run a command and return the result"""
        try:
            return subprocess.run(cmd, capture_output=True, text=True, check=check)
        except subprocess.CalledProcessError as e:
            if check:
                click.echo(f"{RED}✗{NC} Command failed: {' '.join(cmd)}")
                if e.stderr:
                    click.echo(f"  Error: {e.stderr}")
                sys.exit(1)
            return e
    
    def init_hosts_file(self):
        """Initialize the shared hosts file with basic entries"""
        # Create directories with sudo if needed
        try:
            os.makedirs(SHARED_HOSTS_DIR, exist_ok=True)
        except PermissionError:
            # Try with sudo
            subprocess.run(['sudo', 'mkdir', '-p', SHARED_HOSTS_DIR], check=True)
            # Set permissions so we can write to it
            subprocess.run(['sudo', 'chmod', '755', SHARED_HOSTS_DIR], check=True)
        
        try:
            os.makedirs(DATA_DIR, exist_ok=True)
        except PermissionError:
            # Try with sudo
            subprocess.run(['sudo', 'mkdir', '-p', DATA_DIR], check=True)
            # Set permissions so we can write to it
            subprocess.run(['sudo', 'chmod', '755', DATA_DIR], check=True)
        
        if not os.path.exists(SHARED_HOSTS_FILE):
            try:
                with open(SHARED_HOSTS_FILE, 'w') as f:
                    f.write("# LXC Compose managed hosts file\n")
                    f.write("127.0.0.1\tlocalhost\n")
                    f.write("::1\tlocalhost ip6-localhost ip6-loopback\n")
                    f.write("\n# Container entries\n")
            except PermissionError:
                # Create with sudo and then write
                content = """# LXC Compose managed hosts file
127.0.0.1\tlocalhost
::1\tlocalhost ip6-localhost ip6-loopback

# Container entries
"""
                subprocess.run(['sudo', 'bash', '-c', f'echo "{content}" > {SHARED_HOSTS_FILE}'], check=True)
                subprocess.run(['sudo', 'chmod', '644', SHARED_HOSTS_FILE], check=True)
    
    def update_hosts_file(self, action: str, name: str, ip: str = None):
        """Add or remove entry from shared hosts file"""
        if action == "add" and ip:
            # Check if entry already exists
            try:
                with open(SHARED_HOSTS_FILE, 'r') as f:
                    existing = f.read()
                    if f"{ip}\t{name}" in existing or f" {name}\n" in existing:
                        return  # Already exists
            except FileNotFoundError:
                # File doesn't exist yet, that's ok
                existing = ""
            
            # Add new entry
            try:
                with open(SHARED_HOSTS_FILE, 'a') as f:
                    f.write(f"{ip}\t{name}\n")
            except PermissionError:
                # Use sudo to append
                subprocess.run(['sudo', 'bash', '-c', f'echo "{ip}\t{name}" >> {SHARED_HOSTS_FILE}'], check=True)
            click.echo(f"  Added {name} ({ip}) to hosts file")
            
        elif action == "remove":
            # Remove entry containing the container name
            if os.path.exists(SHARED_HOSTS_FILE):
                try:
                    with open(SHARED_HOSTS_FILE, 'r') as f:
                        lines = f.readlines()
                    
                    # Filter out lines with this container name
                    new_lines = []
                    for line in lines:
                        # Skip lines that have this container name as a hostname
                        if name in line.split():
                            continue
                        new_lines.append(line)
                    
                    with open(SHARED_HOSTS_FILE, 'w') as f:
                        f.writelines(new_lines)
                except PermissionError:
                    # Read with cat, filter, and write back with sudo
                    result = subprocess.run(['cat', SHARED_HOSTS_FILE], capture_output=True, text=True)
                    lines = result.stdout.splitlines(keepends=True)
                    
                    # Filter out lines with this container name
                    new_lines = []
                    for line in lines:
                        # Skip lines that have this container name as a hostname
                        if name in line.split():
                            continue
                        new_lines.append(line)
                    
                    # Write back with sudo
                    content = ''.join(new_lines)
                    subprocess.run(['sudo', 'bash', '-c', f'echo "{content}" > {SHARED_HOSTS_FILE}'], check=True)
    
    def mount_hosts_file(self, name: str):
        """Mount the shared hosts file into the container"""
        click.echo(f"  Mounting shared hosts file...")
        self.run_command(['lxc', 'config', 'device', 'add', name, 'hosts',
                         'disk', f'source={SHARED_HOSTS_FILE}', 
                         'path=/etc/hosts'])
    
    def mount_env_file(self, name: str):
        """Mount the .env file into the container if it exists"""
        config_dir = os.path.dirname(os.path.abspath(self.config_file))
        env_file = os.path.join(config_dir, DEFAULT_ENV_FILE)
        
        if os.path.exists(env_file):
            click.echo(f"  Mounting .env file...")
            self.run_command(['lxc', 'config', 'device', 'add', name, 'envfile',
                             'disk', f'source={env_file}', 
                             'path=/app/.env'])
    
    def setup_container_environment(self, name: str):
        """Setup system-wide environment variables in container"""
        if not self.env_vars:
            return
        
        click.echo(f"  Setting up environment variables...")
        
        # Create /etc/environment entries
        env_content = ""
        for key, value in self.env_vars.items():
            env_content += f'{key}="{value}"\n'
        
        if env_content:
            # Write to /etc/environment
            self.run_command(['lxc', 'exec', name, '--', 'sh', '-c',
                            f'echo \'{env_content}\' >> /etc/environment'])
            
            # Also create a profile.d script for shell environments
            profile_script = "#!/bin/sh\n"
            profile_script += "# LXC Compose environment variables\n"
            for key, value in self.env_vars.items():
                profile_script += f'export {key}="{value}"\n'
            
            self.run_command(['lxc', 'exec', name, '--', 'sh', '-c',
                            f'echo \'{profile_script}\' > /etc/profile.d/lxc-compose.sh && chmod +x /etc/profile.d/lxc-compose.sh'])
    
    def manage_exposed_ports(self, action: str, ip: str, ports: List[int]):
        """Add or remove iptables rules for exposed ports"""
        if action == "add" and ports:
            click.echo(f"  Setting up exposed ports: {ports}")
            
            # Allow established connections
            self.run_command(['sudo', 'iptables', '-A', 'FORWARD',
                            '-d', ip, '-m', 'state', '--state',
                            'ESTABLISHED,RELATED', '-j', 'ACCEPT'], check=False)
            
            # Allow each exposed port
            for port in ports:
                self.run_command(['sudo', 'iptables', '-A', 'FORWARD',
                                '-d', ip, '-p', 'tcp', '--dport', str(port),
                                '-j', 'ACCEPT'], check=False)
                click.echo(f"    Exposed port {port}")
            
            # Allow container to initiate outbound connections
            self.run_command(['sudo', 'iptables', '-A', 'FORWARD',
                            '-s', ip, '-j', 'ACCEPT'], check=False)
            
            # Drop all other inbound traffic to this container
            self.run_command(['sudo', 'iptables', '-A', 'FORWARD',
                            '-d', ip, '-j', 'DROP'], check=False)
            
        elif action == "remove":
            click.echo(f"  Removing iptables rules...")
            
            # Get all FORWARD rules
            result = self.run_command(['sudo', 'iptables', '-L', 'FORWARD',
                                     '--line-numbers', '-n'], check=False)
            
            if result.returncode == 0:
                # Parse rules and find ones with our IP
                lines = result.stdout.split('\n')
                rules_to_remove = []
                
                for line in lines:
                    if ip in line:
                        # Extract rule number
                        match = re.match(r'^(\d+)', line)
                        if match:
                            rules_to_remove.append(int(match.group(1)))
                
                # Remove rules in reverse order (highest number first)
                for rule_num in sorted(rules_to_remove, reverse=True):
                    self.run_command(['sudo', 'iptables', '-D', 'FORWARD',
                                    str(rule_num)], check=False)
    
    def save_container_ip(self, name: str, ip: str):
        """Save container IP for later cleanup"""
        ips = {}
        if os.path.exists(CONTAINER_IPS_FILE):
            try:
                with open(CONTAINER_IPS_FILE, 'r') as f:
                    ips = json.load(f)
            except PermissionError:
                # Read with sudo
                result = subprocess.run(['sudo', 'cat', CONTAINER_IPS_FILE], capture_output=True, text=True)
                if result.returncode == 0:
                    ips = json.loads(result.stdout)
        
        ips[name] = ip
        
        try:
            with open(CONTAINER_IPS_FILE, 'w') as f:
                json.dump(ips, f, indent=2)
        except PermissionError:
            # Write with sudo
            content = json.dumps(ips, indent=2)
            subprocess.run(['sudo', 'bash', '-c', f'echo \'{content}\' > {CONTAINER_IPS_FILE}'], check=True)
    
    def get_saved_container_ip(self, name: str) -> Optional[str]:
        """Get saved container IP"""
        if os.path.exists(CONTAINER_IPS_FILE):
            try:
                with open(CONTAINER_IPS_FILE, 'r') as f:
                    ips = json.load(f)
                    return ips.get(name)
            except PermissionError:
                # Read with sudo
                result = subprocess.run(['sudo', 'cat', CONTAINER_IPS_FILE], capture_output=True, text=True)
                if result.returncode == 0:
                    ips = json.loads(result.stdout)
                    return ips.get(name)
        return None
    
    def remove_saved_container_ip(self, name: str):
        """Remove saved container IP"""
        if os.path.exists(CONTAINER_IPS_FILE):
            try:
                with open(CONTAINER_IPS_FILE, 'r') as f:
                    ips = json.load(f)
            except PermissionError:
                # Read with sudo
                result = subprocess.run(['sudo', 'cat', CONTAINER_IPS_FILE], capture_output=True, text=True)
                if result.returncode == 0:
                    ips = json.loads(result.stdout)
                else:
                    ips = {}
            
            if name in ips:
                del ips[name]
                try:
                    with open(CONTAINER_IPS_FILE, 'w') as f:
                        json.dump(ips, f, indent=2)
                except PermissionError:
                    # Write with sudo
                    content = json.dumps(ips, indent=2)
                    subprocess.run(['sudo', 'bash', '-c', f'echo \'{content}\' > {CONTAINER_IPS_FILE}'], check=True)
    
    def get_all_containers(self) -> List[str]:
        """Get all containers on the system"""
        result = self.run_command(['lxc', 'list', '--format=json'], check=False)
        if result.returncode != 0:
            return []
        containers = json.loads(result.stdout)
        return [c['name'] for c in containers]
    
    def container_exists(self, name: str) -> bool:
        """Check if container exists"""
        result = self.run_command(['lxc', 'list', name, '--format=json'], check=False)
        if result.returncode != 0:
            return False
        containers = json.loads(result.stdout)
        return len(containers) > 0
    
    def container_running(self, name: str) -> bool:
        """Check if container is running"""
        result = self.run_command(['lxc', 'list', name, '--format=json'], check=False)
        if result.returncode != 0:
            return False
        containers = json.loads(result.stdout)
        return len(containers) > 0 and containers[0].get('status') == 'Running'
    
    def get_container_ip(self, name: str) -> Optional[str]:
        """Get container IP address"""
        result = self.run_command(['lxc', 'list', name, '--format=json'], check=False)
        if result.returncode != 0:
            return None
        
        containers = json.loads(result.stdout)
        if not containers:
            return None
        
        container = containers[0]
        if container.get('state', {}).get('network'):
            for iface, details in container['state']['network'].items():
                if iface != 'lo' and details.get('addresses'):
                    for addr in details['addresses']:
                        if addr['family'] == 'inet' and not addr['address'].startswith('fe80'):
                            return addr['address'].split('/')[0]
        return None
    
    def wait_for_network(self, name: str, timeout: int = 60) -> Optional[str]:
        """Wait for container to get network and return IP"""
        click.echo(f"  Waiting for network...")
        start = time.time()
        while time.time() - start < timeout:
            ip = self.get_container_ip(name)
            if ip:
                click.echo(f"  Got IP: {ip}")
                return ip
            time.sleep(2)
        return None
    
    def setup_container_networking(self, name: str, exposed_ports: List[int]):
        """Setup both hosts file and iptables rules"""
        # Get container IP
        ip = self.get_container_ip(name)
        if not ip:
            click.echo(f"  {YELLOW}Warning: Could not get container IP{NC}")
            return
        
        try:
            # Save IP for later cleanup
            self.save_container_ip(name, ip)
            
            # Update hosts file
            self.update_hosts_file("add", name, ip)
            
            # Mount shared hosts file to container
            self.mount_hosts_file(name)
            
            # Mount .env file if it exists
            self.mount_env_file(name)
            
            # Setup system-wide environment variables
            self.setup_container_environment(name)
            
            # Setup iptables rules for exposed ports
            if exposed_ports:
                self.manage_exposed_ports("add", ip, exposed_ports)
            
        except Exception as e:
            # Rollback on failure
            click.echo(f"  {RED}Error setting up networking: {e}{NC}")
            self.cleanup_container_networking(name)
            raise
    
    def cleanup_container_networking(self, name: str):
        """Remove hosts entry and iptables rules"""
        # Try to get IP from saved data first, then from container
        ip = self.get_saved_container_ip(name)
        if not ip:
            ip = self.get_container_ip(name)
        
        # Remove from hosts file
        self.update_hosts_file("remove", name)
        
        # Remove iptables rules if we have an IP
        if ip:
            self.manage_exposed_ports("remove", ip, [])
        
        # Remove saved IP
        self.remove_saved_container_ip(name)
    
    def create_container(self, container: Dict):
        """Create a single container"""
        name = container['name']
        
        # Determine base image
        if 'image' in container:
            image = container['image']
        elif 'template' in container:
            template = container['template']
            release = container.get('release', 'latest')
            if template == 'alpine':
                image = f"images:alpine/{release}"
            elif template in ['ubuntu', 'debian']:
                image = f"images:{template}/{release}"
            else:
                image = f"images:{template}/{release}"
        else:
            image = 'ubuntu:22.04'
        
        # Create container
        click.echo(f"  Creating from {image}...")
        self.run_command(['lxc', 'launch', image, name])
        
        # Wait for network
        ip = self.wait_for_network(name)
        
        # Setup networking (hosts file, env vars, and exposed ports)
        exposed_ports = []
        if 'exposed_ports' in container:
            exposed_ports = container['exposed_ports']
            if isinstance(exposed_ports, int):
                exposed_ports = [exposed_ports]
        
        if ip:
            self.setup_container_networking(name, exposed_ports)
        
        # Setup mounts
        if 'mounts' in container:
            self.setup_mounts(name, container['mounts'])
        
        # Install packages
        if 'packages' in container:
            self.install_packages(name, container['packages'])
        
        # Run post-install commands (with environment variables)
        if 'post_install' in container:
            self.run_post_install(name, container['post_install'])
            
    def setup_mounts(self, name: str, mounts: List):
        """Setup container mounts"""
        click.echo(f"  Setting up mounts...")
        
        config_dir = os.path.dirname(os.path.abspath(self.config_file))
        
        for mount in mounts:
            if isinstance(mount, str):
                # Simple format: "./path:/container/path"
                if ':' in mount:
                    source, target = mount.split(':', 1)
                else:
                    continue
            elif isinstance(mount, dict):
                # Dictionary format: {source: path, target: path}
                source = mount.get('source', '')
                target = mount.get('target', '')
            else:
                continue
            
            # Expand and resolve paths
            source = os.path.expanduser(source)
            if not os.path.isabs(source):
                source = os.path.join(config_dir, source)
            source = os.path.abspath(source)
            
            # Create source directory if it doesn't exist
            if not os.path.exists(source):
                os.makedirs(source, exist_ok=True)
                click.echo(f"    Created directory: {source}")
            
            # Add mount to container
            device_name = target.replace('/', '-').strip('-') or 'root'
            self.run_command(['lxc', 'config', 'device', 'add', name, device_name, 
                            'disk', f'source={source}', f'path={target}'])
            click.echo(f"    Mounted {source} -> {target}")
    
    def install_packages(self, name: str, packages: List[str]):
        """Install packages in container"""
        if not packages:
            return
            
        click.echo(f"  Installing packages...")
        
        # Detect package manager
        result = self.run_command(['lxc', 'exec', name, '--', 'which', 'apt-get'], check=False)
        if result.returncode == 0:
            # Ubuntu/Debian
            self.run_command(['lxc', 'exec', name, '--', 'apt-get', 'update'])
            self.run_command(['lxc', 'exec', name, '--', 'apt-get', 'install', '-y'] + packages)
        else:
            # Try Alpine
            result = self.run_command(['lxc', 'exec', name, '--', 'which', 'apk'], check=False)
            if result.returncode == 0:
                self.run_command(['lxc', 'exec', name, '--', 'apk', 'update'])
                self.run_command(['lxc', 'exec', name, '--', 'apk', 'add'] + packages)
    
    def run_post_install(self, name: str, commands: List):
        """Run post-installation commands with environment variables"""
        click.echo(f"  Running post-install commands...")
        
        # Build environment string for commands
        env_prefix = ""
        if self.env_vars:
            for key, value in self.env_vars.items():
                env_prefix += f'export {key}="{value}"; '
        
        for item in commands:
            if isinstance(item, dict):
                cmd_name = item.get('name', 'Command')
                command = item.get('command', '')
            else:
                cmd_name = 'Command'
                command = item
            
            if command:
                click.echo(f"    {cmd_name}...")
                # Handle multi-line commands
                if '\n' in command:
                    # Create a script with environment variables
                    script = f"#!/bin/sh\n{env_prefix}\n{command}"
                    script = script.replace('\r\n', '\n').replace('\r', '\n')
                    self.run_command(['lxc', 'exec', name, '--', 'sh', '-c', script])
                else:
                    # Single line command with environment
                    full_command = f"{env_prefix}{command}" if env_prefix else command
                    self.run_command(['lxc', 'exec', name, '--', 'sh', '-c', full_command])
    
    def handle_dependencies(self, container: Dict):
        """Handle container dependencies"""
        if 'depends_on' not in container:
            return
            
        deps = container['depends_on']
        if isinstance(deps, str):
            deps = [deps]
        
        for dep in deps:
            if not self.container_exists(dep):
                click.echo(f"  {YELLOW}Warning: Dependency {dep} doesn't exist{NC}")
                continue
                
            if not self.container_running(dep):
                click.echo(f"  Starting dependency: {dep}")
                self.run_command(['lxc', 'start', dep])
                
                # Wait for network and setup networking if needed
                ip = self.wait_for_network(dep, timeout=30)
                if ip and not self.get_saved_container_ip(dep):
                    # Dependency wasn't properly setup, just add to hosts
                    self.save_container_ip(dep, ip)
                    self.update_hosts_file("add", dep, ip)
    
    def up(self):
        """Create and start containers"""
        if self.all_containers:
            click.echo(f"{BOLD}Starting all containers on system...{NC}")
            containers = self.get_all_containers()
            if not containers:
                click.echo(f"{YELLOW}No containers found on system{NC}")
                return
                
            for name in containers:
                if not self.container_running(name):
                    click.echo(f"Starting {name}...")
                    self.run_command(['lxc', 'start', name])
                else:
                    click.echo(f"Container {name} already running")
        else:
            click.echo(f"{BOLD}Creating/starting containers from {self.config_file}...{NC}")
            
            for container in self.containers:
                name = container['name']
                click.echo(f"\n{BLUE}Container: {name}{NC}")
                
                # Handle dependencies
                self.handle_dependencies(container)
                
                if self.container_exists(name):
                    if self.container_running(name):
                        click.echo(f"  Already running")
                    else:
                        click.echo(f"  Starting...")
                        self.run_command(['lxc', 'start', name])
                        
                        # Re-setup networking
                        ip = self.wait_for_network(name)
                        if ip:
                            exposed_ports = container.get('exposed_ports', [])
                            if isinstance(exposed_ports, int):
                                exposed_ports = [exposed_ports]
                            self.setup_container_networking(name, exposed_ports)
                else:
                    self.create_container(container)
            
            click.echo(f"\n{GREEN}✓{NC} All containers are up")
    
    def down(self):
        """Stop containers"""
        if self.all_containers:
            click.echo(f"{BOLD}Stopping all containers on system...{NC}")
            containers = self.get_all_containers()
            if not containers:
                click.echo(f"{YELLOW}No containers found on system{NC}")
                return
                
            for name in containers:
                if self.container_running(name):
                    click.echo(f"Stopping {name}...")
                    self.run_command(['lxc', 'stop', name])
                else:
                    click.echo(f"Container {name} already stopped")
        else:
            click.echo(f"{BOLD}Stopping containers from {self.config_file}...{NC}")
            
            for container in self.containers:
                name = container['name']
                if self.container_exists(name) and self.container_running(name):
                    click.echo(f"Stopping {name}...")
                    # Note: We don't cleanup networking on stop, only on destroy
                    self.run_command(['lxc', 'stop', name])
                else:
                    click.echo(f"Container {name} not running")
            
            click.echo(f"\n{GREEN}✓{NC} All containers stopped")
    
    def destroy(self):
        """Stop and remove containers"""
        if self.all_containers:
            click.echo(f"{BOLD}{RED}DESTROYING ALL CONTAINERS ON SYSTEM!{NC}")
            containers = self.get_all_containers()
            if not containers:
                click.echo(f"{YELLOW}No containers found on system{NC}")
                return
                
            for name in containers:
                click.echo(f"Destroying {name}...")
                if self.container_running(name):
                    self.run_command(['lxc', 'stop', name])
                
                # Cleanup networking
                self.cleanup_container_networking(name)
                
                # Delete container
                self.run_command(['lxc', 'delete', name])
        else:
            click.echo(f"{BOLD}Destroying containers from {self.config_file}...{NC}")
            
            for container in self.containers:
                name = container['name']
                if self.container_exists(name):
                    click.echo(f"Destroying {name}...")
                    if self.container_running(name):
                        self.run_command(['lxc', 'stop', name])
                    
                    # Cleanup networking
                    self.cleanup_container_networking(name)
                    
                    # Delete container
                    self.run_command(['lxc', 'delete', name])
                else:
                    click.echo(f"Container {name} doesn't exist")
                    # Still try to cleanup any lingering network config
                    self.cleanup_container_networking(name)
            
            click.echo(f"\n{GREEN}✓{NC} All containers destroyed")
    
    def list_containers(self):
        """List containers and their status"""
        if self.all_containers:
            click.echo(f"{BOLD}All containers on system:{NC}")
            result = self.run_command(['lxc', 'list', '--format=json'])
            containers = json.loads(result.stdout)
            
            if not containers:
                click.echo(f"{YELLOW}No containers found{NC}")
                return
            
            click.echo("\n" + "=" * 60)
            for container in containers:
                name = container['name']
                status = container.get('status', 'Unknown')
                
                # Color code status
                if status == 'Running':
                    status_color = GREEN
                elif status == 'Stopped':
                    status_color = YELLOW
                else:
                    status_color = RED
                
                click.echo(f"  {name}: {status_color}{status}{NC}")
                
                # Show IP if running
                if status == 'Running':
                    ip = self.get_container_ip(name)
                    if ip:
                        click.echo(f"    IP: {ip}")
                        
                        # Check if this container has saved exposed ports
                        # (We don't have config for --all, so we can't show exposed ports)
        else:
            click.echo(f"{BOLD}Containers from {self.config_file}:{NC}")
            
            # Show loaded environment variables
            if self.env_vars:
                click.echo(f"\n  Environment variables loaded from .env:")
                for key in self.env_vars:
                    click.echo(f"    {key}")
            
            click.echo("\n" + "=" * 60)
            for container in self.containers:
                name = container['name']
                
                # Get container status
                result = self.run_command(['lxc', 'list', name, '--format=json'], check=False)
                if result.returncode != 0:
                    click.echo(f"  {name}: {RED}Not Found{NC}")
                    continue
                
                containers = json.loads(result.stdout)
                if not containers:
                    click.echo(f"  {name}: {RED}Not Found{NC}")
                    continue
                
                info = containers[0]
                status = info.get('status', 'Unknown')
                
                # Color code status
                if status == 'Running':
                    status_color = GREEN
                elif status == 'Stopped':
                    status_color = YELLOW
                else:
                    status_color = RED
                
                click.echo(f"  {name}: {status_color}{status}{NC}")
                
                # Show IP if running
                if status == 'Running':
                    ip = self.get_container_ip(name)
                    if ip:
                        click.echo(f"    IP: {ip}")
                
                # Show exposed ports from config
                exposed_ports = container.get('exposed_ports', [])
                if exposed_ports:
                    if isinstance(exposed_ports, int):
                        exposed_ports = [exposed_ports]
                    click.echo(f"    Exposed ports: {', '.join(map(str, exposed_ports))}")
        
        click.echo("=" * 60)

# Confirmation helper
def confirm_all_operation(operation: str):
    """Require confirmation for --all operations"""
    expected = f"Yes, I want to {operation} all containers. I am aware of the risks involved."
    click.echo(f"\n{YELLOW}⚠ WARNING: This will {operation} ALL containers on the system!{NC}")
    click.echo(f"Type exactly: {BOLD}{expected}{NC}")
    confirmation = input("> ")
    if confirmation != expected:
        click.echo(f"{RED}✗{NC} Confirmation failed. Operation cancelled.")
        sys.exit(1)

@click.group()
def cli():
    """LXC Compose - Simple container orchestration"""
    pass

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file')
@click.option('--all', 'all_containers', is_flag=True, help='Start ALL containers on system')
def up(file, all_containers):
    """Create and start containers"""
    if all_containers:
        confirm_all_operation("start")
    compose = LXCCompose(file if not all_containers else None, all_containers)
    compose.up()

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file')
@click.option('--all', 'all_containers', is_flag=True, help='Stop ALL containers on system')
def down(file, all_containers):
    """Stop containers"""
    if all_containers:
        confirm_all_operation("stop")
    compose = LXCCompose(file if not all_containers else None, all_containers)
    compose.down()

@cli.command('list')
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file')
@click.option('--all', 'all_containers', is_flag=True, help='List ALL containers on system')
def list_cmd(file, all_containers):
    """List containers and status"""
    compose = LXCCompose(file if not all_containers else None, all_containers)
    compose.list_containers()

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file')
@click.option('--all', 'all_containers', is_flag=True, help='Destroy ALL containers on system')
def destroy(file, all_containers):
    """Stop and remove containers"""
    if all_containers:
        confirm_all_operation("destroy")
    compose = LXCCompose(file if not all_containers else None, all_containers)
    compose.destroy()

if __name__ == '__main__':
    cli()