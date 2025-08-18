#!/usr/bin/env python3

import click
import yaml
import subprocess
import os
import sys
import json
import time
from pathlib import Path
from typing import Dict, List, Optional

RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
BOLD = '\033[1m'
NC = '\033[0m'

DEFAULT_CONFIG = 'lxc-compose.yml'
REGISTRY_FILE = '/etc/lxc-compose/registry.json'
PORT_FORWARDS_FILE = '/etc/lxc-compose/port-forwards.json'

class LXCCompose:
    def __init__(self, config_file: str):
        self.config_file = config_file
        self.config = self.load_config()
        
    def load_config(self) -> Dict:
        """Load configuration from YAML file"""
        if not os.path.exists(self.config_file):
            click.echo(f"{RED}✗{NC} Config file not found: {self.config_file}")
            sys.exit(1)
            
        with open(self.config_file, 'r') as f:
            return yaml.safe_load(f)
    
    def run_command(self, cmd: List[str], check: bool = True) -> subprocess.CompletedProcess:
        """Run a command and return the result"""
        try:
            return subprocess.run(cmd, capture_output=True, text=True, check=check)
        except subprocess.CalledProcessError as e:
            if check:
                click.echo(f"{RED}✗{NC} Command failed: {' '.join(cmd)}")
                click.echo(f"  {e.stderr}")
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
    
    def create_container(self, container: Dict) -> bool:
        """Create a new container"""
        name = container['name']
        
        if self.container_exists(name):
            click.echo(f"{YELLOW}⚠{NC} Container {name} already exists")
            return False
        
        click.echo(f"{BLUE}ℹ{NC} Creating container {name}...")
        
        # Create container - use minimal cloud image by default
        image = container.get('image', 'ubuntu-minimal:22.04')
        
        # Check if image exists locally
        check_image = self.run_command(['lxc', 'image', 'list', image, '--format=json'], check=False)
        if check_image.returncode != 0 or not json.loads(check_image.stdout):
            click.echo(f"{YELLOW}⚠{NC} Image {image} not found locally. Downloading...")
            click.echo(f"  This may take 5-10 minutes on first use. Future containers will be fast.")
        
        cmd = ['lxc', 'launch', image, name]
        
        # Add network config if specified
        if 'ip' in container:
            cmd.extend(['--network', f'lxcbr0:eth0,ipv4.address={container["ip"]}'])
        
        self.run_command(cmd)
        
        # Wait for container to be ready
        time.sleep(3)
        
        # Setup mounts
        if 'mounts' in container:
            for mount in container['mounts']:
                source = os.path.expanduser(mount['source'])
                target = mount['target']
                
                # Create source directory if it doesn't exist
                os.makedirs(source, exist_ok=True)
                
                # Add device
                self.run_command([
                    'lxc', 'config', 'device', 'add', name,
                    f"mount-{target.replace('/', '-')}", 'disk',
                    f'source={source}', f'path={target}'
                ])
        
        # Install and start services
        if 'services' in container:
            for service in container['services']:
                self.setup_service(name, service)
        
        # Setup port forwarding
        if 'ports' in container:
            self.setup_port_forwarding(name, container['ports'], container.get('ip'))
        
        click.echo(f"{GREEN}✓{NC} Container {name} created successfully")
        return True
    
    def setup_service(self, container_name: str, service: Dict):
        """Setup a service in the container"""
        service_name = service.get('name', '')
        command = service.get('command', '')
        
        if not command:
            return
        
        click.echo(f"  Setting up service: {service_name}")
        
        # Create systemd service or run command
        if service.get('type') == 'systemd':
            # Create systemd service file
            service_content = f"""[Unit]
Description={service_name}
After=network.target

[Service]
Type=simple
ExecStart={command}
Restart=always

[Install]
WantedBy=multi-user.target
"""
            # Write service file to container
            self.run_command([
                'lxc', 'exec', container_name, '--', 
                'bash', '-c', f'cat > /etc/systemd/system/{service_name}.service << EOF\n{service_content}\nEOF'
            ])
            
            # Enable and start service
            self.run_command(['lxc', 'exec', container_name, '--', 'systemctl', 'enable', f'{service_name}.service'])
            self.run_command(['lxc', 'exec', container_name, '--', 'systemctl', 'start', f'{service_name}.service'])
        else:
            # Just run the command
            self.run_command(['lxc', 'exec', container_name, '--', 'bash', '-c', command])
    
    def setup_port_forwarding(self, container_name: str, ports: List, container_ip: Optional[str]):
        """Setup port forwarding for container"""
        if not container_ip:
            # Get container IP
            result = self.run_command(['lxc', 'list', container_name, '--format=json'])
            containers = json.loads(result.stdout)
            if containers and containers[0].get('state', {}).get('network', {}).get('eth0'):
                for addr in containers[0]['state']['network']['eth0']['addresses']:
                    if addr['family'] == 'inet' and not addr['address'].startswith('fe80'):
                        container_ip = addr['address']
                        break
        
        if not container_ip:
            click.echo(f"{YELLOW}⚠{NC} Could not determine IP for {container_name}")
            return
        
        # Load existing port forwards
        forwards = []
        if os.path.exists(PORT_FORWARDS_FILE):
            with open(PORT_FORWARDS_FILE, 'r') as f:
                forwards = json.load(f)
        
        for port_config in ports:
            if isinstance(port_config, int):
                host_port = container_port = port_config
            elif isinstance(port_config, str) and ':' in port_config:
                host_port, container_port = port_config.split(':')
                host_port = int(host_port)
                container_port = int(container_port)
            elif isinstance(port_config, dict):
                host_port = port_config.get('host', port_config.get('port'))
                container_port = port_config.get('container', port_config.get('port'))
            else:
                continue
            
            # Add iptables rule
            self.run_command([
                'sudo', 'iptables', '-t', 'nat', '-A', 'PREROUTING',
                '-p', 'tcp', '--dport', str(host_port),
                '-j', 'DNAT', '--to-destination', f'{container_ip}:{container_port}'
            ], check=False)
            
            # Save to registry
            forwards.append({
                'container': container_name,
                'host_port': host_port,
                'container_port': container_port,
                'container_ip': container_ip
            })
        
        # Save port forwards
        os.makedirs(os.path.dirname(PORT_FORWARDS_FILE), exist_ok=True)
        with open(PORT_FORWARDS_FILE, 'w') as f:
            json.dump(forwards, f, indent=2)
    
    def up(self):
        """Create and start all containers"""
        containers = self.config.get('containers', [])
        
        if not containers:
            click.echo(f"{YELLOW}⚠{NC} No containers defined in {self.config_file}")
            return
        
        click.echo(f"{BOLD}Starting LXC Compose...{NC}")
        
        for container in containers:
            self.create_container(container)
    
    def down(self):
        """Stop all containers"""
        containers = self.config.get('containers', [])
        
        if not containers:
            click.echo(f"{YELLOW}⚠{NC} No containers defined in {self.config_file}")
            return
        
        click.echo(f"{BOLD}Stopping containers...{NC}")
        
        for container in containers:
            name = container['name']
            if self.container_running(name):
                click.echo(f"{BLUE}ℹ{NC} Stopping {name}...")
                self.run_command(['lxc', 'stop', name])
                click.echo(f"{GREEN}✓{NC} Stopped {name}")
            else:
                click.echo(f"{YELLOW}⚠{NC} Container {name} is not running")
    
    def destroy(self):
        """Destroy all containers"""
        containers = self.config.get('containers', [])
        
        if not containers:
            click.echo(f"{YELLOW}⚠{NC} No containers defined in {self.config_file}")
            return
        
        click.echo(f"{BOLD}Destroying containers...{NC}")
        
        for container in containers:
            name = container['name']
            if self.container_exists(name):
                if self.container_running(name):
                    click.echo(f"{BLUE}ℹ{NC} Stopping {name}...")
                    self.run_command(['lxc', 'stop', name])
                
                click.echo(f"{BLUE}ℹ{NC} Destroying {name}...")
                self.run_command(['lxc', 'delete', name])
                click.echo(f"{GREEN}✓{NC} Destroyed {name}")
            else:
                click.echo(f"{YELLOW}⚠{NC} Container {name} does not exist")
    
    def start(self):
        """Start all containers"""
        containers = self.config.get('containers', [])
        
        if not containers:
            click.echo(f"{YELLOW}⚠{NC} No containers defined in {self.config_file}")
            return
        
        click.echo(f"{BOLD}Starting containers...{NC}")
        
        for container in containers:
            name = container['name']
            if not self.container_exists(name):
                click.echo(f"{YELLOW}⚠{NC} Container {name} does not exist. Run 'lxc-compose up' first.")
            elif self.container_running(name):
                click.echo(f"{YELLOW}⚠{NC} Container {name} is already running")
            else:
                click.echo(f"{BLUE}ℹ{NC} Starting {name}...")
                self.run_command(['lxc', 'start', name])
                click.echo(f"{GREEN}✓{NC} Started {name}")
    
    def stop(self):
        """Stop all containers (alias for down)"""
        self.down()
    
    def list_containers(self):
        """List all containers and their status"""
        containers = self.config.get('containers', [])
        
        if not containers:
            click.echo(f"{YELLOW}⚠{NC} No containers defined in {self.config_file}")
            return
        
        click.echo(f"\n{BOLD}Containers:{NC}")
        click.echo("=" * 60)
        
        # Load port forwards
        port_forwards = {}
        if os.path.exists(PORT_FORWARDS_FILE):
            with open(PORT_FORWARDS_FILE, 'r') as f:
                forwards = json.load(f)
                for fw in forwards:
                    if fw['container'] not in port_forwards:
                        port_forwards[fw['container']] = []
                    port_forwards[fw['container']].append(f"{fw['host_port']}→{fw['container_port']}")
        
        for container in containers:
            name = container['name']
            
            # Get status
            if not self.container_exists(name):
                status = f"{RED}Not Created{NC}"
                ip = "N/A"
            else:
                result = self.run_command(['lxc', 'list', name, '--format=json'])
                containers_info = json.loads(result.stdout)
                
                if containers_info:
                    info = containers_info[0]
                    state = info.get('status', 'Unknown')
                    
                    if state == 'Running':
                        status = f"{GREEN}Running{NC}"
                    elif state == 'Stopped':
                        status = f"{YELLOW}Stopped{NC}"
                    else:
                        status = state
                    
                    # Get IP address
                    ip = "N/A"
                    if info.get('state', {}).get('network', {}).get('eth0'):
                        for addr in info['state']['network']['eth0']['addresses']:
                            if addr['family'] == 'inet' and not addr['address'].startswith('fe80'):
                                ip = addr['address']
                                break
                else:
                    status = f"{RED}Unknown{NC}"
                    ip = "N/A"
            
            click.echo(f"\n{CYAN}{name}{NC}")
            click.echo(f"  Status: {status}")
            click.echo(f"  IP: {ip}")
            
            # Show port mappings
            if name in port_forwards:
                click.echo(f"  Ports: {', '.join(port_forwards[name])}")
            
            # Show services
            if 'services' in container:
                services = [s.get('name', 'unnamed') for s in container['services']]
                click.echo(f"  Services: {', '.join(services)}")
        
        click.echo("=" * 60)

