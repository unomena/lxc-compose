#!/usr/bin/env python3

import json
import subprocess
import os
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import click

class PortManager:
    """Manages port forwarding between host and LXC containers"""
    
    def __init__(self):
        self.config_file = Path("/srv/lxc-compose/port-forwards.json")
        self.ensure_config_exists()
        
    def ensure_config_exists(self):
        """Ensure the port forwards configuration file exists"""
        if not self.config_file.exists():
            self.config_file.parent.mkdir(parents=True, exist_ok=True)
            self.config_file.write_text(json.dumps({"forwards": []}, indent=2))
    
    def load_config(self) -> Dict:
        """Load port forwarding configuration"""
        try:
            return json.loads(self.config_file.read_text())
        except (json.JSONDecodeError, FileNotFoundError):
            return {"forwards": []}
    
    def save_config(self, config: Dict):
        """Save port forwarding configuration"""
        self.config_file.write_text(json.dumps(config, indent=2))
    
    def get_host_interface(self) -> Tuple[str, str]:
        """Get the main network interface and IP"""
        try:
            # Get default route interface
            result = subprocess.run(
                ["ip", "route", "show", "default"],
                capture_output=True, text=True, check=True
            )
            interface = result.stdout.split()[4] if result.stdout else "eth0"
            
            # Get IP of that interface
            result = subprocess.run(
                ["ip", "-4", "addr", "show", interface],
                capture_output=True, text=True, check=True
            )
            
            import re
            match = re.search(r'inet (\d+\.\d+\.\d+\.\d+)', result.stdout)
            ip = match.group(1) if match else "0.0.0.0"
            
            return interface, ip
        except Exception:
            return "eth0", "0.0.0.0"
    
    def add_forward(self, host_port: int, container_name: str, container_port: int, 
                   protocol: str = "tcp", description: str = "") -> bool:
        """Add a port forward rule"""
        # Get container IP
        container_ip = self.get_container_ip(container_name)
        if not container_ip:
            click.echo(f"Error: Container '{container_name}' not found or not running", err=True)
            return False
        
        # Check if host port is already in use
        config = self.load_config()
        for forward in config["forwards"]:
            if forward["host_port"] == host_port and forward["protocol"] == protocol:
                click.echo(f"Error: Host port {host_port}/{protocol} is already forwarded", err=True)
                return False
        
        # Add to configuration
        forward_rule = {
            "host_port": host_port,
            "container_name": container_name,
            "container_ip": container_ip,
            "container_port": container_port,
            "protocol": protocol,
            "description": description or f"{container_name}:{container_port}"
        }
        
        # Apply iptables rules
        if self.apply_iptables_rule(forward_rule, action="add"):
            config["forwards"].append(forward_rule)
            self.save_config(config)
            click.echo(f"✓ Added port forward: {host_port} -> {container_name}:{container_port} ({protocol})")
            return True
        
        return False
    
    def remove_forward(self, host_port: int, protocol: str = "tcp") -> bool:
        """Remove a port forward rule"""
        config = self.load_config()
        
        # Find the rule
        rule_to_remove = None
        for forward in config["forwards"]:
            if forward["host_port"] == host_port and forward["protocol"] == protocol:
                rule_to_remove = forward
                break
        
        if not rule_to_remove:
            click.echo(f"Error: No forward rule found for port {host_port}/{protocol}", err=True)
            return False
        
        # Remove iptables rules
        if self.apply_iptables_rule(rule_to_remove, action="remove"):
            config["forwards"] = [f for f in config["forwards"] 
                                 if not (f["host_port"] == host_port and f["protocol"] == protocol)]
            self.save_config(config)
            click.echo(f"✓ Removed port forward for {host_port}/{protocol}")
            return True
        
        return False
    
    def list_forwards(self) -> List[Dict]:
        """List all port forward rules"""
        config = self.load_config()
        
        # Update container IPs if they've changed
        updated = False
        for forward in config["forwards"]:
            current_ip = self.get_container_ip(forward["container_name"])
            if current_ip and current_ip != forward["container_ip"]:
                forward["container_ip"] = current_ip
                updated = True
        
        if updated:
            self.save_config(config)
        
        return config["forwards"]
    
    def get_container_ip(self, container_name: str) -> Optional[str]:
        """Get the IP address of an LXC container"""
        try:
            result = subprocess.run(
                ["lxc", "list", container_name, "--format=json"],
                capture_output=True, text=True, check=True
            )
            
            containers = json.loads(result.stdout)
            if not containers:
                return None
            
            container = containers[0]
            if container["status"] != "Running":
                return None
            
            # Get IP from state
            for iface, details in container.get("state", {}).get("network", {}).items():
                if iface == "lo":
                    continue
                for addr in details.get("addresses", []):
                    if addr["family"] == "inet" and addr["address"].startswith("10.0.3."):
                        return addr["address"]
            
            return None
        except Exception:
            return None
    
    def apply_iptables_rule(self, forward: Dict, action: str = "add") -> bool:
        """Apply or remove an iptables rule"""
        interface, host_ip = self.get_host_interface()
        
        try:
            if action == "add":
                # Add DNAT rule
                subprocess.run([
                    "sudo", "iptables", "-t", "nat", "-A", "PREROUTING",
                    "-i", interface, "-p", forward["protocol"],
                    "--dport", str(forward["host_port"]),
                    "-j", "DNAT", "--to-destination",
                    f"{forward['container_ip']}:{forward['container_port']}",
                    "-m", "comment", "--comment", f"lxc-compose: {forward['description']}"
                ], check=True)
                
                # Add FORWARD rule
                subprocess.run([
                    "sudo", "iptables", "-A", "FORWARD",
                    "-p", forward["protocol"], "-d", forward["container_ip"],
                    "--dport", str(forward["container_port"]),
                    "-m", "state", "--state", "NEW,ESTABLISHED,RELATED",
                    "-j", "ACCEPT",
                    "-m", "comment", "--comment", f"lxc-compose: {forward['description']}"
                ], check=True)
                
            elif action == "remove":
                # Remove DNAT rule
                subprocess.run([
                    "sudo", "iptables", "-t", "nat", "-D", "PREROUTING",
                    "-i", interface, "-p", forward["protocol"],
                    "--dport", str(forward["host_port"]),
                    "-j", "DNAT", "--to-destination",
                    f"{forward['container_ip']}:{forward['container_port']}"
                ], check=False)  # Don't fail if rule doesn't exist
                
                # Remove FORWARD rule
                subprocess.run([
                    "sudo", "iptables", "-D", "FORWARD",
                    "-p", forward["protocol"], "-d", forward["container_ip"],
                    "--dport", str(forward["container_port"]),
                    "-m", "state", "--state", "NEW,ESTABLISHED,RELATED",
                    "-j", "ACCEPT"
                ], check=False)  # Don't fail if rule doesn't exist
            
            return True
            
        except subprocess.CalledProcessError as e:
            click.echo(f"Error applying iptables rule: {e}", err=True)
            return False
    
    def apply_all_rules(self) -> bool:
        """Apply all configured port forwarding rules (used on system startup)"""
        config = self.load_config()
        interface, host_ip = self.get_host_interface()
        
        # Enable IP forwarding
        subprocess.run(["sudo", "sysctl", "-w", "net.ipv4.ip_forward=1"], check=False)
        
        # Setup masquerading
        subprocess.run([
            "sudo", "iptables", "-t", "nat", "-A", "POSTROUTING",
            "-o", interface, "-j", "MASQUERADE"
        ], check=False)
        
        # Apply all forward rules
        success_count = 0
        for forward in config["forwards"]:
            # Update container IP if needed
            current_ip = self.get_container_ip(forward["container_name"])
            if current_ip:
                forward["container_ip"] = current_ip
                if self.apply_iptables_rule(forward, action="add"):
                    success_count += 1
        
        # Save updated config
        self.save_config(config)
        
        return success_count == len(config["forwards"])
    
    def clear_all_rules(self) -> bool:
        """Remove all port forwarding rules"""
        config = self.load_config()
        
        for forward in config["forwards"]:
            self.apply_iptables_rule(forward, action="remove")
        
        config["forwards"] = []
        self.save_config(config)
        
        click.echo("✓ Cleared all port forwarding rules")
        return True
    
    def update_container_ip(self, container_name: str) -> bool:
        """Update the IP address for a container in all rules"""
        config = self.load_config()
        new_ip = self.get_container_ip(container_name)
        
        if not new_ip:
            click.echo(f"Error: Cannot get IP for container '{container_name}'", err=True)
            return False
        
        updated = False
        for forward in config["forwards"]:
            if forward["container_name"] == container_name:
                if forward["container_ip"] != new_ip:
                    # Remove old rule
                    self.apply_iptables_rule(forward, action="remove")
                    
                    # Update IP
                    forward["container_ip"] = new_ip
                    
                    # Add new rule
                    self.apply_iptables_rule(forward, action="add")
                    updated = True
        
        if updated:
            self.save_config(config)
            click.echo(f"✓ Updated IP for container '{container_name}' to {new_ip}")
        
        return updated
    
    def save_iptables_rules(self) -> bool:
        """Save iptables rules for persistence"""
        try:
            # Try netfilter-persistent first
            result = subprocess.run(
                ["sudo", "which", "netfilter-persistent"],
                capture_output=True
            )
            if result.returncode == 0:
                subprocess.run(["sudo", "netfilter-persistent", "save"], check=True)
                return True
            
            # Try iptables-save
            rules_dir = Path("/etc/iptables")
            if rules_dir.exists():
                subprocess.run(
                    ["sudo", "bash", "-c", "iptables-save > /etc/iptables/rules.v4"],
                    check=True
                )
                return True
            
            return False
        except Exception:
            return False


