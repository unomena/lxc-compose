# Troubleshooting Guide

Common issues and solutions for LXC Compose.

## Table of Contents
- [Installation Issues](#installation-issues)
- [Container Issues](#container-issues)
- [Networking Issues](#networking-issues)
- [Configuration Issues](#configuration-issues)
- [Performance Issues](#performance-issues)
- [Common Errors](#common-errors)
- [Debugging Tools](#debugging-tools)

## Installation Issues

### LXC/LXD Not Found

**Problem:** Installation fails with "LXC not found" or "LXD not found"

**Solution:**
```bash
# For Ubuntu
sudo apt update
sudo apt install -y lxc lxc-utils

# For Debian
sudo apt update
sudo apt install -y lxc

# Verify installation
lxc-ls --version
```

### Permission Denied

**Problem:** Installation fails with permission errors

**Solution:**
```bash
# Ensure you're using sudo
sudo ./install.sh

# Or with curl
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash
```

### Network Bridge Missing

**Problem:** Bridge network lxcbr0 not found

**Solution:**
```bash
# Create bridge manually
sudo systemctl stop lxc-net
sudo systemctl start lxc-net

# Verify bridge
ip addr show lxcbr0

# If still missing, reinstall lxc
sudo apt remove --purge lxc lxc-utils
sudo apt install lxc lxc-utils
```

## Container Issues

### Container Name Conflicts

**Problem:** Error: Container name conflict detected!

**Solution:**
```bash
# List existing containers
lxc-compose list
sudo lxc-ls

# Check /etc/hosts for conflicts
grep "container-name" /etc/hosts

# Use namespaced names
# Instead of: db, web, cache
# Use: myproject-db, myproject-web, myproject-cache
```

### Container Won't Start

**Problem:** Container created but won't start

**Solution:**
```bash
# Check container status
sudo lxc-info -n container-name

# View container logs
sudo lxc-console -n container-name

# Check configuration
sudo cat /var/lib/lxc/container-name/config

# Try starting manually
sudo lxc-start -n container-name -F  # Foreground for debugging

# Check for mount issues
sudo lxc-start -n container-name -l DEBUG -o /tmp/lxc.log
cat /tmp/lxc.log
```

### Container Has No Network

**Problem:** Container starts but has no network connectivity

**Solution:**
```bash
# Check container IP
sudo lxc-info -n container-name -iH

# Verify bridge
sudo brctl show lxcbr0

# Check /etc/hosts
cat /etc/hosts | grep "LXC Compose"

# Restart container
lxc-compose restart container-name

# Manual IP assignment
sudo lxc-attach -n container-name -- ip addr add 10.0.3.100/24 dev eth0
sudo lxc-attach -n container-name -- ip route add default via 10.0.3.1
```

### Mount Points Not Working

**Problem:** Host directories not visible in container

**Solution:**
```bash
# Verify mount in config
sudo grep mount /var/lib/lxc/container-name/config

# Check host path exists
ls -la /path/on/host

# Create missing directories
mkdir -p /path/on/host

# Fix permissions
sudo chown -R 100000:100000 /path/on/host  # For unprivileged containers

# Restart container
sudo lxc-stop -n container-name
sudo lxc-start -n container-name
```

## Networking Issues

### Port Forwarding Not Working

**Problem:** Can't access services on forwarded ports

**Solution:**
```bash
# Check if port is listening
sudo lxc-attach -n container-name -- netstat -tlpn

# Verify iptables rules
sudo iptables -t nat -L PREROUTING -n --line-numbers

# Add port forward manually
sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 \
  -j DNAT --to-destination 10.0.3.11:80

# Make persistent
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

### Container Can't Reach Internet

**Problem:** Container can't access external networks

**Solution:**
```bash
# Check NAT/masquerade
sudo iptables -t nat -L POSTROUTING

# Enable IP forwarding
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Add masquerade rule
sudo iptables -t nat -A POSTROUTING -s 10.0.3.0/24 -j MASQUERADE

# Check DNS
sudo lxc-attach -n container-name -- cat /etc/resolv.conf
sudo lxc-attach -n container-name -- ping 8.8.8.8
sudo lxc-attach -n container-name -- nslookup google.com
```

### Containers Can't Communicate

**Problem:** Containers can't reach each other

**Solution:**
```bash
# Check /etc/hosts entries
cat /etc/hosts | grep "LXC Compose"

# Verify both containers are running
lxc-compose ps

# Test connectivity
sudo lxc-attach -n container1 -- ping container2

# Check firewall rules
sudo iptables -L FORWARD

# Allow container communication
sudo iptables -A FORWARD -s 10.0.3.0/24 -d 10.0.3.0/24 -j ACCEPT
```

## Configuration Issues

### YAML Parse Errors

**Problem:** Error reading config: yaml parse error

**Solution:**
```yaml
# Check YAML syntax
# Use proper indentation (2 spaces)
containers:
  myapp-web:    # 2 spaces
    ports:      # 4 spaces
      - 8080:80 # 6 spaces

# Validate YAML online
# https://www.yamllint.com/

# Common issues:
# - Tabs instead of spaces
# - Missing colons
# - Wrong indentation
# - Special characters not quoted
```

### Environment Variables Not Set

**Problem:** Environment variables not available in container

**Solution:**
```yaml
# Correct format in lxc-compose.yml
containers:
  myapp-web:
    environment:
      KEY: "value"        # String format
      PORT: "3000"        # Numbers as strings
      DEBUG: "true"       # Booleans as strings

# Verify in container
sudo lxc-attach -n myapp-web -- env | grep KEY
```

### Services Not Starting

**Problem:** Services defined but not running

**Solution:**
```bash
# Check supervisor status
sudo lxc-attach -n container-name -- supervisorctl status

# View service logs
sudo lxc-attach -n container-name -- supervisorctl tail service-name

# Restart service
sudo lxc-attach -n container-name -- supervisorctl restart service-name

# Check service configuration
sudo lxc-attach -n container-name -- cat /etc/supervisor/conf.d/services.conf

# Manual start for debugging
sudo lxc-attach -n container-name -- /path/to/command
```

## Performance Issues

### Slow Container Startup

**Problem:** Containers take long time to start

**Solution:**
```bash
# Check system resources
free -h
df -h

# Reduce package installation
# Only install essential packages

# Use template caching
sudo lxc-create -t download -n template-cache -- \
  --dist ubuntu --release jammy --arch amd64

# Clone from template
sudo lxc-copy -n template-cache -N new-container
```

### High Memory Usage

**Problem:** Containers using too much memory

**Solution:**
```bash
# Check memory usage
sudo lxc-info -n container-name

# Set memory limits
echo "lxc.cgroup2.memory.max = 512M" | \
  sudo tee -a /var/lib/lxc/container-name/config

# Restart container
sudo lxc-stop -n container-name
sudo lxc-start -n container-name
```

## Common Errors

### "Container already exists"

```bash
# Solution 1: Use existing container
lxc-compose start container-name

# Solution 2: Remove and recreate
sudo lxc-stop -n container-name
sudo lxc-destroy -n container-name
lxc-compose up

# Solution 3: Force recreate
lxc-compose up --force-recreate
```

### "No such file or directory"

```bash
# Check if path exists
ls -la /path/to/file

# Create missing directories
mkdir -p /srv/apps/myapp

# Use absolute paths in config
mounts:
  - /absolute/path:/container/path  # Good
  - ./relative:/path                 # May cause issues
```

### "Address already in use"

```bash
# Find process using port
sudo lsof -i :8080
sudo netstat -tlpn | grep 8080

# Kill process
sudo kill -9 <PID>

# Or use different port
ports:
  - 8081:80  # Use 8081 instead of 8080
```

## Debugging Tools

### LXC Compose Doctor

```bash
# Run diagnostics
lxc-compose doctor

# Auto-fix common issues
lxc-compose doctor --fix

# Check specific component
lxc-compose doctor --check networking
lxc-compose doctor --check containers
lxc-compose doctor --check config
```

### Container Logs

```bash
# View all logs
lxc-compose logs

# Follow logs
lxc-compose logs -f

# Specific container
lxc-compose logs container-name

# System logs
sudo journalctl -u lxc
sudo journalctl -xe | grep lxc
```

### Interactive Debugging

```bash
# Enter container shell
lxc-compose exec container-name bash

# Run commands
lxc-compose exec container-name ps aux
lxc-compose exec container-name netstat -tlpn
lxc-compose exec container-name systemctl status

# Attach to container console
sudo lxc-console -n container-name
# Press Ctrl+A, Q to exit
```

### Network Debugging

```bash
# Check routing
ip route
sudo lxc-attach -n container-name -- ip route

# Check DNS
nslookup container-name
dig container-name

# Trace network path
sudo lxc-attach -n container-name -- traceroute google.com

# Monitor traffic
sudo tcpdump -i lxcbr0 -n
```

### Configuration Validation

```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('lxc-compose.yml'))"

# Check container config
sudo lxc-config -l
sudo lxc-checkconfig

# Verify installation
lxc-compose --version
which lxc-compose
ls -la /srv/lxc-compose/
```

## Getting Help

### Collect Debug Information

When reporting issues, include:

```bash
# System information
lsb_release -a
uname -a

# LXC version
lxc-ls --version

# Container list
sudo lxc-ls -f

# Configuration
cat lxc-compose.yml

# Error logs
lxc-compose logs > error.log 2>&1

# Network configuration
ip addr
ip route
sudo iptables -L -n
```

### Resources

- **GitHub Issues**: [Report bugs](https://github.com/unomena/lxc-compose/issues)
- **Documentation**: [Read the docs](https://github.com/unomena/lxc-compose/tree/main/docs)
- **Examples**: [Sample configurations](https://github.com/unomena/lxc-compose/tree/main/examples)

### Quick Fixes Script

Create a quick-fix script for common issues:

```bash
#!/bin/bash
# save as fix-common.sh

echo "Running LXC Compose Quick Fixes..."

# Fix permissions
sudo chown -R $USER:$USER ~/.config/lxc/

# Restart networking
sudo systemctl restart lxc-net

# Clear IP allocations (careful!)
sudo cp /srv/lxc-compose/ip-allocations.json /srv/lxc-compose/ip-allocations.backup
echo '{"subnet":"10.0.3.0/24","next_ip":11,"allocations":{},"reserved":[1,2,3,4,5,6,7,8,9,10]}' | \
  sudo tee /srv/lxc-compose/ip-allocations.json

# Fix /etc/hosts
sudo sed -i '/# BEGIN LXC Compose/,/# END LXC Compose/d' /etc/hosts

# Run doctor
lxc-compose doctor --fix

echo "Quick fixes applied. Try running your command again."
```