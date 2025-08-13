# /srv/lxc-compose/cli/lxc_compose.py
#!/usr/bin/env python3

import click
import yaml
import subprocess
import os
import sys
from pathlib import Path

class LXCCompose:
    def __init__(self, config_file):
        self.config_file = config_file
        self.config = self.load_config()
        
    def load_config(self):
        with open(self.config_file, 'r') as f:
            return yaml.safe_load(f)
    
    def create_container(self):
        """Create and configure LXC container"""
        # Implementation here
        pass
    
    def setup_networking(self):
        """Configure static IP and hosts file"""
        # Implementation here
        pass
    
    def setup_supervisor(self):
        """Generate supervisor config from YAML"""
        # Implementation here
        pass
    
    def mount_directories(self):
        """Setup directory mounts"""
        # Implementation here
        pass

@click.group()
def cli():
    """LXC Compose - Docker Compose-like orchestration for LXC"""
    pass

@cli.command()
@click.option('-f', '--file', required=True, help='Configuration file')
def up(file):
    """Create and start container with all services"""
    compose = LXCCompose(file)
    compose.create_container()
    click.echo(f"Container {compose.config['container']['name']} started")

@cli.command()
@click.option('-f', '--file', required=True)
def down(file):
    """Stop and destroy container"""
    # Implementation
    pass


@cli.command()
@click.option('-f', '--file', required=True)
@click.argument('service')
def logs(file, service):
    """Tail logs for a specific service"""
    # Implementation
    pass

@cli.command()
@click.option('-f', '--file', required=True)
@click.argument('service')
@click.argument('command', nargs=-1)
def exec(file, service, command):
    """Execute command in container context"""
    # Implementation
    pass

@cli.command()
def doctor():
    """Check system health and diagnose issues"""
    script_path = '/srv/lxc-compose/update.sh'
    if os.path.exists(script_path):
        subprocess.run(['sudo', script_path, 'doctor'])
    else:
        click.echo(f"Error: Update script not found at {script_path}", err=True)

@cli.command()
def update():
    """Update LXC Compose to the latest version"""
    script_path = '/srv/lxc-compose/update.sh'
    if os.path.exists(script_path):
        subprocess.run(['sudo', script_path, 'update'])
    else:
        click.echo(f"Error: Update script not found at {script_path}", err=True)

@cli.command()
def wizard():
    """Run the interactive setup wizard"""
    script_path = '/srv/lxc-compose/wizard.sh'
    if os.path.exists(script_path):
        subprocess.run(['sudo', script_path])
    else:
        click.echo(f"Error: Wizard script not found at {script_path}", err=True)

@cli.command(name='list')
@click.option('--running', is_flag=True, help='Show only running containers')
def list_containers(running):
    """List all containers"""
    if running:
        subprocess.run(['sudo', 'lxc-ls', '--running'])
    else:
        subprocess.run(['sudo', 'lxc-ls', '--fancy'])

@cli.command()
@click.argument('container')
def attach(container):
    """Attach to a container shell"""
    subprocess.run(['sudo', 'lxc-attach', '-n', container])

@cli.command()
@click.argument('container', required=False)
def info(container):
    """Show container information"""
    if container:
        subprocess.run(['sudo', 'lxc-info', '-n', container])
    else:
        # Show info for all containers
        result = subprocess.run(['sudo', 'lxc-ls'], capture_output=True, text=True)
        if result.returncode == 0:
            containers = result.stdout.strip().split()
            for c in containers:
                click.echo(f"\n=== {c} ===")
                subprocess.run(['sudo', 'lxc-info', '-n', c])

@cli.command()
@click.argument('container')
def start(container):
    """Start a container"""
    subprocess.run(['sudo', 'lxc-start', '-n', container])

@cli.command()
@click.argument('container')
def stop(container):
    """Stop a container"""
    subprocess.run(['sudo', 'lxc-stop', '-n', container])

@cli.command()
@click.argument('container')
def restart(container):
    """Restart a container"""
    subprocess.run(['sudo', 'lxc-stop', '-n', container])
    subprocess.run(['sudo', 'lxc-start', '-n', container])

@cli.command()
def start_all():
    """Start all containers"""
    result = subprocess.run(['sudo', 'lxc-ls'], capture_output=True, text=True)
    if result.returncode == 0:
        containers = result.stdout.strip().split()
        for container in containers:
            click.echo(f"Starting {container}...")
            subprocess.run(['sudo', 'lxc-start', '-n', container])

@cli.command()
def stop_all():
    """Stop all running containers"""
    result = subprocess.run(['sudo', 'lxc-ls', '--running'], capture_output=True, text=True)
    if result.returncode == 0:
        containers = result.stdout.strip().split()
        for container in containers:
            click.echo(f"Stopping {container}...")
            subprocess.run(['sudo', 'lxc-stop', '-n', container])

@cli.command()
def ports():
    """Show listening ports"""
    subprocess.run(['sudo', 'netstat', '-tulpn'])

@cli.command()
@click.argument('container')
@click.argument('command', nargs=-1, required=True)
def execute(container, command):
    """Execute a command in a container"""
    cmd = ['sudo', 'lxc-attach', '-n', container, '--'] + list(command)
    subprocess.run(cmd)

