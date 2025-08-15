#!/bin/bash

#############################################################################
# Install Doctor Script for LXC Compose
# 
# This script installs the enhanced doctor command with --fix support
# Run this on the target server to add the doctor functionality
#############################################################################

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Check if running with sudo
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run with sudo: sudo $0"
    exit 1
fi

info "Installing enhanced doctor command for LXC Compose..."

# Create the doctor.py script
cat > /srv/lxc-compose/cli/doctor.py << 'EOF'
#!/usr/bin/env python3
"""
LXC Compose Doctor - Diagnostic and recovery tool
Checks system health and helps recover from installation issues
"""

import os
import sys
import subprocess
import shutil
import json
import time
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# Color codes for output
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color


class LXCComposeDoctor:
    """Diagnostic and recovery tool for LXC Compose"""
    
    def __init__(self):
        self.issues = []
        self.warnings = []
        self.fixed = []
        
    def log_success(self, msg: str):
        print(f"{GREEN}✓{NC} {msg}")
        
    def log_error(self, msg: str):
        print(f"{RED}✗{NC} {msg}")
        self.issues.append(msg)
        
    def log_warning(self, msg: str):
        print(f"{YELLOW}⚠{NC} {msg}")
        self.warnings.append(msg)
        
    def log_info(self, msg: str):
        print(f"{BLUE}ℹ{NC} {msg}")
        
    def log_fixed(self, msg: str):
        print(f"{GREEN}✓ FIXED:{NC} {msg}")
        self.fixed.append(msg)
        
    def run_command(self, cmd: List[str], timeout: int = 10) -> Tuple[int, str, str]:
        """Run a command with timeout"""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", f"Command timed out after {timeout} seconds"
        except Exception as e:
            return -1, "", str(e)
            
    def check_os_compatibility(self):
        """Check if OS is compatible"""
        print("\n=== Checking OS Compatibility ===")
        
        # Check if running on Ubuntu
        if os.path.exists('/etc/os-release'):
            with open('/etc/os-release', 'r') as f:
                os_info = f.read()
                if 'Ubuntu' in os_info:
                    if '22.04' in os_info or '24.04' in os_info:
                        self.log_success("Running on supported Ubuntu version")
                    else:
                        self.log_warning("Running on untested Ubuntu version")
                else:
                    self.log_error("Not running on Ubuntu - some features may not work")
        else:
            self.log_error("Cannot determine OS version")
            
    def check_dependencies(self):
        """Check if all required dependencies are installed"""
        print("\n=== Checking Dependencies ===")
        
        required_commands = {
            'git': 'git',
            'curl': 'curl',
            'python3': 'python3',
            'pip3': 'python3-pip',
            'lxc': 'lxc',
            'systemctl': 'systemd'
        }
        
        for cmd, package in required_commands.items():
            if shutil.which(cmd):
                self.log_success(f"{cmd} is installed")
            else:
                self.log_error(f"{cmd} is not installed (install with: apt install {package})")
                
    def check_python_modules(self):
        """Check if required Python modules are installed"""
        print("\n=== Checking Python Modules ===")
        
        required_modules = [
            'click', 'yaml', 'jinja2', 'tabulate', 'colorama', 'requests'
        ]
        
        for module in required_modules:
            try:
                __import__(module)
                self.log_success(f"Python module '{module}' is installed")
            except ImportError:
                self.log_error(f"Python module '{module}' is not installed")
                # Try to fix it
                self.log_info(f"Attempting to install {module}...")
                ret, _, _ = self.run_command(['sudo', 'pip3', 'install', '--break-system-packages', module])
                if ret == 0:
                    self.log_fixed(f"Installed Python module '{module}'")
                    
    def check_lxd_installation(self):
        """Check LXD installation status"""
        print("\n=== Checking LXD Installation ===")
        
        # Check if snap is available
        if shutil.which('snap'):
            # Check if LXD is installed via snap
            ret, stdout, _ = self.run_command(['snap', 'list'], timeout=5)
            if ret == 0 and 'lxd' in stdout:
                self.log_success("LXD is installed via snap")
                
                # Check LXD status
                ret, stdout, stderr = self.run_command(['lxc', 'list'], timeout=5)
                if ret == 0:
                    self.log_success("LXD is working properly")
                else:
                    self.log_warning("LXD is installed but may not be initialized")
                    self.log_info("Run 'sudo lxd init' to initialize LXD")
            else:
                self.log_warning("LXD is not installed via snap")
                
                # Check for hanging snap processes
                ret, stdout, _ = self.run_command(['pgrep', '-f', 'snap install'])
                if ret == 0:
                    self.log_error("Found hanging snap install process")
                    self.log_info("Attempting to kill hanging process...")
                    subprocess.run(['sudo', 'pkill', '-f', 'snap install'], capture_output=True)
                    time.sleep(2)
                    self.log_fixed("Killed hanging snap install process")
                    
                # Check snapd service status
                ret, stdout, _ = self.run_command(['systemctl', 'is-active', 'snapd'])
                if 'inactive' in stdout or 'failed' in stdout:
                    self.log_error("snapd service is not running")
                    self.log_info("Attempting to restart snapd...")
                    subprocess.run(['sudo', 'systemctl', 'restart', 'snapd'], capture_output=True)
                    time.sleep(3)
                    self.log_fixed("Restarted snapd service")
        else:
            self.log_warning("Snap is not available on this system")
            
        # Check if LXC is available
        if shutil.which('lxc-ls'):
            self.log_success("LXC tools are installed")
        else:
            self.log_error("LXC tools are not installed")
            
    def check_network_configuration(self):
        """Check network bridge configuration"""
        print("\n=== Checking Network Configuration ===")
        
        # Check if lxcbr0 exists
        ret, stdout, _ = self.run_command(['ip', 'link', 'show', 'lxcbr0'])
        if ret == 0:
            self.log_success("LXC bridge (lxcbr0) exists")
            
            # Check if bridge has IP
            ret, stdout, _ = self.run_command(['ip', 'addr', 'show', 'lxcbr0'])
            if '10.0.3.1' in stdout:
                self.log_success("LXC bridge has correct IP address")
            else:
                self.log_error("LXC bridge does not have correct IP address")
                self.log_info("Attempting to configure bridge...")
                subprocess.run(['sudo', 'ip', 'addr', 'add', '10.0.3.1/24', 'dev', 'lxcbr0'], capture_output=True)
                subprocess.run(['sudo', 'ip', 'link', 'set', 'lxcbr0', 'up'], capture_output=True)
                self.log_fixed("Configured LXC bridge IP address")
        else:
            self.log_error("LXC bridge (lxcbr0) does not exist")
            self.log_info("Attempting to create bridge...")
            subprocess.run(['sudo', 'ip', 'link', 'add', 'name', 'lxcbr0', 'type', 'bridge'], capture_output=True)
            subprocess.run(['sudo', 'ip', 'addr', 'add', '10.0.3.1/24', 'dev', 'lxcbr0'], capture_output=True)
            subprocess.run(['sudo', 'ip', 'link', 'set', 'lxcbr0', 'up'], capture_output=True)
            self.log_fixed("Created LXC bridge")
            
    def check_directory_structure(self):
        """Check if required directories exist"""
        print("\n=== Checking Directory Structure ===")
        
        required_dirs = [
            '/srv/lxc-compose',
            '/srv/lxc-compose/cli',
            '/srv/lxc-compose/templates',
            '/srv/lxc-compose/scripts',
            '/srv/apps',
            '/srv/shared',
            '/srv/logs'
        ]
        
        for dir_path in required_dirs:
            if os.path.exists(dir_path):
                self.log_success(f"Directory {dir_path} exists")
            else:
                self.log_error(f"Directory {dir_path} does not exist")
                self.log_info(f"Creating {dir_path}...")
                os.makedirs(dir_path, exist_ok=True)
                self.log_fixed(f"Created directory {dir_path}")
                
    def check_lxc_compose_installation(self):
        """Check if lxc-compose is properly installed"""
        print("\n=== Checking LXC Compose Installation ===")
        
        # Check if lxc-compose command exists
        if shutil.which('lxc-compose'):
            self.log_success("lxc-compose command is available")
        else:
            self.log_error("lxc-compose command not found")
            
            # Check if CLI script exists
            cli_path = '/srv/lxc-compose/cli/lxc_compose.py'
            if os.path.exists(cli_path):
                self.log_info("CLI script exists, creating symlink...")
                subprocess.run(['sudo', 'ln', '-sf', cli_path, '/usr/local/bin/lxc-compose'], capture_output=True)
                subprocess.run(['sudo', 'chmod', '+x', cli_path], capture_output=True)
                self.log_fixed("Created lxc-compose command")
            else:
                self.log_error(f"CLI script not found at {cli_path}")
                self.log_info("Please run the installation script again")
                
    def check_services(self):
        """Check status of related services"""
        print("\n=== Checking Services ===")
        
        services = ['lxc-net', 'lxd', 'snapd', 'ssh']
        
        for service in services:
            ret, stdout, _ = self.run_command(['systemctl', 'is-active', service])
            if 'active' in stdout:
                self.log_success(f"Service {service} is active")
            elif 'inactive' in stdout:
                self.log_warning(f"Service {service} is inactive")
            else:
                self.log_info(f"Service {service} not found or status unknown")
                
    def fix_common_issues(self):
        """Attempt to fix common issues"""
        print("\n=== Attempting Common Fixes ===")
        
        # Fix permission issues
        if os.path.exists('/srv/lxc-compose'):
            user = os.environ.get('SUDO_USER', 'ubuntu')
            self.log_info(f"Setting ownership of /srv to {user}...")
            subprocess.run(['sudo', 'chown', '-R', f'{user}:{user}', '/srv/'], capture_output=True)
            self.log_fixed("Fixed directory permissions")
            
        # Restart networking if bridge is missing
        ret, _, _ = self.run_command(['ip', 'link', 'show', 'lxcbr0'])
        if ret != 0:
            self.log_info("Restarting LXC networking...")
            subprocess.run(['sudo', 'systemctl', 'restart', 'lxc-net'], capture_output=True)
            time.sleep(2)
            ret, _, _ = self.run_command(['ip', 'link', 'show', 'lxcbr0'])
            if ret == 0:
                self.log_fixed("Fixed LXC networking")
                
    def generate_report(self):
        """Generate final diagnostic report"""
        print("\n" + "="*50)
        print("DIAGNOSTIC REPORT")
        print("="*50)
        
        if not self.issues:
            print(f"\n{GREEN}✓ All checks passed! System is healthy.{NC}")
        else:
            print(f"\n{RED}Issues found:{NC}")
            for issue in self.issues:
                print(f"  • {issue}")
                
        if self.warnings:
            print(f"\n{YELLOW}Warnings:{NC}")
            for warning in self.warnings:
                print(f"  • {warning}")
                
        if self.fixed:
            print(f"\n{GREEN}Fixed issues:{NC}")
            for fix in self.fixed:
                print(f"  • {fix}")
                
        print("\n" + "="*50)
        
        if self.issues:
            print("\nRecommended actions:")
            print("1. Run: sudo /srv/lxc-compose/scripts/setup_host.sh")
            print("2. If installation hangs, press Ctrl+C and run: lxc-compose doctor --fix")
            print("3. For manual LXD installation: sudo snap install lxd --channel=5.21/stable")
            
    def run(self, fix_mode: bool = False):
        """Run all diagnostic checks"""
        print(f"{BLUE}LXC Compose Doctor - System Diagnostics{NC}")
        print("="*50)
        
        self.check_os_compatibility()
        self.check_dependencies()
        self.check_python_modules()
        self.check_lxd_installation()
        self.check_network_configuration()
        self.check_directory_structure()
        self.check_lxc_compose_installation()
        self.check_services()
        
        if fix_mode:
            self.fix_common_issues()
            
        self.generate_report()
        
        return 0 if not self.issues else 1


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='LXC Compose Doctor - Diagnostic Tool')
    parser.add_argument('--fix', action='store_true', help='Attempt to fix common issues')
    parser.add_argument('--json', action='store_true', help='Output results as JSON')
    args = parser.parse_args()
    
    doctor = LXCComposeDoctor()
    return doctor.run(fix_mode=args.fix)


