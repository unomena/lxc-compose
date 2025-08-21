# Troubleshooting Guide

Common issues and solutions for LXC Compose.

## Installation Issues

### LXD Not Initialized

**Problem:** Error message about LXD not being initialized

**Solution:**
```bash
# The installer should handle this, but if needed:
sudo lxd init --minimal

# Or with default settings:
sudo lxd init --auto
```

### Permission Denied

**Problem:** Permission errors when running commands

**Solution:**
```bash
# Always use sudo for LXC Compose commands
sudo lxc-compose up

# For installation
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash
```

### Network Bridge Missing

**Problem:** Bridge network lxdbr0 not found

**Solution:**
```bash
# Create the bridge network
sudo lxc network create lxdbr0 ipv4.address=10.0.3.1/24 ipv4.nat=true

# Verify it exists
lxc network list
```

## Container Issues

### Container Won't Start

**Problem:** Container fails to start or shows as STOPPED

**Diagnosis:**
```bash
# Check container status
lxc list

# View container logs
lxc info container-name --show-log

# Check for errors
lxc console container-name
```

**Common Solutions:**

1. Check template availability:
```bash
# List available images
lxc image list ubuntu:
lxc image list ubuntu-minimal:
lxc image list alpine:
```

2. Verify storage pool:
```bash
lxc storage list
# If missing, create default pool
lxc storage create default dir
```

3. Check profile configuration:
```bash
lxc profile show default
```

### Container IP Not Assigned

**Problem:** Container doesn't get an IP address

**Solution:**
```bash
# Restart container
lxc restart container-name

# Check DHCP on bridge
sudo systemctl restart lxd

# Manually check network
lxc exec container-name -- ip addr show
```

### Mount Permission Denied

**Problem:** Can't access mounted directories

**Solution:**
```yaml
# In lxc-compose.yml, add permission fixes:
post_install:
  - name: "Fix mount permissions"
    command: |
      chown -R $(id -u):$(id -g) /app
      chmod -R 755 /app
```

## Networking Issues

### Port Not Accessible

**Problem:** Can't connect to exposed ports

**Diagnosis:**
```bash
# Check if port is exposed in config
grep exposed_ports lxc-compose.yml

# Verify iptables rules
sudo iptables -t nat -L PREROUTING -n | grep container-name

# Check if service is listening
lxc exec container-name -- netstat -tlnp | grep PORT
```

**Solutions:**

1. Ensure port is in exposed_ports:
```yaml
exposed_ports:
  - 80
  - 443
```

2. Verify iptables rule exists:
```bash
# Check DNAT rules
sudo iptables -t nat -L PREROUTING -n -v

# Manually add if missing (temporary)
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 \
  -j DNAT --to-destination CONTAINER_IP:80
```

3. Check if another service is using the port:
```bash
sudo lsof -i :PORT
sudo netstat -tlnp | grep PORT
```

### Containers Can't Communicate

**Problem:** Containers can't reach each other by name

**Solution:**
```bash
# Check shared hosts file
cat /srv/lxc-compose/etc/hosts

# Verify from inside container
lxc exec container1 -- cat /etc/hosts
lxc exec container1 -- ping container2

# Rebuild hosts file
sudo lxc-compose down
sudo lxc-compose up
```

### iptables Rules Not Created

**Problem:** Port forwarding rules missing

**Solution:**
```bash
# Check if UPF is installed
which upf

# Install UPF if missing
curl -fsSL https://raw.githubusercontent.com/unomena/upf/main/install.sh | sudo bash

# Recreate containers to trigger rule creation
lxc-compose destroy
lxc-compose up
```

## Service Issues

### Supervisor Not Starting Services

**Problem:** Services defined in YAML not running

**Diagnosis:**
```bash
# Check supervisor status
lxc exec container-name -- supervisorctl status

# View supervisor logs
lxc exec container-name -- tail -f /var/log/supervisord.log
```

**Solution:**
```bash
# Restart supervisor
lxc exec container-name -- supervisorctl reload

# Check service configuration
lxc exec container-name -- cat /etc/supervisor.d/*.ini
```

### Service Keeps Restarting

**Problem:** Service in restart loop

**Solution:**
1. Check service logs:
```bash
lxc-compose logs container-name service-name
```

