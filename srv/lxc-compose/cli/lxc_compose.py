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
@click.option('--ports', is_flag=True, help='Show port forwarding information')
def list_containers(running, ports):
    """List all containers
    
    \b
    Examples:
      lxc-compose list           # Show all containers with details
      lxc-compose list --running # Show only running containers
      lxc-compose list --ports   # Show containers with port forwarding
    """
    # Sync hosts with reality first
    try:
        from hosts_manager import HostsManager
        hosts_manager = HostsManager()
        hosts_manager.sync_with_reality()
    except:
        pass
    
    if running:
        subprocess.run(['sudo', 'lxc-ls', '--running'])
    else:
        subprocess.run(['sudo', 'lxc-ls', '--fancy'])
    
    # Show port forwarding information if requested or by default
    if ports or not running:
        try:
            from port_manager import PortManager
            manager = PortManager()
            forwards = manager.list_forwards()
            
            if forwards:
                click.echo("\n" + "="*80)
                click.echo("PORT FORWARDING:")
                click.echo("-"*80)
                
                # Group by container
                by_container = {}
                for f in forwards:
                    container = f["container_name"]
                    if container not in by_container:
                        by_container[container] = []
                    by_container[container].append(f)
                
                for container, rules in sorted(by_container.items()):
                    click.echo(f"\n{container}:")
                    for rule in rules:
                        click.echo(f"  • {rule['host_port']} → {rule['container_port']} ({rule['protocol']}) - {rule['description']}")
                
                click.echo()
        except ImportError:
            pass  # Port manager not available

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
    """Show listening ports (deprecated - use 'port list' instead)"""
    subprocess.run(['sudo', 'netstat', '-tulpn'])

@cli.group()
def port():
    """Manage port forwarding between host and containers"""
    pass

@port.command('list')
def port_list():
    """List all port forwarding rules"""
    from port_manager import PortManager, format_port_table
    
    manager = PortManager()
    forwards = manager.list_forwards()
    
    if forwards:
        click.echo("\nPort Forwarding Rules:")
        click.echo("=" * 80)
        click.echo(format_port_table(forwards))
        click.echo()
        
        # Show access info
        interface, host_ip = manager.get_host_interface()
        click.echo(f"Access services from host at: {host_ip}")
    else:
        click.echo("No port forwarding rules configured")
        click.echo("\nAdd a rule with: lxc-compose port add <host-port> <container> <container-port>")

@port.command('add')
@click.argument('host_port', type=int)
@click.argument('container')
@click.argument('container_port', type=int)
@click.option('--protocol', '-p', default='tcp', type=click.Choice(['tcp', 'udp']), help='Protocol (tcp or udp)')
@click.option('--description', '-d', default='', help='Description for this forward')
def port_add(host_port, container, container_port, protocol, description):
    """Add a port forwarding rule
    
    \b
    Examples:
      lxc-compose port add 8080 app-1 80              # Forward 8080 to nginx
      lxc-compose port add 8000 django-app 8000       # Django dev server
      lxc-compose port add 5432 datastore 5432        # PostgreSQL
      lxc-compose port add 6379 datastore 6379        # Redis
      lxc-compose port add 3000 app-1 3000 -p udp     # UDP forward
    """
    from port_manager import PortManager
    
    manager = PortManager()
    if manager.add_forward(host_port, container, container_port, protocol, description):
        manager.save_iptables_rules()
        
        interface, host_ip = manager.get_host_interface()
        click.echo(f"\nAccess at: {host_ip}:{host_port}")

@port.command('remove')
@click.argument('host_port', type=int)
@click.option('--protocol', '-p', default='tcp', type=click.Choice(['tcp', 'udp']), help='Protocol (tcp or udp)')
def port_remove(host_port, protocol):
    """Remove a port forwarding rule
    
    \b
    Examples:
      lxc-compose port remove 8080        # Remove TCP forward on port 8080
      lxc-compose port remove 3000 -p udp  # Remove UDP forward on port 3000
    """
    from port_manager import PortManager
    
    manager = PortManager()
    if manager.remove_forward(host_port, protocol):
        manager.save_iptables_rules()