@click.group()
def cli():
    """LXC Compose - Simple container orchestration for LXC"""
    pass

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file (default: lxc-compose.yml)')
def up(file):
    """Create and start containers"""
    compose = LXCCompose(file)
    compose.up()

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file (default: lxc-compose.yml)')
def down(file):
    """Stop containers"""
    compose = LXCCompose(file)
    compose.down()

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file (default: lxc-compose.yml)')
def destroy(file):
    """Stop and destroy containers"""
    compose = LXCCompose(file)
    
    # Confirm destruction
    click.echo(f"{YELLOW}⚠{NC} This will destroy all containers and their data!")
    if click.confirm('Are you sure?'):
        compose.destroy()
    else:
        click.echo("Aborted.")

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file (default: lxc-compose.yml)')
def start(file):
    """Start containers"""
    compose = LXCCompose(file)
    compose.start()

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file (default: lxc-compose.yml)')
def stop(file):
    """Stop containers"""
    compose = LXCCompose(file)
    compose.stop()

@cli.command('list')
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file (default: lxc-compose.yml)')
def list_cmd(file):
    """List containers and their status"""
    compose = LXCCompose(file)
    compose.list_containers()

@cli.command()
@click.option('-f', '--file', default=DEFAULT_CONFIG, help='Config file (default: lxc-compose.yml)')
def status(file):
    """Show detailed status (alias for list)"""
    compose = LXCCompose(file)
    compose.list_containers()

if __name__ == '__main__':
    cli()