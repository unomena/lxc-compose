#!/usr/bin/env python3

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import fcntl
import click

class IPAllocator:
    """Manages IP address allocation for containers"""
    
    def __init__(self, subnet="10.0.3.0/24", start_from=11):
        self.subnet_base = ".".join(subnet.split("/")[0].split(".")[:-1])  # "10.0.3"
        self.start_from = start_from
        self.allocations_file = Path("/srv/lxc-compose/ip-allocations.json")
        self.ensure_allocations_file()
    
    def ensure_allocations_file(self):
        """Ensure the IP allocations file exists"""
        if not self.allocations_file.exists():
            try:
                self.allocations_file.parent.mkdir(parents=True, exist_ok=True)
                self.allocations_file.write_text(json.dumps({
                    "subnet": f"{self.subnet_base}.0/24",
                    "next_ip": self.start_from,
                    "allocations": {},
                    "reserved": list(range(1, self.start_from))  # Reserve .1 to .10
                }, indent=2))
            except PermissionError:
                # Use sudo to create the directory and file
                subprocess.run(['sudo', 'mkdir', '-p', str(self.allocations_file.parent)])
                content = json.dumps({
                    "subnet": f"{self.subnet_base}.0/24",
                    "next_ip": self.start_from,
                    "allocations": {},
                    "reserved": list(range(1, self.start_from))
                }, indent=2)
                with tempfile.NamedTemporaryFile(mode='w', delete=False) as tmp:
                    tmp.write(content)
                    tmp_path = tmp.name
                subprocess.run(['sudo', 'cp', tmp_path, str(self.allocations_file)])
                subprocess.run(['sudo', 'chmod', '666', str(self.allocations_file)])
                os.unlink(tmp_path)
    
    def load_allocations(self) -> Dict:
        """Load IP allocations from file"""
        try:
            return json.loads(self.allocations_file.read_text())
        except (json.JSONDecodeError, FileNotFoundError):
            self.ensure_allocations_file()
            return json.loads(self.allocations_file.read_text())
    
    def save_allocations(self, data: Dict):
        """Save IP allocations to file"""
        try:
            self.allocations_file.write_text(json.dumps(data, indent=2))
        except PermissionError:
            # Use sudo to write
            content = json.dumps(data, indent=2)
            with tempfile.NamedTemporaryFile(mode='w', delete=False) as tmp:
                tmp.write(content)
                tmp_path = tmp.name
            subprocess.run(['sudo', 'cp', tmp_path, str(self.allocations_file)])
            subprocess.run(['sudo', 'chmod', '666', str(self.allocations_file)])
            os.unlink(tmp_path)
    
    def allocate_ip(self, container_name: str) -> str:
        """Allocate an IP address for a container"""
        data = self.load_allocations()
        
        # Check if container already has an allocation
        if container_name in data["allocations"]:
            return f"{self.subnet_base}.{data['allocations'][container_name]}"
        
        # Find next available IP
        next_ip = data.get("next_ip", self.start_from)
        while next_ip in data.get("reserved", []) or next_ip in data["allocations"].values():
            next_ip += 1
            if next_ip > 254:
                raise ValueError("No more IP addresses available in subnet")
        
        # Allocate the IP
        data["allocations"][container_name] = next_ip
        data["next_ip"] = next_ip + 1
        self.save_allocations(data)
        
        return f"{self.subnet_base}.{next_ip}"
    
    def release_ip(self, container_name: str) -> bool:
        """Release an IP allocation for a container"""
        data = self.load_allocations()
        
        if container_name in data["allocations"]:
            del data["allocations"][container_name]
            self.save_allocations(data)
            return True
        return False
    
    def get_ip(self, container_name: str) -> Optional[str]:
        """Get the allocated IP for a container"""
        data = self.load_allocations()
        if container_name in data["allocations"]:
            return f"{self.subnet_base}.{data['allocations'][container_name]}"
        return None