@port.command('clear')
@click.confirmation_option(prompt='Remove all port forwarding rules?')
def port_clear():
    """Remove all port forwarding rules"""
    from port_manager import PortManager
    
    manager = PortManager()
    manager.clear_all_rules()
    manager.save_iptables_rules()

@port.command('apply')
def port_apply():
    """Apply all configured port forwarding rules (useful after reboot)"""
    from port_manager import PortManager
    
    manager = PortManager()
    if manager.apply_all_rules():
        click.echo("✓ All port forwarding rules applied")
        manager.save_iptables_rules()
    else:
        click.echo("Some rules could not be applied. Check container status.", err=True)

@port.command('update')
@click.argument('container')
def port_update(container):
    """Update IP address for a container's forwarding rules
    
    \b
    Use this after a container restart if its IP changed:
      lxc-compose port update app-1
      lxc-compose port update datastore
    """
    from port_manager import PortManager
    
    manager = PortManager()
    if manager.update_container_ip(container):
        manager.save_iptables_rules()
    else:
        click.echo(f"No rules found for container '{container}' or container not running")

@port.command('show')
@click.argument('container', required=False)
def port_show(container):
    """Show port forwarding rules for a specific container"""
    from port_manager import PortManager, format_port_table
    
    manager = PortManager()
    forwards = manager.list_forwards()
    
    if container:
        forwards = [f for f in forwards if f["container_name"] == container]
        if not forwards:
            click.echo(f"No port forwarding rules for container '{container}'")
            return
    
    click.echo("\nPort Forwarding Rules:")
    click.echo("=" * 80)
    click.echo(format_port_table(forwards))

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