@cli.command()
@click.argument('container')
def destroy(container):
    """Destroy a container (requires confirmation)"""
    if click.confirm(f"Are you sure you want to destroy container '{container}'?"):
        # Stop if running
        subprocess.run(['sudo', 'lxc-stop', '-n', container], stderr=subprocess.DEVNULL)
        # Destroy
        subprocess.run(['sudo', 'lxc-destroy', '-n', container])
        click.echo(f"Container '{container}' destroyed")
    else:
        click.echo("Cancelled")

@cli.command()
def status():
    """Show system status"""
    click.echo("\n=== LXC Network ===")
    subprocess.run(['ip', 'addr', 'show', 'lxcbr0'], stderr=subprocess.DEVNULL)
    
    click.echo("\n=== Containers ===")
    subprocess.run(['sudo', 'lxc-ls', '--fancy'])
    
    click.echo("\n=== Disk Usage ===")
    subprocess.run(['df', '-h', '/srv'])

@cli.command()
@click.argument('service', type=click.Choice(['db', 'database', 'postgres', 'postgresql', 'redis', 'cache'], case_sensitive=False))
@click.argument('container', default='datastore')
def test(service, container):
    """Test database or Redis connectivity in a container"""
    service = service.lower()
    
    # Check if container exists and is running
    result = subprocess.run(['sudo', 'lxc-info', '-n', container], capture_output=True, text=True)
    if result.returncode != 0:
        click.echo(f"Error: Container '{container}' not found", err=True)
        return
    
    if 'STOPPED' in result.stdout:
        click.echo(f"Error: Container '{container}' is not running", err=True)
        click.echo(f"Start it with: lxc-compose start {container}")
        return
    
    # Test PostgreSQL
    if service in ['db', 'database', 'postgres', 'postgresql']:
        click.echo(f"Testing PostgreSQL in container '{container}'...")
        
        # Test connection as postgres user
        cmd = ['sudo', 'lxc-attach', '-n', container, '--', 
               'sudo', '-u', 'postgres', 'psql', '-c', 'SELECT version();']
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            click.echo("✓ PostgreSQL is running and accessible")
            # Extract and show version
            for line in result.stdout.split('\n'):
                if 'PostgreSQL' in line:
                    click.echo(f"  Version: {line.strip()}")
                    break
            
            # Show databases
            cmd = ['sudo', 'lxc-attach', '-n', container, '--', 
                   'sudo', '-u', 'postgres', 'psql', '-l', '-t']
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                databases = [db.split('|')[0].strip() for db in result.stdout.strip().split('\n') 
                           if '|' in db and db.split('|')[0].strip()]
                click.echo(f"  Databases: {', '.join(databases[:5])}")  # Show first 5 databases
            
            # Show connection info
            # Get container IP
            info_cmd = ['sudo', 'lxc-info', '-n', container, '-iH']
            info_result = subprocess.run(info_cmd, capture_output=True, text=True)
            if info_result.returncode == 0:
                ips = info_result.stdout.strip().split('\n')
                if ips:
                    click.echo(f"  Connection: psql -h {ips[0]} -U postgres")
        else:
            click.echo("✗ PostgreSQL test failed")
            if 'psql: error' in result.stderr:
                click.echo(f"  Error: {result.stderr.strip()}")
            elif 'command not found' in result.stderr:
                click.echo("  PostgreSQL does not appear to be installed")
            else:
                click.echo("  PostgreSQL may not be running or properly configured")
            
    # Test Redis
    elif service in ['redis', 'cache']:
        click.echo(f"Testing Redis in container '{container}'...")
        
        # Test Redis ping
        cmd = ['sudo', 'lxc-attach', '-n', container, '--', 'redis-cli', 'ping']
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0 and 'PONG' in result.stdout:
            click.echo("✓ Redis is running and accessible")
            
            # Get Redis version
            cmd = ['sudo', 'lxc-attach', '-n', container, '--', 'redis-cli', 'info', 'server']
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if line.startswith('redis_version:'):
                        click.echo(f"  Version: Redis {line.split(':')[1]}")
                        break
            
            # Test set/get
            test_key = 'lxc_compose_test'
            test_value = 'test_successful'
            
            # Set a test value
            cmd = ['sudo', 'lxc-attach', '-n', container, '--', 
                   'redis-cli', 'set', test_key, test_value]
            subprocess.run(cmd, capture_output=True)
            
            # Get the test value
            cmd = ['sudo', 'lxc-attach', '-n', container, '--', 
                   'redis-cli', 'get', test_key]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if test_value in result.stdout:
                click.echo("  Read/Write: Working")
            
            # Clean up test key
            cmd = ['sudo', 'lxc-attach', '-n', container, '--', 
                   'redis-cli', 'del', test_key]
            subprocess.run(cmd, capture_output=True)
            
            # Show connection info
            info_cmd = ['sudo', 'lxc-info', '-n', container, '-iH']
            info_result = subprocess.run(info_cmd, capture_output=True, text=True)
            if info_result.returncode == 0:
                ips = info_result.stdout.strip().split('\n')
                if ips:
                    click.echo(f"  Connection: redis-cli -h {ips[0]}")
        else:
            click.echo("✗ Redis test failed")
            if 'command not found' in result.stderr:
                click.echo("  Redis does not appear to be installed")
            elif 'Could not connect' in result.stderr:
                click.echo("  Redis is installed but not running")
            else:
                click.echo("  Redis may not be properly configured")

if __name__ == '__main__':
    cli()