2. Verify command path:
```yaml
services:
  myservice:
    command: /full/path/to/executable  # Use absolute paths
    directory: /app                     # Set working directory
```

3. Check dependencies:
```bash
# Ensure required services are running
lxc exec container-name -- ps aux | grep service
```

## Configuration Issues

### Environment Variables Not Loading

**Problem:** .env variables not available in container

**Solution:**
1. Verify .env file location (same directory as lxc-compose.yml)
2. Check syntax:
```env
# Correct
KEY=value
DB_HOST=localhost

# Wrong (no spaces around =)
KEY = value
```

3. Use variables in post_install:
```yaml
post_install:
  - name: "Use env var"
    command: |
      echo "Database: ${DB_HOST}"
```

### YAML Parse Errors

**Problem:** Invalid YAML configuration

**Common Issues:**
- Tabs instead of spaces (use spaces only)
- Incorrect indentation (use 2 spaces)
- Missing quotes around version numbers

**Validation:**
```bash
# Install yamllint
sudo apt install yamllint

# Check syntax
yamllint lxc-compose.yml
```

### Template Not Found

**Problem:** Error about ubuntu-minimal or alpine template

**Solution:**
```bash
# For ubuntu-minimal
lxc launch ubuntu-minimal:lts test-container

# For alpine
lxc launch alpine:3.19 test-container

# If not available, use alternatives:
# ubuntu-minimal → ubuntu
# alpine → ubuntu with minimal packages
```

## Performance Issues

### Slow Container Startup

**Problem:** Containers take long to start

**Solutions:**

1. Use Alpine for lightweight containers:
```yaml
template: alpine
release: "3.19"
```

2. Minimize packages:
```yaml
packages:
  - only-what-you-need
```

3. Cache package installations:
```bash
# Create custom image after setup
lxc publish container-name --alias myapp-base
```

### High Memory Usage

**Problem:** Containers using too much memory

**Solution:**
```bash
# Set memory limits
lxc config set container-name limits.memory 512MB

# Check current usage
lxc info container-name
```

## Common Error Messages

### "Container already exists"

**Solution:**
```bash
# Remove existing container
lxc delete container-name --force

# Or use destroy command
lxc-compose destroy
```

### "Address already in use"

**Solution:**
```bash
# Find process using port
sudo lsof -i :PORT
# Kill process if needed
sudo kill PID
```

### "No such file or directory"

**Solution:**
```bash
# Ensure mount source exists
mkdir -p ./data
# Verify paths in lxc-compose.yml
```

### "Connection refused"

**Solution:**
```bash
# Check if service is running
lxc exec container-name -- ps aux | grep service

# Verify port binding
lxc exec container-name -- netstat -tlnp
```

## Debugging Commands

### Essential Diagnostic Commands

```bash
# Container status
lxc list
lxc-compose list

# Container info
lxc info container-name

# Container processes
lxc exec container-name -- ps aux

# Network configuration
lxc exec container-name -- ip addr show
lxc exec container-name -- ip route

# Check mounts
lxc exec container-name -- mount | grep /app

# Service status
lxc exec container-name -- supervisorctl status

# View logs
lxc-compose logs container-name
lxc exec container-name -- journalctl -xe

# Interactive shell
lxc exec container-name -- /bin/bash
```

### Reset Everything

If all else fails, complete reset:

```bash
# Stop all containers
lxc-compose destroy --all

# Clean up iptables
sudo iptables -t nat -F
sudo iptables -F

# Remove installation
sudo rm -rf /srv/lxc-compose
sudo rm -f /usr/local/bin/lxc-compose

# Reinstall
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash
```

## Getting Help

If you're still stuck:

1. Check container logs: `lxc-compose logs container-name`
2. Run tests: `lxc-compose test`
3. Review configuration: `cat lxc-compose.yml`
4. Check [GitHub Issues](https://github.com/unomena/lxc-compose/issues)
5. Review [Documentation](index.md)

## Prevention Tips

1. **Always use sudo** for LXC Compose commands
2. **Start simple** - test with minimal configuration first
3. **Check logs early** - don't wait for multiple errors
4. **Use Alpine** for databases and services (smaller, faster)
5. **Test locally** before deploying to production
6. **Keep configurations versioned** in git
7. **Document custom settings** in comments