@cli.command(name='exec-direct')
@click.argument('container')
@click.argument('command', nargs=-1, required=True)
def exec_direct(container, command):
    """Execute a command in a container (direct mode)
    
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
        
        # Destroy container
        subprocess.run(['sudo', 'lxc-destroy', '-n', container])
        
        # Clean up hosts entry and IP allocation
        try:
            from hosts_manager import HostsManager
            hosts_manager = HostsManager()
            hosts_manager.remove_container(container)
            click.echo(f"✓ Cleaned up hosts entry for '{container}'")
        except Exception as e:
            # Don't fail if cleanup has issues
            click.echo(f"Warning: Could not clean up hosts entry: {e}", err=True)
        
        click.echo(f"Container '{container}' destroyed")
    else:
        click.echo("Cancelled")

@cli.command()
def cleanup():
    """Clean up orphaned hosts entries and IP allocations
    
    Removes hosts entries for containers that no longer exist.
    Useful after manual container deletion or system issues.
    """
    try:
        from hosts_manager import HostsManager
        hosts_manager = HostsManager()
        
        # Get list of existing containers
        result = subprocess.run(['sudo', 'lxc-ls'], capture_output=True, text=True)
        if result.returncode == 0:
            existing_containers = set(result.stdout.strip().split())
        else:
            existing_containers = set()
        
        # Get all managed entries
        entries = hosts_manager.list_entries()
        removed_count = 0
        
        for entry in entries:
            container_name = entry['container']
            if container_name not in existing_containers:
                click.echo(f"Removing orphaned entry: {container_name}")
                hosts_manager.remove_container(container_name)
                removed_count += 1
        
        if removed_count > 0:
            click.echo(f"✓ Cleaned up {removed_count} orphaned entries")
        else:
            click.echo("✓ No orphaned entries found")
            
    except Exception as e:
        click.echo(f"Error during cleanup: {e}", err=True)
        sys.exit(1)

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
    Service naming:
      Use exact container names - no aliases allowed
      Example: myapp-db, myapp-cache, myapp-web
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
        
        # Test connection as postgres user (cd to /tmp to avoid permission issues)
        cmd = ['sudo', 'lxc-attach', '-n', container, '--', 
               'sh', '-c', 'cd /tmp && sudo -u postgres psql -c "SELECT version();"']
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
                   'sh', '-c', 'cd /tmp && sudo -u postgres psql -l -t']
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

@cli.group(invoke_without_command=True)
@click.pass_context
def web(ctx):
    """Manage the web interface
    
    \b
    Commands:
      lxc-compose web           - Show web interface status
      lxc-compose web status    - Check if running
      lxc-compose web start     - Start the interface
      lxc-compose web stop      - Stop the interface
      lxc-compose web restart   - Restart the interface
      lxc-compose web install   - Install dependencies
      lxc-compose web logs      - View logs
    """
    # If no subcommand, show status
    if ctx.invoked_subcommand is None:
        ctx.invoke(web_status)

@web.command('status')
def web_status():
    """Check web interface status"""
    result = subprocess.run(['pgrep', '-f', 'app.py'], capture_output=True)
    if result.returncode == 0:
        pid = result.stdout.decode().strip()
        click.echo(f"✓ Web interface is running (PID: {pid})")
        # Get IP
        try:
            result = subprocess.run(['ip', '-4', 'addr', 'show'], capture_output=True, text=True)
            import re
            ips = re.findall(r'inet (\d+\.\d+\.\d+\.\d+)', result.stdout)
            ip = next((ip for ip in ips if not ip.startswith('127.')), 'localhost')
        except:
            ip = 'localhost'
        click.echo(f"  Access at: http://{ip}:5000")
    else:
        click.echo("○ Web interface is not running")
        click.echo("  Start with: lxc-compose web start")

@web.command('start')
def web_start():
    """Start the web interface"""
    subprocess.run(['sudo', '/srv/lxc-compose/wizard.sh', 'web-start'])

@web.command('stop')
def web_stop():
    """Stop the web interface"""
    subprocess.run(['sudo', '/srv/lxc-compose/wizard.sh', 'web-stop'])

@web.command('restart')
def web_restart():
    """Restart the web interface"""
    subprocess.run(['sudo', '/srv/lxc-compose/wizard.sh', 'web-restart'])

@web.command('install')
def web_install():
    """Install web interface dependencies"""
    subprocess.run(['sudo', '/srv/lxc-compose/wizard.sh', 'web-install'])

@web.command('logs')
@click.option('-f', '--follow', is_flag=True, help='Follow log output')
@click.option('-n', '--lines', default=50, help='Number of lines to show')
def web_logs(follow, lines):
    """View web interface logs"""
    log_file = '/srv/logs/manager.log'
    if os.path.exists(log_file):
        if follow:
            subprocess.run(['tail', '-f', log_file])
        else:
            subprocess.run(['tail', f'-{lines}', log_file])
    else:
        click.echo("No logs found at /srv/logs/manager.log")

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
@click.option('-f', '--file', 'config_file', 
              default='lxc-compose.yml',
              help='Specify the config file (default: lxc-compose.yml)')
@click.option('-d', '--detach', is_flag=True, help='Run containers in background')
@click.option('--build', is_flag=True, help='Build/rebuild containers')
@click.option('--force-recreate', is_flag=True, help='Recreate containers even if config unchanged')
def up(config_file, detach, build, force_recreate):
    """Create and start containers (Docker Compose-like)
    
    \b
    This command mimics docker-compose up behavior:
    - Reads lxc-compose.yml from current directory (or specified file)
    - Creates containers if they don't exist
    - Starts all defined containers
    - Sets up mounts, networking, and services
    
    \b
    Examples:
      lxc-compose up                    # Use lxc-compose.yml in current dir
      lxc-compose up -f custom.yml      # Use custom config file
      lxc-compose up -d                 # Run in background
      lxc-compose up --build            # Rebuild containers
    """
    # Check if config file exists in current directory
    config_path = Path(config_file)
    if not config_path.is_absolute():
        config_path = Path.cwd() / config_file
    
    if not config_path.exists():
        # Try in /srv/lxc-compose/configs/ as fallback
        fallback_path = Path('/srv/lxc-compose/configs') / config_file
        if fallback_path.exists():
            config_path = fallback_path
        else:
            click.echo(f"Error: Config file '{config_file}' not found", err=True)
            click.echo("Searched in:")
            click.echo(f"  - {Path.cwd() / config_file}")
            click.echo(f"  - {fallback_path}")
            sys.exit(1)
    
    click.echo(f"Using config: {config_path}")
    
    # Parse the YAML config
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
    except Exception as e:
        click.echo(f"Error reading config: {e}", err=True)
        sys.exit(1)
    
    # Import hosts manager
    try:
        from hosts_manager import HostsManager, IPAllocator
        hosts_manager = HostsManager()
        ip_allocator = IPAllocator()
        
        # Sync hosts with reality before starting
        hosts_manager.sync_with_reality()
    except ImportError:
        click.echo("Warning: hosts_manager not available, using static IPs", err=True)
        hosts_manager = None
        ip_allocator = None
    
    # First, determine container dependencies and order
    container_order = []
    if 'containers' in config:
        # Build dependency graph
        containers = config['containers']
        processed = set()
        
        def add_container_with_deps(cont_name):
            if cont_name in processed:
                return
            cont_cfg = containers.get(cont_name, {})
            # Process dependencies first (integrated format)
            if 'depends_on' in cont_cfg:
                for dep in cont_cfg['depends_on']:
                    if dep in containers:
                        add_container_with_deps(dep)
            # Then add this container
            if cont_name not in processed:
                container_order.append(cont_name)
                processed.add(cont_name)
        
        # Process all containers
        for name in containers:
            add_container_with_deps(name)
    
    # Process containers in dependency order
    for name in container_order:
        container_config = config['containers'][name]
        click.echo(f"\nProcessing container: {name}")
        
        # Check if container exists
        result = subprocess.run(
            ['sudo', 'lxc-info', '-n', name],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
        )
        
        container_exists = result.returncode == 0
        
        # For new containers, check for name conflicts first
        if not container_exists and hosts_manager:
            # Check if name exists in hosts file (from another project)
            existing_ip = hosts_manager.get_container_ip(name)
            if existing_ip:
                click.echo(f"\n✗ ERROR: Container name conflict detected!", err=True)
                click.echo(f"  The name '{name}' is already in use on this system.", err=True)
                click.echo(f"\n  This is a problem because container names must be globally unique.", err=True)
                click.echo(f"  Each container name maps to exactly one IP address in /etc/hosts.", err=True)
                click.echo(f"\n  Solution: Use project namespaces to ensure unique names:", err=True)
                click.echo(f"    - projectname-db", err=True)
                click.echo(f"    - projectname-cache", err=True)
                click.echo(f"    - projectname-web", err=True)
                click.echo(f"  Or use reverse domain notation:", err=True)
                click.echo(f"    - com-example-db", err=True)
                click.echo(f"    - org-myproject-app", err=True)
                sys.exit(1)
        
        if container_exists and not force_recreate:
            click.echo(f"  Container '{name}' already exists")
            # Start if not running
            info_result = subprocess.run(['sudo', 'lxc-info', '-n', name], 
                                       capture_output=True, text=True)
            if 'RUNNING' not in info_result.stdout:
                click.echo(f"  Starting container '{name}'...")
                subprocess.run(['sudo', 'lxc-start', '-n', name])
                
            # Update hosts entry even for existing container
            if hosts_manager:
                # Get container IP
                ip_result = subprocess.run(['sudo', 'lxc-info', '-n', name, '-iH'],
                                         capture_output=True, text=True)
                if ip_result.returncode == 0:
                    container_ip = ip_result.stdout.strip().split()[0] if ip_result.stdout.strip() else None
                    if container_ip:
                        # No aliases - only exact container name
                        hosts_manager.add_container(name, container_ip)
        else:
            # Create container
            click.echo(f"  Creating container '{name}'...")
            
            # Get IP allocation
            if hosts_manager and ip_allocator:
                container_ip = ip_allocator.allocate_ip(name)
                click.echo(f"  Allocated IP: {container_ip}")
            else:
                # Fallback to config IP if specified (simplified format only)
                container_ip = container_config.get('ip', '10.0.3.100/24')
            
            # Extract network parts
            if '/' in str(container_ip):
                ip_only = container_ip.split('/')[0]
                cidr = container_ip.split('/')[1]
            else:
                ip_only = container_ip
                cidr = '24'
            
            # Create container with LXC (simplified format only)
            template = container_config.get('template', 'ubuntu')
            release = container_config.get('release', 'jammy')
            
            # Check if template cache exists
            cache_path = f"/var/cache/lxc/{release}/rootfs-amd64"
            if not os.path.exists(cache_path):
                click.echo(f"  (First time using {release} template - downloading, this may take a few minutes...)")
            
            create_cmd = ['sudo', 'lxc-create', '-n', name, '-t', template, '--', '-r', release]
            result = subprocess.run(create_cmd, stderr=subprocess.PIPE, text=True)
            
            if result.returncode != 0:
                click.echo(f"  Failed to create container: {result.stderr}", err=True)
                continue
            
            # Configure container with IP and mounts
            config_lines = [
                f"lxc.include = /usr/share/lxc/config/{template}.common.conf",
                "lxc.arch = linux64",
                "",
                "# Network",
                "lxc.net.0.type = veth",
                "lxc.net.0.link = lxcbr0",
                "lxc.net.0.flags = up",
                f"lxc.net.0.ipv4.address = {ip_only}/{cidr}",
                "lxc.net.0.ipv4.gateway = 10.0.3.1",
                "",
                "# Mount /etc/hosts from host",
                "lxc.mount.entry = /etc/hosts etc/hosts none bind,create=file 0 0",
            ]
            
            # Add custom mounts
            if 'mounts' in container_config:
                config_lines.append("")
                config_lines.append("# Custom mounts")
                for mount in container_config['mounts']:
                    # Support both old format (dict) and new format (string)
                    if isinstance(mount, str):
                        # New Docker-like format: "host:container"
                        if ':' in mount:
                            host_path, container_path = mount.split(':', 1)
                        else:
                            # If no colon, mount to same path in container
                            host_path = mount
                            container_path = mount
                    else:
                        # Old format for backward compatibility
                        host_path = mount.get('host', '.')
                        container_path = mount.get('container', '/mnt')
                    
                    # Convert relative paths
                    if host_path == '.':
                        host_path = str(Path.cwd())
                    elif not host_path.startswith('/'):
                        # Relative path
                        host_path = str(Path.cwd() / host_path)
                    
                    config_lines.append(f"lxc.mount.entry = {host_path} {container_path.lstrip('/')} none bind,create=dir 0 0")
                    click.echo(f"  Configured mount: {host_path} -> {container_path}")
            
            config_lines.extend([
                "",
                "# System",
                "lxc.apparmor.profile = generated",
                "lxc.apparmor.allow_nesting = 1",
                "",
                "# Root filesystem",
                f"lxc.rootfs.path = dir:/var/lib/lxc/{name}/rootfs"
            ])
            
            # Write container config
            config_file = f"/var/lib/lxc/{name}/config"
            config_content = '\n'.join(config_lines)
            
            write_result = subprocess.run(
                ['sudo', 'bash', '-c', f'cat > {config_file}'],
                input=config_content,
                text=True,
                capture_output=True
            )
            
            if write_result.returncode != 0:
                click.echo(f"  Failed to write config: {write_result.stderr}", err=True)
            
            # Start container
            click.echo(f"  Starting container '{name}'...")
            subprocess.run(['sudo', 'lxc-start', '-n', name])
            
            # Wait for container to be ready
            import time
            time.sleep(5)
            
            # Add to hosts file
            if hosts_manager:
                # No aliases - only exact container name
                hosts_manager.add_container(name, ip_only)
                click.echo(f"  Added to /etc/hosts: {name} -> {ip_only}")
            
            # Install packages if specified
            if 'packages' in container_config and container_config['packages']:
                click.echo(f"  Installing packages...")
                packages = ' '.join(container_config['packages'])
                install_cmd = f"apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y {packages}"
                result = subprocess.run(
                    ['sudo', 'lxc-attach', '-n', name, '--', 'bash', '-c', install_cmd],
                    capture_output=True, text=True
                )
                if result.returncode != 0:
                    click.echo(f"    Warning: Some packages failed to install", err=True)
                else:
                    click.echo(f"    Installed: {len(container_config['packages'])} packages")
            
            # Set environment variables
            if 'environment' in container_config:
                env_file_content = ""
                for key, value in container_config['environment'].items():
                    env_file_content += f"export {key}=\"{value}\"\n"
                
                # Write to /etc/environment in container
                write_env_cmd = f"cat >> /etc/environment << 'EOF'\n{env_file_content}EOF"
                subprocess.run(
                    ['sudo', 'lxc-attach', '-n', name, '--', 'bash', '-c', write_env_cmd],
                    capture_output=True
                )
            
            # Configure services
            if 'services' in container_config:
                click.echo(f"  Configuring services...")
                for service_name, service_config in container_config['services'].items():
                    if isinstance(service_config, dict):
                        if service_config.get('type') == 'system':
                            # System service with config script
                            if 'config' in service_config:
                                subprocess.run(
                                    ['sudo', 'lxc-attach', '-n', name, '--', 'bash', '-c', service_config['config']],
                                    capture_output=True
                                )
                        else:
                            # Supervisor service - generate config
                            supervisor_conf = f"""[program:{service_name}]
