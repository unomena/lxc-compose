#!/usr/bin/env python3
"""
Web interface management commands for LXC Compose
This module handles the Flask web interface lifecycle
"""

import click
import subprocess
import os
import sys
import time
import socket

def get_host_ip():
    """Get the host's primary IP address"""
    try:
        result = subprocess.run(['ip', '-4', 'addr', 'show'], capture_output=True, text=True)
        import re
        ips = re.findall(r'inet (\d+\.\d+\.\d+\.\d+)', result.stdout)
        return next((ip for ip in ips if not ip.startswith('127.')), 'localhost')
    except:
        return 'localhost'

def is_web_running():
    """Check if web interface is running"""
    result = subprocess.run(['pgrep', '-f', 'app.py'], capture_output=True)
    return result.returncode == 0

def add_web_commands(cli):
    """Add web interface commands to the CLI"""
    
    @cli.group()
    def web():
        """Manage the web interface
        
        \b
        Commands:
          lxc-compose web status    - Check web interface status
          lxc-compose web start     - Start the web interface
          lxc-compose web stop      - Stop the web interface  
          lxc-compose web restart   - Restart the web interface
          lxc-compose web install   - Install/update dependencies
          lxc-compose web logs      - View web interface logs
        """
        pass
    
    @web.command()
    def status():
        """Check web interface status"""
        if is_web_running():
            result = subprocess.run(['pgrep', '-f', 'app.py'], capture_output=True, text=True)
            pid = result.stdout.strip()
            click.echo(f"✓ Web interface is running (PID: {pid})")
            click.echo(f"  Access at: http://{get_host_ip()}:5000")
        else:
            click.echo("○ Web interface is not running")
            click.echo("  Start with: lxc-compose web start")
    
    @web.command()
    def start():
        """Start the web interface"""
        if is_web_running():
            click.echo("Web interface is already running")
            click.echo(f"Access at: http://{get_host_ip()}:5000")
            return
        
        # Check if directory exists
        if not os.path.exists('/srv/lxc-compose/lxc-compose-manager'):
            click.echo("Web interface not found!")
            if click.confirm("Would you like to install it?"):
                install()
            else:
                return
        
        click.echo("Starting web interface...")
        # Use wizard to start
        result = subprocess.run(['sudo', '/srv/lxc-compose/wizard.sh', 'web-start'])
        
        if result.returncode == 0:
            time.sleep(2)
            if is_web_running():
                click.echo(f"✓ Web interface started")
                click.echo(f"  Access at: http://{get_host_ip()}:5000")
            else:
                click.echo("Failed to start web interface")
                click.echo("Check logs: lxc-compose web logs")
    
    @web.command()
    def stop():
        """Stop the web interface"""
        if not is_web_running():
            click.echo("Web interface is not running")
            return
        
        click.echo("Stopping web interface...")
        subprocess.run(['sudo', '/srv/lxc-compose/wizard.sh', 'web-stop'])
        
        time.sleep(1)
        if not is_web_running():
            click.echo("✓ Web interface stopped")
        else:
            click.echo("Failed to stop web interface")
    
    @web.command()
    def restart():
        """Restart the web interface"""
        click.echo("Restarting web interface...")
        subprocess.run(['sudo', '/srv/lxc-compose/wizard.sh', 'web-restart'])
        
        time.sleep(2)
        if is_web_running():
            click.echo(f"✓ Web interface restarted")
            click.echo(f"  Access at: http://{get_host_ip()}:5000")
        else:
            click.echo("Failed to restart web interface")
    
    @web.command()
    def install():
        """Install/update web interface dependencies"""
        click.echo("Installing web interface dependencies...")
        result = subprocess.run(['sudo', '/srv/lxc-compose/wizard.sh', 'web-install'])
        
        if result.returncode == 0:
            click.echo("✓ Web interface installed")
            click.echo("  Start with: lxc-compose web start")
        else:
            click.echo("Installation failed")
    
    @web.command()
    @click.option('-n', '--lines', default=50, help='Number of lines to show')
    @click.option('-f', '--follow', is_flag=True, help='Follow log output')
    def logs(lines, follow):
        """View web interface logs"""
        log_file = '/srv/logs/manager.log'
        
        if not os.path.exists(log_file):
            click.echo("No logs found at /srv/logs/manager.log")
            click.echo("The web interface may not have been started yet")
            return
        
        if follow:
            subprocess.run(['tail', '-f', log_file])
        else:
            subprocess.run(['tail', f'-{lines}', log_file])
    
    @web.command()
    def open():
        """Open web interface in browser (if possible)"""
        ip = get_host_ip()
        url = f"http://{ip}:5000"
        
        if not is_web_running():
            click.echo("Web interface is not running")
            if click.confirm("Start it now?"):
                start()
            else:
                return
        
        click.echo(f"Opening {url} in browser...")
        
        # Try to open in browser
        try:
            import webbrowser
            webbrowser.open(url)
        except:
            click.echo(f"Could not open browser. Please visit: {url}")
    
    return web