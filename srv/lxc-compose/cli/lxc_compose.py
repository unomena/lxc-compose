#!/usr/bin/env python3
"""
LXC Compose v2 - Docker Compose-like orchestration for LXC
Supports both list-based and dictionary-based container definitions
"""

import os
import sys
import time
import json
import yaml
import click
import subprocess
from typing import Dict, Any, Optional

# Terminal colors
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
BOLD = '\033[1m'
NC = '\033[0m'  # No Color

DEFAULT_CONFIG = 'lxc-compose.yml'

# Data directory setup
if os.geteuid() == 0:
    DATA_DIR = '/etc/lxc-compose'
else:
    XDG_DATA_HOME = os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share'))
    DATA_DIR = os.path.join(XDG_DATA_HOME, 'lxc-compose')

REGISTRY_FILE = os.path.join(DATA_DIR, 'registry.json')
PORT_FORWARDS_FILE = os.path.join(DATA_DIR, 'port-forwards.json')

class LXCCompose:
    def __init__(self, config_file: str):
        self.config_file = config_file
        self.config = self.load_config()
        self.containers = self.parse_containers()
        
    def load_config(self) -> Dict:
        """Load configuration from YAML file"""
        if not os.path.exists(self.config_file):
            click.echo(f"{RED}✗{NC} Config file not found: {self.config_file}")
            sys.exit(1)
            
        with open(self.config_file, 'r') as f:
            return yaml.safe_load(f)
    
    def parse_containers(self):
        """Parse containers from either list or dictionary format"""
        containers_config = self.config.get('containers', {})
        
        if type(containers_config) == list:
            # Old format: list of containers with 'name' field
            return containers_config
        elif type(containers_config) == dict:
            # New format: dictionary with container names as keys
            containers = []
            for name, config in containers_config.items():
                container = config.copy() if config else {}
                container['name'] = name
                containers.append(container)
            return containers
        else:
            return []
    
    def run_command(self, cmd, check: bool = True, env = None):
        """Run a command and return the result"""
        try:
            return subprocess.run(cmd, capture_output=True, text=True, check=check, env=env)
        except subprocess.CalledProcessError as e:
            if check:
                click.echo(f"{RED}✗{NC} Command failed: {' '.join(cmd)}")
                if e.stderr:
                    click.echo(f"  Error: {e.stderr}")
                if e.stdout:
                    click.echo(f"  Output: {e.stdout}")
                sys.exit(1)
            return e
    
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
    
    def wait_for_container(self, name: str, timeout: int = 60) -> bool:
        """Wait for container to be ready"""
        click.echo(f"  Waiting for {name} to be ready...")
        for i in range(timeout):
            result = self.run_command(['lxc', 'list', name, '--format=json'], check=False)
            if result.returncode == 0:
                containers = json.loads(result.stdout)
                if containers and containers[0].get('status') == 'Running':
                    # Check if network is ready
                    info = self.run_command(['lxc', 'info', name, '--format=json'], check=False)
                    if info.returncode == 0:
                        data = json.loads(info.stdout)
                        if data.get('state') and data['state'].get('network'):
                            return True
            time.sleep(1)
        return False
    
    def get_container_order(self):
        """Get containers in dependency order"""
        containers = self.containers.copy()
        ordered = []
        added_names = set()
        
        # First pass: containers without dependencies
        for container in containers:
            if not container.get('depends_on'):
                ordered.append(container)
                added_names.add(container['name'])
        
        # Second pass: containers with dependencies
        max_iterations = len(containers) * 2
        iteration = 0
        while len(ordered) < len(containers) and iteration < max_iterations:
            iteration += 1
            for container in containers:
                if container['name'] in added_names:
                    continue
                    
                deps = container.get('depends_on', [])
                if isinstance(deps, str):
                    deps = [deps]
                    
                if all(dep in added_names for dep in deps):
                    ordered.append(container)
                    added_names.add(container['name'])
        
        # Add any remaining containers (circular dependencies)
        for container in containers:
            if container['name'] not in added_names:
                click.echo(f"{YELLOW}⚠{NC} Warning: {container['name']} has unresolved dependencies")
                ordered.append(container)
        
        return ordered
    
    def create_container(self, container: Dict) -> bool:
        """Create a new container"""
        name = container['name']
        
        if self.container_exists(name):
            if self.container_running(name):
                click.echo(f"{YELLOW}⚠{NC} Container {name} already running")
            else:
                click.echo(f"{BLUE}ℹ{NC} Starting existing container {name}...")
                self.run_command(['lxc', 'start', name])
            return True
        
        click.echo(f"{BLUE}ℹ{NC} Creating container {name}...")
        
        # Determine image/template
        if 'image' in container:
            # Old format: image field
            image = container['image']
            cmd = ['lxc', 'launch', image, name]
        elif 'template' in container:
            # New format: template and release
            template = container['template']
            release = container.get('release', 'jammy')
            
            # Map template names to image sources
            if template == 'ubuntu':
                image = f'ubuntu:{release}'
            elif template == 'alpine':
                image = f'images:alpine/{release}'
            else:
                image = f'images:{template}/{release}'
            
            cmd = ['lxc', 'launch', image, name]
        else:
            # Default to Ubuntu 22.04
            cmd = ['lxc', 'launch', 'ubuntu:22.04', name]
        
        # Add static IP if specified
        if 'ip' in container:
            cmd.extend(['--network', f'lxcbr0:ip={container["ip"]}'])
        
        # Create the container
        result = self.run_command(cmd, check=False)
        if result.returncode != 0:
            if 'already exists' in result.stderr:
                click.echo(f"{YELLOW}⚠{NC} Container {name} already exists")
                return True
            else:
                click.echo(f"{RED}✗{NC} Failed to create container {name}")
                click.echo(f"  Error: {result.stderr}")
                return False
        
        # Wait for container to be ready
        if not self.wait_for_container(name):
            click.echo(f"{YELLOW}⚠{NC} Container {name} took too long to start")
        
        # Setup mounts
        if 'mounts' in container:
            self.setup_mounts(name, container['mounts'])
        
        # Install packages
        if 'packages' in container:
            self.install_packages(name, container['packages'])
        
        # Run post_install commands
        if 'post_install' in container:
            self.run_post_install(name, container['post_install'])
        
        # Setup services
        if 'services' in container:
            self.setup_services(name, container['services'])
        
        # Setup port forwarding
        if 'ports' in container:
            self.setup_port_forwarding(name, container['ports'], container.get('ip'))
        
        click.echo(f"{GREEN}✓{NC} Container {name} created and configured")
        return True
    
    def setup_mounts(self, container_name: str, mounts):
        """Setup container mounts"""
        for mount in mounts:
            # Support both string format (./path:/container) and dict format
            if isinstance(mount, str):
                if ':' in mount:
                    source, target = mount.split(':', 1)
                    source = os.path.expanduser(source)
                    # Convert relative paths to absolute
                    if not os.path.isabs(source):
                        config_dir = os.path.dirname(os.path.abspath(self.config_file))
                        source = os.path.join(config_dir, source)
                else:
                    click.echo(f"{YELLOW}⚠{NC} Invalid mount format: {mount}")
                    continue
            elif isinstance(mount, dict):
                source = os.path.expanduser(mount['source'])
                target = mount['target']
                # Convert relative paths to absolute
                if not os.path.isabs(source):
                    config_dir = os.path.dirname(os.path.abspath(self.config_file))
                    source = os.path.join(config_dir, source)
            else:
                click.echo(f"{YELLOW}⚠{NC} Invalid mount format: {mount}")
                continue
            
            # Create source directory if it doesn't exist
            os.makedirs(source, exist_ok=True)
            
            # Add device
            device_name = f"mount-{target.replace('/', '-').strip('-')}"
            click.echo(f"  Mounting {source} -> {target}")
            self.run_command([
                'lxc', 'config', 'device', 'add', container_name,
                device_name, 'disk',
                f'source={source}', f'path={target}'
            ])
    
    def install_packages(self, container_name: str, packages):
        """Install packages in container"""
        if not packages:
            return
        
        click.echo(f"  Installing packages...")
        
        # Determine package manager
        result = self.run_command(['lxc', 'exec', container_name, '--', 'which', 'apt-get'], check=False)
        if result.returncode == 0:
            # Ubuntu/Debian
            self.run_command(['lxc', 'exec', container_name, '--', 'apt-get', 'update'])
            cmd = ['lxc', 'exec', container_name, '--', 'apt-get', 'install', '-y'] + packages
        else:
            result = self.run_command(['lxc', 'exec', container_name, '--', 'which', 'apk'], check=False)
            if result.returncode == 0:
                # Alpine
                cmd = ['lxc', 'exec', container_name, '--', 'apk', 'add', '--no-cache'] + packages
            else:
                click.echo(f"{YELLOW}⚠{NC} Unknown package manager in {container_name}")
                return
        
        self.run_command(cmd)
    
    def run_post_install(self, container_name: str, post_install):
        """Run post-install commands"""
        for item in post_install:
            if isinstance(item, dict):
                name = item.get('name', 'Post-install command')
                command = item.get('command', '')
            else:
                name = 'Post-install command'
                command = item
            
            if not command:
                continue
            
            click.echo(f"  Running: {name}")
            
            # Handle multi-line commands
            if isinstance(command, str) and '\n' in command:
                # Write to temp script and execute
                script = f"#!/bin/bash\nset -e\n{command}"
                result = self.run_command([
                    'lxc', 'exec', container_name, '--', 
                    'bash', '-c', script
                ])
            else:
                result = self.run_command([
                    'lxc', 'exec', container_name, '--',
                    'bash', '-c', command
                ])
    
    def setup_services(self, container_name: str, services: Dict):
        """Setup services in container"""
        for service_name, service_config in services.items():
            click.echo(f"  Setting up service: {service_name}")
            
            if isinstance(service_config, dict):
                service_type = service_config.get('type', 'command')
                
                if service_type == 'system':
                    # System service configuration
                    config = service_config.get('config', '')
                    if config:
                        self.run_command([
                            'lxc', 'exec', container_name, '--',
                            'bash', '-c', config
                        ])
                
                elif service_type == 'systemd':
                    # Create systemd service
                    self.create_systemd_service(container_name, service_name, service_config)
                
                else:
                    # Regular command or supervisor service
                    self.create_supervisor_service(container_name, service_name, service_config)
            else:
                # Simple command
                self.run_command([
                    'lxc', 'exec', container_name, '--',
                    'bash', '-c', service_config
                ])
    
    def create_systemd_service(self, container_name: str, service_name: str, config: Dict):
        """Create systemd service in container"""
        command = config.get('command', '')
        if not command:
            return
        
        service_content = f"""[Unit]
Description={service_name}
After=network.target

[Service]
Type=simple
ExecStart={command}
Restart=always
User={config.get('user', 'root')}
WorkingDirectory={config.get('directory', '/')}

[Install]
WantedBy=multi-user.target
"""
        
        # Write service file
        self.run_command([
            'lxc', 'exec', container_name, '--',
            'bash', '-c', f'cat > /etc/systemd/system/{service_name}.service << EOF\n{service_content}\nEOF'
        ])
        
        # Enable and start service
        self.run_command(['lxc', 'exec', container_name, '--', 'systemctl', 'daemon-reload'])
        self.run_command(['lxc', 'exec', container_name, '--', 'systemctl', 'enable', service_name])
        self.run_command(['lxc', 'exec', container_name, '--', 'systemctl', 'start', service_name])
    
    def create_supervisor_service(self, container_name: str, service_name: str, config: Dict):
        """Create supervisor service in container"""
        # Check if supervisor is installed
        result = self.run_command(['lxc', 'exec', container_name, '--', 'which', 'supervisorctl'], check=False)
        if result.returncode != 0:
            return
        
        command = config.get('command', '')
        if not command:
            return
        
        # Build environment string
        env_vars = config.get('environment', {})
        env_str = ','.join([f'{k}="{v}"' for k, v in env_vars.items()])
        
        supervisor_config = f"""[program:{service_name}]
command={command}
directory={config.get('directory', '/')}
user={config.get('user', 'root')}
autostart={str(config.get('autostart', True)).lower()}
autorestart={str(config.get('autorestart', True)).lower()}
stdout_logfile={config.get('stdout_logfile', f'/var/log/{service_name}.log')}
stderr_logfile={config.get('stderr_logfile', f'/var/log/{service_name}_err.log')}
environment={env_str}
"""
        
        # Write supervisor config
        self.run_command([
            'lxc', 'exec', container_name, '--',
            'bash', '-c', f'cat > /etc/supervisor/conf.d/{service_name}.conf << EOF\n{supervisor_config}\nEOF'
        ])
        
        # Reload supervisor
        self.run_command(['lxc', 'exec', container_name, '--', 'supervisorctl', 'reread'], check=False)
        self.run_command(['lxc', 'exec', container_name, '--', 'supervisorctl', 'update'], check=False)
    
    def setup_port_forwarding(self, container_name: str, ports, container_ip: Optional[str] = None):
        """Setup port forwarding for container"""
        if not container_ip:
            # Get container IP
            result = self.run_command(['lxc', 'list', container_name, '--format=json'])
            containers = json.loads(result.stdout)
            if not containers:
                return
            
            container = containers[0]
            if container.get('state') and container['state'].get('network'):
                for iface, details in container['state']['network'].items():
                    if iface == 'lo':
                        continue
                    for addr in details.get('addresses', []):
                        if addr['family'] == 'inet' and not addr['address'].startswith('fe80'):
                            container_ip = addr['address']
                            break
        
        if not container_ip:
            click.echo(f"{YELLOW}⚠{NC} Could not determine IP for {container_name}")
            return
        
        # Load existing port forwards
        os.makedirs(DATA_DIR, exist_ok=True)
        forwards = []
        if os.path.exists(PORT_FORWARDS_FILE):
            with open(PORT_FORWARDS_FILE, 'r') as f:
                forwards = json.load(f)
        
        for port_config in ports:
            if isinstance(port_config, int):
                host_port = container_port = port_config
            elif isinstance(port_config, str) and ':' in port_config:
                parts = port_config.split(':')
                host_port = int(parts[0])
                container_port = int(parts[1])
            elif isinstance(port_config, dict):
                host_port = port_config.get('host', port_config.get('port'))
                container_port = port_config.get('container', port_config.get('port'))
            else:
                continue
            
            click.echo(f"  Port forward: {host_port} -> {container_ip}:{container_port}")
            
            # Add iptables rules
            # PREROUTING for external access
            self.run_command([
                'sudo', 'iptables', '-t', 'nat', '-A', 'PREROUTING',
                '-p', 'tcp', '--dport', str(host_port),
                '-j', 'DNAT', '--to-destination', f'{container_ip}:{container_port}'
            ], check=False)
            
            # OUTPUT for local access
            self.run_command([
                'sudo', 'iptables', '-t', 'nat', '-A', 'OUTPUT',
                '-p', 'tcp', '--dport', str(host_port), '-d', '127.0.0.1',
                '-j', 'DNAT', '--to-destination', f'{container_ip}:{container_port}'
            ], check=False)
            
            # POSTROUTING for SNAT
            self.run_command([
                'sudo', 'iptables', '-t', 'nat', '-A', 'POSTROUTING',
                '-p', 'tcp', '-d', container_ip, '--dport', str(container_port),
                '-j', 'MASQUERADE'
            ], check=False)
            
            # Save to registry
            forwards.append({
                'container': container_name,
                'host_port': host_port,
                'container_port': container_port,
                'container_ip': container_ip
            })
        
        # Save port forwards
        with open(PORT_FORWARDS_FILE, 'w') as f:
            json.dump(forwards, f, indent=2)
    
    def up(self):
        """Create and start all containers"""
        if not self.containers:
            click.echo(f"{YELLOW}⚠{NC} No containers defined in {self.config_file}")
            return
        
        click.echo(f"{BOLD}Starting LXC Compose...{NC}")
        
        # Process containers in dependency order
        ordered_containers = self.get_container_order()
        
        for container in ordered_containers:
            # Handle dependencies
            deps = container.get('depends_on', [])
            if isinstance(deps, str):
                deps = [deps]
            
            for dep in deps:
                click.echo(f"  Waiting for dependency: {dep}")
                max_wait = 60
                for i in range(max_wait):
                    if self.container_running(dep):
                        break
                    time.sleep(1)
                else:
                    click.echo(f"{YELLOW}⚠{NC} Dependency {dep} not ready after {max_wait}s")
            
            self.create_container(container)
    
    def down(self):
        """Stop all containers"""
        if not self.containers:
            click.echo(f"{YELLOW}⚠{NC} No containers defined in {self.config_file}")
            return
        
        click.echo(f"{BOLD}Stopping containers...{NC}")
        
        # Stop in reverse dependency order
        for container in reversed(self.get_container_order()):
            name = container['name']
            if self.container_running(name):
                click.echo(f"{BLUE}ℹ{NC} Stopping {name}...")
                self.run_command(['lxc', 'stop', name])
                click.echo(f"{GREEN}✓{NC} Stopped {name}")
            else:
                click.echo(f"{YELLOW}⚠{NC} Container {name} is not running")
    
    def list_containers(self):
        """List all containers with their status"""
        if not self.containers:
            click.echo(f"{YELLOW}⚠{NC} No containers defined in {self.config_file}")
            return
        
        click.echo(f"{BOLD}Containers from {self.config_file}:{NC}")
        click.echo("=" * 60)
        
        # Load port forwards
        port_forwards = {}
        if os.path.exists(PORT_FORWARDS_FILE):
            with open(PORT_FORWARDS_FILE, 'r') as f:
                forwards = json.load(f)
                for fw in forwards:
                    container = fw['container']
                    if container not in port_forwards:
                        port_forwards[container] = []
                    port_forwards[container].append(f"{fw['host_port']}:{fw['container_port']}")
        
        for container in self.containers:
            name = container['name']
            
            # Get container info
            result = self.run_command(['lxc', 'list', name, '--format=json'], check=False)
            
            if result.returncode != 0 or not result.stdout:
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
            
            # Show IP address if running
            if status == 'Running' and info.get('state') and info['state'].get('network'):
                for iface, details in info['state']['network'].items():
                    if iface == 'lo':
                        continue
                    for addr in details.get('addresses', []):
                        if addr['family'] == 'inet' and not addr['address'].startswith('fe80'):
                            click.echo(f"    IP: {addr['address']}")
                            break
            
            # Show port mappings
            if name in port_forwards:
                click.echo(f"    Ports: {', '.join(port_forwards[name])}")
            
            # Show services
            if 'services' in container:
                if isinstance(container['services'], dict):
                    services = list(container['services'].keys())
                else:
                    services = [s.get('name', 'unnamed') for s in container['services'] if isinstance(s, dict)]
                if services:
                    click.echo(f"    Services: {', '.join(services)}")
        
        click.echo("=" * 60)

@click.group()
def cli():
    """LXC Compose v2 - Container orchestration for LXC"""
    pass

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file')
def up(file):
    """Create and start containers"""
    compose = LXCCompose(file)
    compose.up()

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file')
def down(file):
    """Stop containers"""
    compose = LXCCompose(file)
    compose.down()

@cli.command('list')
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file')
def list_cmd(file):
    """List containers and status"""
    compose = LXCCompose(file)
    compose.list_containers()

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file')
def status(file):
    """Alias for list"""
    compose = LXCCompose(file)
    compose.list_containers()

if __name__ == '__main__':
    cli()