command={service_config.get('command', '')}
directory={service_config.get('directory', '/app')}
user={service_config.get('user', 'root')}
autostart={str(service_config.get('autostart', True)).lower()}
autorestart={str(service_config.get('autorestart', True)).lower()}
redirect_stderr=true
stdout_logfile=/var/log/{service_name}.log
stderr_logfile=/var/log/{service_name}.error.log
stopasgroup=true
killasgroup=true
"""
                            # Add environment if specified
                            if 'environment' in service_config:
                                env_vars = ','.join([f'{k}="{v}"' for k, v in service_config['environment'].items()])
                                supervisor_conf += f"environment={env_vars}\n"
                            
                            # Write supervisor config to container
                            write_supervisor_cmd = f"""
mkdir -p /etc/supervisor/conf.d
cat > /etc/supervisor/conf.d/{service_name}.conf << 'EOF'
{supervisor_conf}
EOF
"""
                            result = subprocess.run(
                                ['sudo', 'lxc-attach', '-n', name, '--', 'bash', '-c', write_supervisor_cmd],
                                capture_output=True, text=True
                            )
                            
                            if result.returncode == 0:
                                # Install supervisor if not present
                                install_supervisor_cmd = """
if ! command -v supervisord &> /dev/null; then
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y supervisor
fi
# Restart supervisor to load new config
supervisorctl reread && supervisorctl update
"""
                                subprocess.run(
                                    ['sudo', 'lxc-attach', '-n', name, '--', 'bash', '-c', install_supervisor_cmd],
                                    capture_output=True
                                )
                                click.echo(f"    Configured service: {service_name}")
            
            # Run post_install commands
            if 'post_install' in container_config:
                click.echo(f"  Running post-install commands...")
                for cmd_config in container_config['post_install']:
                    if isinstance(cmd_config, dict):
                        cmd_name = cmd_config.get('name', 'Command')
                        cmd = cmd_config.get('command', '')
                        click.echo(f"    Running: {cmd_name}")
                        result = subprocess.run(
                            ['sudo', 'lxc-attach', '-n', name, '--', 'bash', '-c', cmd],
                            capture_output=True, text=True
                        )
                        if result.returncode != 0:
                            click.echo(f"      Warning: Command failed", err=True)
    
    # Collect all port forwards from containers (new integrated format)
    all_port_forwards = []
    
    # Check for new integrated format (ports inside containers)
    if 'containers' in config:
        for name, container_config in config['containers'].items():
            if 'ports' in container_config:
                for port_mapping in container_config['ports']:
                    # Parse Docker-like format "host:container"
                    if isinstance(port_mapping, str) and ':' in port_mapping:
                        parts = port_mapping.split('#')[0].strip().split(':')
                        if len(parts) == 2:
                            all_port_forwards.append({
                                'host_port': int(parts[0]),
                                'container': name,
                                'container_port': int(parts[1])
                            })
                    # Also support old dict format if needed
                    elif isinstance(port_mapping, dict):
                        all_port_forwards.append(port_mapping)
    
    # Also check for old format (separate port_forwards section)
    if 'port_forwards' in config:
        all_port_forwards.extend(config['port_forwards'])
    
    # Apply all collected port forwards
    if all_port_forwards:
        click.echo("\nSetting up port forwarding...")
        for forward in all_port_forwards:
            host_port = forward['host_port']
            container_name = forward['container']
            container_port = forward['container_port']
            
            # Get container IP from hosts manager
            container_ip = hosts_manager.get_container_ip(container_name) if hosts_manager else None
            
            if container_ip:
                click.echo(f"  {host_port} -> {container_name}:{container_port} ({container_ip})")
                
                # Apply iptables rules for port forwarding
                # First, delete any existing rules for this port
                subprocess.run(
                    ['sudo', 'iptables', '-t', 'nat', '-D', 'PREROUTING', 
                     '-p', 'tcp', '--dport', str(host_port), 
                     '-j', 'DNAT', '--to-destination', f'{container_ip}:{container_port}'],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
                
                # Add the new rule
                result = subprocess.run(
                    ['sudo', 'iptables', '-t', 'nat', '-A', 'PREROUTING', 
                     '-p', 'tcp', '--dport', str(host_port), 
                     '-j', 'DNAT', '--to-destination', f'{container_ip}:{container_port}'],
                    capture_output=True, text=True
                )
                
                if result.returncode != 0:
                    click.echo(f"    Warning: Failed to setup port forwarding: {result.stderr}", err=True)
                
                # Also add FORWARD rule to allow the traffic
                subprocess.run(
                    ['sudo', 'iptables', '-A', 'FORWARD', 
                     '-p', 'tcp', '-d', container_ip, '--dport', str(container_port), 
                     '-m', 'state', '--state', 'NEW,ESTABLISHED,RELATED', '-j', 'ACCEPT'],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                )
            else:
                click.echo(f"    Warning: Cannot setup port forwarding for {container_name} (IP not found)", err=True)
    
    if not detach:
        click.echo("\nContainers started. Press Ctrl+C to stop.")
        try:
            # Keep running until interrupted
            subprocess.run(['tail', '-f', '/dev/null'])
        except KeyboardInterrupt:
            click.echo("\nStopping containers...")

@cli.command()
@click.option('-f', '--file', 'config_file', 
              default='lxc-compose.yml',
              help='Specify the config file (default: lxc-compose.yml)')
@click.option('-v', '--volumes', is_flag=True, help='Remove volumes')
@click.option('--remove-orphans', is_flag=True, help='Remove containers not in config')
def down(config_file, volumes, remove_orphans):
    """Stop and remove containers (Docker Compose-like)
    
    \b
    This command mimics docker-compose down behavior:
    - Stops all containers defined in config
    - Optionally removes containers
    - Optionally removes volumes
    
    \b
    Examples:
      lxc-compose down                  # Stop containers
      lxc-compose down -v               # Stop and remove volumes
      lxc-compose down --remove-orphans # Remove undefined containers
    """
    # Check if config file exists
    config_path = Path(config_file)
    if not config_path.is_absolute():
        config_path = Path.cwd() / config_file
    
    if not config_path.exists():
        click.echo(f"Error: Config file '{config_file}' not found", err=True)
        sys.exit(1)
    
    click.echo(f"Using config: {config_path}")
    
    # Parse the YAML config
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
    except Exception as e:
        click.echo(f"Error reading config: {e}", err=True)
        sys.exit(1)
    
    # Import hosts manager
    try:
        from hosts_manager import HostsManager
        hosts_manager = HostsManager()
        
        # Sync hosts with reality before processing
        hosts_manager.sync_with_reality()
    except ImportError:
        hosts_manager = None
    
    # Stop containers
    if 'containers' in config:
        for name in config['containers']:
            click.echo(f"Stopping container: {name}")
            subprocess.run(['sudo', 'lxc-stop', '-n', name], stderr=subprocess.DEVNULL)
            
            # Remove from hosts file
            if hosts_manager:
                hosts_manager.remove_container(name)
            
            if volumes:
                click.echo(f"  Removing container: {name}")
                subprocess.run(['sudo', 'lxc-destroy', '-n', name], stderr=subprocess.DEVNULL)

@cli.command()
@click.option('-f', '--file', 'config_file', 
              default='lxc-compose.yml',
              help='Specify the config file (default: lxc-compose.yml)')
def ps(config_file):
    """List containers defined in config (Docker Compose-like)
    
    \b
    Shows status of containers defined in lxc-compose.yml
    
    \b
    Examples:
      lxc-compose ps                    # Show containers from lxc-compose.yml
      lxc-compose ps -f custom.yml      # Use custom config file
    """
    # Sync hosts with reality first
    try:
        from hosts_manager import HostsManager
        hosts_manager = HostsManager()
        hosts_manager.sync_with_reality()
    except:
        pass
    
    # Check if config file exists
    config_path = Path(config_file)
    if not config_path.is_absolute():
        config_path = Path.cwd() / config_file
    
    if not config_path.exists():
        click.echo(f"Error: Config file '{config_file}' not found", err=True)
        sys.exit(1)
    
    # Parse the YAML config
    try:
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
    except Exception as e:
        click.echo(f"Error reading config: {e}", err=True)
        sys.exit(1)
    
    # Show container status
    if 'containers' in config:
        click.echo("Name                    State      IP")
        click.echo("-" * 50)
        for name in config['containers']:
            # Get container info
            result = subprocess.run(
                ['sudo', 'lxc-info', '-n', name],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
            )
            
            if result.returncode == 0:
                state = "RUNNING" if "RUNNING" in result.stdout else "STOPPED"
                # Try to get IP
                ip_result = subprocess.run(
                    ['sudo', 'lxc-info', '-n', name, '-iH'],
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
                )
                ip = ip_result.stdout.strip() if ip_result.returncode == 0 else "N/A"
            else:
                state = "NOT CREATED"
                ip = "N/A"
            
            click.echo(f"{name:23} {state:10} {ip}")

@cli.command(name='exec')
@click.option('-f', '--file', 'config_file', 
              default='lxc-compose.yml',
              help='Specify the config file (default: lxc-compose.yml)')
@click.argument('container', required=False)
@click.argument('command', nargs=-1)
def exec_compose(config_file, container, command):
    """Execute command in a running container (Docker Compose-like)
    
    \b
    This command mimics docker-compose exec behavior.
    If no container is specified, uses the first one in config.
    
    \b
    Examples:
      lxc-compose exec web bash         # Open bash in web container
      lxc-compose exec db psql          # Open psql in db container
      lxc-compose exec web python manage.py shell
    """
    if not container:
        # Try to read config and use first container
        config_path = Path(config_file)
        if not config_path.is_absolute():
            config_path = Path.cwd() / config_file
        
        if config_path.exists():
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
                if 'containers' in config:
                    container = list(config['containers'].keys())[0]
                    click.echo(f"Using first container: {container}")
    
    if not container:
        click.echo("Error: No container specified and none found in config", err=True)
        sys.exit(1)
    
    if not command:
        command = ['/bin/bash']
    
    # Execute command
    cmd = ['sudo', 'lxc-attach', '-n', container, '--'] + list(command)
    subprocess.run(cmd)

@cli.command()
def examples():
    """Show comprehensive examples for all commands"""
    examples_text = """
