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
    """LXC Compose - Docker Compose-like orchestration for LXC
    
    \b
    QUICK START:
      lxc-compose wizard         # Interactive setup wizard
      lxc-compose web            # Open web management interface
      lxc-compose list           # List all containers
      lxc-compose status         # System overview
    
    \b
    WEB INTERFACE:
      lxc-compose web            # Open web management interface
      lxc-compose manager        # Control web interface service
    
    \b
    MAINTENANCE:
      lxc-compose update         # Update to latest version
      lxc-compose reinstall      # Reinstall and reconfigure
      lxc-compose doctor         # Check system health
    
    \b
    COMMON EXAMPLES:
      lxc-compose test db        # Test PostgreSQL in datastore
      lxc-compose test redis     # Test Redis in datastore
      lxc-compose attach datastore  # Enter container shell
      lxc-compose execute datastore redis-cli ping
    
    \b
    Use 'lxc-compose COMMAND --help' for more information on a command.
    """
    pass



@cli.command()
@click.option('--fix', is_flag=True, help='Attempt to fix common issues automatically')
def doctor(fix):
    """Check system health and diagnose issues
    
    \b
    This command will:
    - Check OS compatibility
    - Verify all dependencies are installed
    - Check Python modules
    - Verify LXD/LXC installation
    - Check network configuration
    - Verify directory structure
    - Test services
    
    Use --fix to attempt automatic fixes for common issues.
    """
    # Use wizard for doctor functionality
    cmd = ['sudo', '/srv/lxc-compose/wizard.sh', 'doctor']
    if fix:
        # The wizard will prompt for fix mode
        click.echo("Running diagnostics with fix mode...")
    result = subprocess.run(cmd)
    sys.exit(result.returncode)

@cli.command()
def update():
    """Update LXC Compose to the latest version"""
    # Use wizard for update functionality
    subprocess.run(['sudo', '/srv/lxc-compose/wizard.sh', 'update'])

@cli.command()
def wizard():
    """Run the interactive setup wizard"""
    script_path = '/srv/lxc-compose/wizard.sh'
    if os.path.exists(script_path):
        subprocess.run(['sudo', script_path])
    else:
        click.echo(f"Error: Wizard script not found at {script_path}", err=True)

@cli.command()
@click.option('--force', is_flag=True, help='Force reinstall even if already installed')
def reinstall(force):
    """Reinstall LXC Compose and reconfigure the system
    
    \b
    This command will:
    - Re-download and install LXC Compose
    - Reconfigure the LXC host environment
    - Reinstall snap packages if needed
    
    \b
    Examples:
      lxc-compose reinstall        # Reinstall and reconfigure
      lxc-compose reinstall --force # Force complete reinstallation
    """
    click.echo("Starting LXC Compose reinstallation...")
    
    # Set environment variable for force mode
    env = os.environ.copy()
    if force:
        env['FORCE_REINSTALL'] = 'true'
        click.echo("Force reinstall mode enabled")
    
    # Run the install script with reinstall mode
    install_script = '/srv/lxc-compose/install.sh'
    if os.path.exists(install_script):
        result = subprocess.run(['sudo', 'bash', install_script], env=env)
        if result.returncode == 0:
            click.echo("\n✓ Reinstallation completed successfully!")
            click.echo("\nNow run: lxc-compose wizard")
        else:
            click.echo("\n✗ Reinstallation failed. Check the error messages above.", err=True)
            sys.exit(1)
    else:
        # If install script doesn't exist, download and run get.sh
        click.echo("Install script not found. Downloading fresh installation...")
        subprocess.run(['bash', '-c', 'curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | sudo bash'])

@cli.command(name='list')
@click.option('--running', is_flag=True, help='Show only running containers')
def list_containers(running):
    """List all containers
    
    \b
    Examples:
      lxc-compose list           # Show all containers with details
      lxc-compose list --running # Show only running containers
    """
    if running:
        subprocess.run(['sudo', 'lxc-ls', '--running'])
    else:
        subprocess.run(['sudo', 'lxc-ls', '--fancy'])

@cli.command()
@click.argument('container')
def attach(container):
    """Attach to a container shell
    
    \b
    Examples:
      lxc-compose attach datastore  # Enter the datastore container
      lxc-compose attach app-1      # Enter app-1 container
    """
    subprocess.run(['sudo', 'lxc-attach', '-n', container])

@cli.command()
@click.argument('container', required=False)
def info(container):
    """Show container information
    
    \b
    Examples:
      lxc-compose info             # Show info for all containers
      lxc-compose info datastore   # Show info for specific container
    """
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
    """Start a container
    
    \b
    Examples:
      lxc-compose start datastore  # Start the datastore container
      lxc-compose start app-1      # Start app-1 container
    """
    subprocess.run(['sudo', 'lxc-start', '-n', container])