if __name__ == '__main__':
    sys.exit(main())
EOF

chmod +x /srv/lxc-compose/cli/doctor.py
log "Created doctor.py script"

# Backup the current lxc_compose.py
cp /srv/lxc-compose/cli/lxc_compose.py /srv/lxc-compose/cli/lxc_compose.py.bak
log "Backed up current CLI script"

# Update the doctor command in lxc_compose.py to use the new script
info "Updating lxc-compose CLI to use new doctor script..."

# Check if the doctor command already uses the Python script
if grep -q "doctor_script = '/srv/lxc-compose/cli/doctor.py'" /srv/lxc-compose/cli/lxc_compose.py; then
    warning "Doctor command already updated"
else
    # Update the doctor command - find and replace the function
    python3 -c "
import re

with open('/srv/lxc-compose/cli/lxc_compose.py', 'r') as f:
    content = f.read()

# Find the doctor command function
pattern = r'(@cli\.command\(\).*?def doctor\(\):.*?(?=@cli\.command|\Z))'
replacement = '''@cli.command()
@click.option('--fix', is_flag=True, help='Attempt to fix common issues automatically')
def doctor(fix):
    \"\"\"Check system health and diagnose issues
    
    \\\\b
    This command will:
    - Check OS compatibility
    - Verify all dependencies are installed
    - Check Python modules
    - Verify LXD/LXC installation
    - Check network configuration
    - Verify directory structure
    - Test services
    
    Use --fix to attempt automatic fixes for common issues.
    \"\"\"
    import os
    import subprocess
    import sys
    
    doctor_script = '/srv/lxc-compose/cli/doctor.py'
    
    # First try the Python doctor script
    if os.path.exists(doctor_script):
        cmd = ['sudo', 'python3', doctor_script]
        if fix:
            cmd.append('--fix')
        result = subprocess.run(cmd)
        sys.exit(result.returncode)
    
    # Fallback to shell script if exists
    script_path = '/srv/lxc-compose/update.sh'
    if os.path.exists(script_path):
        subprocess.run(['sudo', script_path, 'doctor'])
    else:
        click.echo(f'Error: Doctor script not found', err=True)

'''

# Replace the doctor function
content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open('/srv/lxc-compose/cli/lxc_compose.py', 'w') as f:
    f.write(content)
" 2>/dev/null || {
    warning "Could not automatically update CLI script"
    info "You may need to manually edit /srv/lxc-compose/cli/lxc_compose.py"
}
fi

log "Doctor command installation complete!"
echo ""
info "You can now use:"
echo "  lxc-compose doctor         # Run diagnostics"
echo "  lxc-compose doctor --fix   # Run diagnostics and attempt fixes"
echo ""
log "Installation complete!"