def format_port_table(forwards: List[Dict]) -> str:
    """Format port forwards as a nice table"""
    if not forwards:
        return "No port forwards configured"
    
    # Calculate column widths
    headers = ["Host Port", "Container", "Container IP", "Container Port", "Protocol", "Description"]
    widths = [len(h) for h in headers]
    
    for f in forwards:
        widths[0] = max(widths[0], len(str(f["host_port"])))
        widths[1] = max(widths[1], len(f["container_name"]))
        widths[2] = max(widths[2], len(f["container_ip"]))
        widths[3] = max(widths[3], len(str(f["container_port"])))
        widths[4] = max(widths[4], len(f["protocol"]))
        widths[5] = max(widths[5], len(f["description"]))
    
    # Build table
    lines = []
    
    # Header
    header_line = "  ".join(h.ljust(w) for h, w in zip(headers, widths))
    lines.append(header_line)
    lines.append("-" * len(header_line))
    
    # Rows
    for f in forwards:
        row = [
            str(f["host_port"]).ljust(widths[0]),
            f["container_name"].ljust(widths[1]),
            f["container_ip"].ljust(widths[2]),
            str(f["container_port"]).ljust(widths[3]),
            f["protocol"].ljust(widths[4]),
            f["description"].ljust(widths[5])
        ]
        lines.append("  ".join(row))
    
    return "\n".join(lines)


if __name__ == "__main__":
    # Test the module
    manager = PortManager()
    forwards = manager.list_forwards()
    print(format_port_table(forwards))