@cli.command()
@click.argument('container')
def stop(container):
    """Stop a container
    
    \b
    Examples:
      lxc-compose stop datastore   # Stop the datastore container
      lxc-compose stop app-1       # Stop app-1 container
    """
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
    """Execute a command in a container
    
    \b
    Examples:
      lxc-compose execute datastore redis-cli ping
      lxc-compose execute datastore sudo -u postgres psql -l
      lxc-compose execute app-1 python3 --version
      lxc-compose execute app-1 cat /etc/os-release
    """
    cmd = ['sudo', 'lxc-attach', '-n', container, '--'] + list(command)
    subprocess.run(cmd)

@cli.command()
@click.argument('container')
@click.argument('command', nargs=-1, required=True)
def exec(container, command):
    """Execute a command in a container (alias for execute)
    
    \b
    Examples:
      lxc-compose exec datastore redis-cli ping
      lxc-compose exec datastore sudo -u postgres psql -l
      lxc-compose exec app-1 python3 --version
      lxc-compose exec app-1 cat /etc/os-release
    """
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
    """Test database or Redis connectivity in a container
    
    \b
    Examples:
      lxc-compose test db          # Test PostgreSQL in datastore
      lxc-compose test redis       # Test Redis in datastore  
      lxc-compose test db mycontainer    # Test in specific container
      lxc-compose test postgres datastore # Using alias names
      lxc-compose test cache datastore    # 'cache' for Redis
    
    \b
    Service aliases:
      PostgreSQL: db, database, postgres, postgresql
      Redis: redis, cache
    """
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
            if result.stderr:
                if 'psql: error' in result.stderr:
                    click.echo(f"  Error: {result.stderr.strip()}")
                elif 'command not found' in result.stderr:
                    click.echo("  PostgreSQL does not appear to be installed")
                else:
                    click.echo(f"  Error output: {result.stderr.strip()}")
            if result.stdout:
                click.echo(f"  Output: {result.stdout.strip()}")
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
            if result.stderr:
                if 'command not found' in result.stderr:
                    click.echo("  Redis does not appear to be installed")
                elif 'Could not connect' in result.stderr:
                    click.echo("  Redis is installed but not running")
                else:
                    click.echo(f"  Error output: {result.stderr.strip()}")
            if result.stdout:
                click.echo(f"  Output: {result.stdout.strip()}")
            click.echo("  Redis may not be properly configured")

@cli.command()
def web():
    """Open web management interface
    
    \b
    This command will:
    - Check if the Flask manager is running
    - Display the web interface URL
    - Optionally restart the service if needed
    """
    import socket
    
    # Get host IP
    hostname = socket.gethostname()
    try:
        host_ip = subprocess.run(['hostname', '-I'], capture_output=True, text=True).stdout.split()[0]
    except:
        host_ip = "localhost"
    
    # Check if Flask manager is running
    result = subprocess.run(['sudo', 'supervisorctl', 'status', 'lxc-compose-manager'], 
                          capture_output=True, text=True)
    
    if result.returncode == 0 and 'RUNNING' in result.stdout:
        click.echo("\n╔══════════════════════════════════════════════════════════════╗")
        click.echo("║           🌐 Web Management Interface 🌐                      ║")
        click.echo("╚══════════════════════════════════════════════════════════════╝\n")
        click.echo(f"[✓] Web Interface: http://{host_ip}:5000\n")
        click.echo("[i] Features available:")
        click.echo("    • View all containers and their status")
        click.echo("    • Create new containers with guided wizard")
        click.echo("    • Manage port forwarding rules")
        click.echo("    • Execute commands via web terminal")
        click.echo("    • Monitor container resources\n")
    else:
        click.echo("[!] Web interface is not running")
        if click.confirm("Would you like to start it?"):
            subprocess.run(['sudo', 'supervisorctl', 'start', 'lxc-compose-manager'])
            click.echo(f"\n[✓] Web interface started at http://{host_ip}:5000")