class HostsManager:
    """Manages /etc/hosts entries for LXC containers"""
    
    def __init__(self):
        self.hosts_file = Path("/etc/hosts")
        self.backup_file = Path("/etc/hosts.lxc-backup")
        self.marker_start = "# BEGIN LXC Compose managed section - DO NOT EDIT"
        self.marker_end = "# END LXC Compose managed section"
        self.ip_allocator = IPAllocator()
        
        # Create backup if it doesn't exist
        if not self.backup_file.exists() and self.hosts_file.exists():
            try:
                self.backup_file.write_text(self.hosts_file.read_text())
            except PermissionError:
                # Try with sudo
                try:
                    result = subprocess.run(
                        ['sudo', 'cp', str(self.hosts_file), str(self.backup_file)],
                        capture_output=True, text=True
                    )
                    if result.returncode != 0:
                        # Silently skip if backup fails - not critical
                        pass
                except:
                    # If sudo fails, just continue without backup
                    pass
    
    def _lock_file(self, file_handle):
        """Lock file for exclusive access"""
        fcntl.flock(file_handle.fileno(), fcntl.LOCK_EX)
    
    def _unlock_file(self, file_handle):
        """Unlock file"""
        fcntl.flock(file_handle.fileno(), fcntl.LOCK_UN)
    
    def read_hosts(self) -> Tuple[List[str], List[str], List[str]]:
        """Read hosts file and split into before, managed, and after sections"""
        with open(self.hosts_file, 'r') as f:
            self._lock_file(f)
            content = f.read()
            self._unlock_file(f)
        
        lines = content.split('\n')
        before = []
        managed = []
        after = []
        
        in_managed = False
        after_managed = False
        
        for line in lines:
            if line.strip() == self.marker_start:
                in_managed = True
                continue
            elif line.strip() == self.marker_end:
                in_managed = False
                after_managed = True
                continue
            
            if not in_managed and not after_managed:
                before.append(line)
            elif in_managed:
                managed.append(line)
            else:
                after.append(line)
        
        return before, managed, after
    
    def write_hosts(self, before: List[str], managed: List[str], after: List[str]):
        """Write hosts file with before, managed, and after sections"""
        content = []
        
        # Add before section
        content.extend(before)
        
        # Remove trailing empty lines from before section
        while content and content[-1].strip() == '':
            content.pop()
        
        # Add managed section with markers
        if managed:
            content.append('')  # Empty line before marker
            content.append(self.marker_start)
            content.extend(managed)
            content.append(self.marker_end)
        
        # Add after section
        if after and any(line.strip() for line in after):
            content.append('')  # Empty line after managed section
            content.extend(after)
        
        # Ensure file ends with newline
        if content and content[-1] != '':
            content.append('')
        
        # Write to /etc/hosts using sudo if needed
        content_str = '\n'.join(content)
        
        # Try direct write first
        try:
            with open(self.hosts_file, 'w') as f:
                self._lock_file(f)
                f.write(content_str)
                self._unlock_file(f)
        except PermissionError:
            # Use sudo to write if permission denied
            with tempfile.NamedTemporaryFile(mode='w', delete=False) as tmp:
                tmp.write(content_str)
                tmp_path = tmp.name
            
            # Use sudo to copy the temp file to /etc/hosts
            result = subprocess.run(['sudo', 'cp', tmp_path, str(self.hosts_file)], 
                                  capture_output=True, text=True)
            os.unlink(tmp_path)
            
            if result.returncode != 0:
                raise PermissionError(f"Failed to write /etc/hosts: {result.stderr}")
    
    def add_container(self, container_name: str, ip: Optional[str] = None) -> str:
        """Add or update a container entry in /etc/hosts
        
        NO ALIASES ALLOWED - only exact container names for clarity
        """
        # Check for container name conflicts first
        if self.check_name_conflict(container_name):
            click.echo(f"\n✗ ERROR: Container name conflict detected!", err=True)
            click.echo(f"  The name '{container_name}' is already in use on this system.", err=True)
            click.echo(f"\n  This is a problem because container names must be globally unique.", err=True)
            click.echo(f"  Each container name maps to exactly one IP address in /etc/hosts.", err=True)
            click.echo(f"\n  Solution: Use project namespaces to ensure unique names:", err=True)
            click.echo(f"    - {container_name.split('-')[0]}-db", err=True)
            click.echo(f"    - {container_name.split('-')[0]}-cache", err=True)
            click.echo(f"    - {container_name.split('-')[0]}-web", err=True)
            click.echo(f"  Or use reverse domain notation:", err=True)
            click.echo(f"    - com-example-db", err=True)
            click.echo(f"    - org-myproject-app", err=True)
            raise click.ClickException(f"Container name '{container_name}' already exists")
        
        # Allocate IP if not provided
        if not ip:
            ip = self.ip_allocator.allocate_ip(container_name)
        
        # Read current hosts file
        before, managed, after = self.read_hosts()
        
        # Create new entry - NO ALIASES
        entry = f"{ip}\t{container_name}"
        
        # Remove existing entry for this container if it exists
        managed = [line for line in managed 
                  if not (line.strip() and container_name in line.split())]
        
        # Add new entry
        managed.append(entry)
        
        # Sort managed entries by IP for readability
        managed.sort(key=lambda x: [int(i) for i in x.split()[0].split('.')] if x.strip() else [999,999,999,999])
        
        # Write back
        self.write_hosts(before, managed, after)
        
        click.echo(f"✓ Added hosts entry: {entry}")
        return ip
    
    def check_name_conflict(self, container_name: str) -> bool:
        """Check if a container name already exists in /etc/hosts or as an LXC container"""
        # Check /etc/hosts
        entries = self.list_entries()
        for entry in entries:
            if entry['container'] == container_name:
                return True
        
        # Check existing LXC containers
        result = subprocess.run(['sudo', 'lxc-ls'], capture_output=True, text=True)
        if result.returncode == 0:
            existing_containers = result.stdout.strip().split()
            if container_name in existing_containers:
                return True
        
        return False
    
    def remove_container(self, container_name: str) -> bool:
        """Remove a container entry from /etc/hosts"""
        # Read current hosts file
        before, managed, after = self.read_hosts()
        
        # Filter out lines containing this container
        original_count = len(managed)
        managed = [line for line in managed 
                  if not (line.strip() and container_name in line.split())]
        
        if len(managed) < original_count:
            # Write back
            self.write_hosts(before, managed, after)
            
            # Release IP allocation
            self.ip_allocator.release_ip(container_name)
            
            click.echo(f"✓ Removed hosts entry for: {container_name}")
            return True
        
        return False
    
    def update_container(self, container_name: str, new_ip: str = None) -> bool:
        """Update a container's hosts entry"""
        # Simply re-add with new info (it will replace existing)
        ip = new_ip or self.ip_allocator.get_ip(container_name)
        if ip:
            # Temporarily allow updates by removing conflict check for existing name
            # Read current hosts file
            before, managed, after = self.read_hosts()
            
            # Create new entry - NO ALIASES
            entry = f"{ip}\t{container_name}"
            
            # Remove existing entry for this container if it exists
            managed = [line for line in managed 
                      if not (line.strip() and container_name in line.split())]
            
            # Add new entry
            managed.append(entry)
            
            # Sort managed entries by IP for readability
            managed.sort(key=lambda x: [int(i) for i in x.split()[0].split('.')] if x.strip() else [999,999,999,999])
            
            # Write back
            self.write_hosts(before, managed, after)
            
            click.echo(f"✓ Updated hosts entry: {entry}")
            return True
        return False
    
    def list_entries(self) -> List[Dict[str, any]]:
        """List all managed container entries"""
        _, managed, _ = self.read_hosts()
        entries = []
        
        for line in managed:
            if line.strip() and not line.startswith('#'):
                parts = line.split()
                if len(parts) >= 2:
                    entries.append({
                        'ip': parts[0],
                        'container': parts[1]
                    })
        
        return entries
    
    def get_container_ip(self, container_name: str) -> Optional[str]:
        """Get IP address for a container from hosts file"""
        entries = self.list_entries()
        for entry in entries:
            if entry['container'] == container_name:
                return entry['ip']
        return None
    
    def cleanup_orphaned_entries(self) -> int:
        """Remove entries for containers that no longer exist"""
        # Get list of running containers
        result = subprocess.run(['sudo', 'lxc-ls'], capture_output=True, text=True)
        if result.returncode != 0:
            return 0
        
        existing_containers = set(result.stdout.strip().split())
        entries = self.list_entries()
        removed = 0
        
        for entry in entries:
            if entry['container'] not in existing_containers:
                if self.remove_container(entry['container']):
                    removed += 1
        
        return removed
    
    def restore_backup(self):
        """Restore the original hosts file from backup"""
        if self.backup_file.exists():
            self.hosts_file.write_text(self.backup_file.read_text())
            click.echo("✓ Restored /etc/hosts from backup")
        else:
            click.echo("✗ No backup file found", err=True)


if __name__ == "__main__":
    # Test the module
    manager = HostsManager()
    
    # Example operations
    print("Current managed entries:")
    for entry in manager.list_entries():
        print(f"  {entry['ip']} -> {entry['container']}")