# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LXC Compose is a Docker Compose-like orchestration tool for Linux Containers (LXC). It provides YAML-based container management supporting both dictionary-based (recommended) and list-based container definitions. The dictionary format is compatible with the reference project at https://github.com/euan/sample-lxc-compose-app.

## Key Commands

### Testing Without Installation
```bash
# Test CLI directly from source
python3 /srv/lxc-compose/cli/lxc_compose.py list
python3 /srv/lxc-compose/cli/lxc_compose.py up --file test-config.yml

# If developing locally
python3 srv/lxc-compose/cli/lxc_compose.py list
python3 srv/lxc-compose/cli/lxc_compose.py up

# Check Python syntax
python3 -m py_compile srv/lxc-compose/cli/*.py
```

### Installation and Deployment
```bash
# Local installation
sudo ./install.sh

# Quick install via curl
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash

# Install with samples
sudo ./install.sh --with-samples
```

### Container Operations
```bash
# Config-scoped operations (default: lxc-compose.yml)
lxc-compose up              # Create and start containers
lxc-compose down            # Stop containers
lxc-compose list            # List with status, IPs, and ports
lxc-compose destroy         # Stop and remove containers

# Custom config file
lxc-compose up -f custom-config.yml

# System-wide operations (requires confirmation)
lxc-compose up --all        # Start ALL containers on system
lxc-compose destroy --all   # Destroy ALL containers (DANGEROUS!)
```

## Architecture

### Core Implementation (`srv/lxc-compose/cli/lxc_compose.py`)

The main CLI uses a `LXCCompose` class with critical methods:

1. **Configuration Parsing**:
   - `parse_containers()`: Handles both dictionary and list formats
   - Dictionary format: `containers: {name: {...}}` (recommended)
   - List format: `containers: [{name: foo}, ...]` (legacy)

2. **Container Lifecycle**:
   - `create_container()`: Creates with image or template+release
   - `wait_for_network()`: Ensures container has IP before proceeding
   - `handle_dependencies()`: Manages `depends_on` startup order

3. **Mount Management**:
   - `setup_mounts()`: Supports two formats:
     - Simple: `"./path:/container/path"`
     - Explicit: `{source: ./path, target: /container/path}`
   - Converts relative paths to absolute based on config file location
   - Creates source directories if they don't exist

4. **Port Forwarding**:
   - `setup_port_forwarding()`: Creates iptables NAT rules
   - PREROUTING chain: External access (interface-based)
   - OUTPUT chain: Localhost access
   - POSTROUTING chain: MASQUERADE for proper SNAT
   - `cleanup_port_forwarding()`: Removes rules on container stop

5. **Service Management**:
   - `setup_services()`: Creates service definitions
   - System services: Uses systemd (`type: system`)
   - Supervisor services: Uses supervisord (default)

6. **Post-Installation**:
   - `run_post_install()`: Executes one-time setup commands
   - Multi-line commands are properly joined
   - Commands run in sequence with error checking

### Data Storage

- **Non-root users**: `~/.local/share/lxc-compose/` (XDG Base Directory)
- **Root users**: `/etc/lxc-compose/`
- **Stored files**:
  - `port-forwards.json`: Active port forwarding rules per container
  - `registry.json`: Container registry (optional feature)

### Network Architecture

- **Bridge**: lxcbr0 (10.0.3.0/24 by default)
- **IP forwarding**: Enabled via sysctl
- **Port forwarding flow**:
  ```
  External -> PREROUTING (DNAT) -> Container
  Localhost -> OUTPUT (DNAT) -> Container
  Container -> POSTROUTING (MASQUERADE) -> External
  ```

## Configuration Format Details

### Dictionary Format (Recommended)
```yaml
version: '1.0'
containers:
  container-name:             # Name as dictionary key
    template: ubuntu          # or alpine, debian
    release: jammy            # or 3.19 for alpine
    depends_on: [other]       # Startup dependencies
    mounts:                   # Both formats supported
      - .:/app
      - source: ./data
        target: /var/lib/data
    ports: ["8080:80"]
    packages: [nginx, python3]
    environment:              # All values must be strings
      KEY: "value"
    post_install:             # One-time setup
      - name: "Setup"
        command: |
          multi-line
          commands
    services:                 # Service definitions
      service-name:
        command: /path/to/cmd
        type: system          # Optional, defaults to supervisor
        directory: /app
        autostart: true
        autorestart: true
        environment:
          KEY: "value"
```

### List Format (Legacy)
```yaml
containers:
  - name: container-name      # Name as property
    image: ubuntu:22.04       # Full image specification
    ports: ["8080:80"]
    mounts: ["./app:/var/www"]
    services:
      - name: service-name
        command: command
```

## Sample Projects

All samples in `sample-configs/` follow the reference project pattern:
- **django-minimal/**: Single Alpine container with Django + PostgreSQL (~150MB)
- **flask-app/**: Flask with Redis cache and Nginx proxy
- **nodejs-app/**: Express.js with MongoDB

Key principles:
- Source files exist in directory (not generated)
- Entire directory mounted as `.:/app`
- Dependencies installed in `post_install`
- No hardcoded secrets in code

## Testing Changes

```bash
# Test with reference project
cd /home/ubuntu/Workspace/sample-lxc-compose-app
python3 /home/ubuntu/Workspace/lxc-compose/srv/lxc-compose/cli/lxc_compose.py up

# Test with sample configs
cd sample-configs/django-minimal
python3 ../../srv/lxc-compose/cli/lxc_compose.py up

# Verify port forwarding
sudo iptables -t nat -L PREROUTING -n -v | grep DNAT

# Check container networking
lxc list
lxc exec container-name -- ip addr
```

## Common Issues and Solutions

### Image Download Failures
- Installer uses correct format: `lxc image copy ubuntu-minimal:22.04 local:`
- Alpine version: 3.19 (not 3.18)
- Images downloaded to local: alias for offline use

### Mount Path Issues
- Relative paths converted to absolute from config file directory
- Source directories auto-created if missing
- LXC requires absolute paths internally

### Service Not Starting
- Supervisor services: Check supervisord is installed
- System services: Verify systemd is available
- Multi-line commands: Automatically joined with `&&`

### Container Dependency Timeout
- Default wait: 60 seconds for dependencies
- Check dependency container has started: `lxc list`
- Circular dependencies logged but allowed

### Port Forwarding Not Working
- Check iptables rules: `sudo iptables -t nat -L -n`
- Verify IP forwarding: `sysctl net.ipv4.ip_forward`
- Ensure container has IP: `lxc-compose list`

## Critical Implementation Notes

1. **Container Name Uniqueness**: Names must be globally unique across the system
2. **Port Forwarding Persistence**: Rules stored in JSON and restored on restart
3. **Mount Creation**: Parent directories created recursively if needed
4. **Service Types**: System services require `type: system`, otherwise supervisor
5. **Environment Variables**: All values must be strings in YAML
6. **Post-Install**: Runs only on container creation, not on restart

## Dependencies

**Python packages**:
- click: CLI framework
- pyyaml: YAML parsing

**System requirements**:
- LXD/LXC: Container runtime
- iptables: Port forwarding
- Python 3.8+: Runtime
- Ubuntu 22.04/24.04: Supported OS