@cli.command()
@click.argument('action', type=click.Choice(['status', 'start', 'stop', 'restart'], case_sensitive=False), required=False)
@click.option('--start', is_flag=True, help='Start the web interface')
@click.option('--stop', is_flag=True, help='Stop the web interface')
@click.option('--restart', is_flag=True, help='Restart the web interface')
@click.option('--status', is_flag=True, help='Show web interface status')
def manager(action, start, stop, restart, status):
    """Control the web management interface
    
    \b
    Examples:
      lxc-compose manager              # Show status (default)
      lxc-compose manager status       # Check if web interface is running
      lxc-compose manager start        # Start the web interface
      lxc-compose manager stop         # Stop the web interface
      lxc-compose manager restart      # Restart the web interface
      
      # Alternative flag-based usage:
      lxc-compose manager --status     # Check status
      lxc-compose manager --restart    # Restart service
    """
    # Handle new action-based syntax
    if action:
        if action == 'status':
            status = True
        elif action == 'start':
            start = True
        elif action == 'stop':
            stop = True
        elif action == 'restart':
            restart = True
    
    # Default to status if no action specified
    if not any([start, stop, restart, status]):
        status = True
    
    if status:
        result = subprocess.run(['sudo', 'supervisorctl', 'status', 'lxc-compose-manager'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            click.echo(result.stdout.strip())
        else:
            click.echo("[!] Web interface is not configured or supervisor is not running")
    
    if start:
        result = subprocess.run(['sudo', 'supervisorctl', 'start', 'lxc-compose-manager'],
                              capture_output=True, text=True)
        if 'started' in result.stdout.lower() or result.returncode == 0:
            click.echo("[✓] Web interface started")
        else:
            click.echo(f"[!] Failed to start: {result.stdout.strip()}")
    
    if stop:
        result = subprocess.run(['sudo', 'supervisorctl', 'stop', 'lxc-compose-manager'],
                              capture_output=True, text=True)
        if 'stopped' in result.stdout.lower() or result.returncode == 0:
            click.echo("[✓] Web interface stopped")
        else:
            click.echo(f"[!] Failed to stop: {result.stdout.strip()}")
    
    if restart:
        result = subprocess.run(['sudo', 'supervisorctl', 'restart', 'lxc-compose-manager'],
                              capture_output=True, text=True)
        if 'started' in result.stdout.lower() or result.returncode == 0:
            click.echo("[✓] Web interface restarted")
        else:
            click.echo(f"[!] Failed to restart: {result.stdout.strip()}")

@cli.command()
def examples():
    """Show comprehensive examples for all commands"""
    examples_text = """
LXC COMPOSE COMMAND EXAMPLES
============================

SETUP & MAINTENANCE
-------------------
  lxc-compose wizard              # Run interactive setup wizard
  lxc-compose doctor              # Check system health
  lxc-compose update              # Update LXC Compose
  lxc-compose status              # Show system overview
  
WEB MANAGEMENT INTERFACE
------------------------
  lxc-compose web                 # Open web management interface
  lxc-compose manager             # Check web interface status
  lxc-compose manager status      # Check web interface status
  lxc-compose manager start       # Start web interface
  lxc-compose manager stop        # Stop web interface
  lxc-compose manager restart     # Restart web interface

CONTAINER LISTING
-----------------
  lxc-compose list                # List all containers with details
  lxc-compose list --running      # List only running containers
  lxc-compose info                # Info for all containers
  lxc-compose info datastore      # Info for specific container

CONTAINER MANAGEMENT
--------------------
  lxc-compose start datastore     # Start a container
  lxc-compose stop datastore      # Stop a container
  lxc-compose restart app-1       # Restart a container
  lxc-compose start-all           # Start all containers
  lxc-compose stop-all            # Stop all running containers
  lxc-compose destroy test-app    # Destroy container (with confirmation)

CONTAINER ACCESS
----------------
  lxc-compose attach datastore    # Enter container shell
  lxc-compose execute datastore ls -la /srv
  lxc-compose exec app-1 python3 --version  # 'exec' is alias for 'execute'

SERVICE TESTING
---------------
  lxc-compose test db             # Test PostgreSQL in datastore
  lxc-compose test redis          # Test Redis in datastore
  lxc-compose test db app-1       # Test PostgreSQL in app-1
  lxc-compose test postgres mydb  # Using 'postgres' alias
  lxc-compose test cache myredis  # Using 'cache' alias for Redis

DATABASE OPERATIONS
-------------------
  lxc-compose execute datastore sudo -u postgres createdb myapp
  lxc-compose execute datastore sudo -u postgres createuser myuser
  lxc-compose execute datastore sudo -u postgres psql -l
  lxc-compose execute datastore sudo -u postgres psql -c "SELECT version();"

REDIS OPERATIONS
----------------
  lxc-compose execute datastore redis-cli ping
  lxc-compose execute datastore redis-cli info server
  lxc-compose execute datastore redis-cli set mykey "myvalue"
  lxc-compose execute datastore redis-cli get mykey

MONITORING
----------
  lxc-compose ports               # Show all listening ports
  lxc-compose status              # System overview with network & disk

CONFIGURATION FILE OPERATIONS
------------------------------
  lxc-compose up -f config.yml    # Create container from config
  lxc-compose down -f config.yml  # Stop and destroy container
  lxc-compose logs -f config.yml nginx  # View service logs
  lxc-compose exec -f config.yml app bash  # Execute in service

TIPS
----
  • Default container for 'test' command is 'datastore'
  • PostgreSQL aliases: db, database, postgres, postgresql
  • Redis aliases: redis, cache
  • Use 'lxc-compose COMMAND --help' for command-specific help
    """
    click.echo(examples_text)

if __name__ == '__main__':
    cli()