LXC COMPOSE COMMAND EXAMPLES
============================

DOCKER COMPOSE-LIKE COMMANDS
-----------------------------
  lxc-compose up                 # Start containers from lxc-compose.yml
  lxc-compose up -d              # Start in background (detached)
  lxc-compose up -f custom.yml   # Use custom config file
  lxc-compose down               # Stop containers
  lxc-compose down -v            # Stop and remove volumes
  lxc-compose ps                 # Show container status
  lxc-compose exec web bash      # Execute command in container
  lxc-compose exec db psql       # Open PostgreSQL console

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
  lxc-compose ports               # Show all listening ports (deprecated)
  lxc-compose status              # System overview with network & disk

PORT FORWARDING
---------------
  lxc-compose port list           # List all port forwarding rules
  lxc-compose port add 8080 app-1 80        # Forward host:8080 to app-1:80
  lxc-compose port add 5432 datastore 5432  # Forward PostgreSQL
  lxc-compose port add 6379 datastore 6379  # Forward Redis
  lxc-compose port remove 8080              # Remove forward on port 8080
  lxc-compose port show app-1               # Show forwards for a container
  lxc-compose port update app-1             # Update IPs after container restart
  lxc-compose port apply                    # Apply all rules (after reboot)
  lxc-compose port clear                    # Remove all forwarding rules

CONFIGURATION FILE OPERATIONS
------------------------------
  lxc-compose up -f config.yml    # Create container from config
  lxc-compose down -f config.yml  # Stop and destroy container
  lxc-compose logs -f config.yml nginx  # View service logs
  lxc-compose exec -f config.yml app bash  # Execute in service

TIPS
----
  • Default container for 'test' command is 'datastore'
  • Container names must be globally unique (use namespaces)
  • Example: myapp-db, myapp-cache, myapp-web
  • Use 'lxc-compose COMMAND --help' for command-specific help
    """
    click.echo(examples_text)

if __name__ == '__main__':
    cli()