# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LXC Compose is a lightweight Docker Compose-like orchestration system for Linux Containers (LXC). It provides simple YAML-based container management through a CLI interface.

## Key Commands

### Development and Testing
```bash
# Test the CLI directly
python3 /srv/lxc-compose/cli/lxc_compose.py --help

# Check Python syntax
python3 -m py_compile srv/lxc-compose/cli/*.py

# Make scripts executable
chmod +x install.sh get.sh
chmod +x srv/lxc-compose/cli/lxc-compose-wrapper.sh
```

### Usage Commands
```bash
lxc-compose up       # Create and start containers from config
lxc-compose down     # Stop containers
lxc-compose start    # Start stopped containers
lxc-compose stop     # Stop running containers
lxc-compose list     # List containers with status and ports
lxc-compose destroy  # Stop and remove containers
```

## Architecture

### Directory Structure
- `srv/lxc-compose/cli/` - Core CLI implementation
  - `lxc_compose.py` - Main CLI application with all commands
  - `lxc-compose-wrapper.sh` - Simple bash wrapper
  - Other utility scripts (doctor.py, port_manager.py, hosts_manager.py) - Legacy, may be removed
- `install.sh` - Installation script
- `get.sh` - Quick installation downloader
- Root config files:
  - User creates `lxc-compose.yml` in their project directory

### Core Components

1. **CLI Application** (`srv/lxc-compose/cli/lxc_compose.py`)
   - Click-based command-line interface
   - Manages container lifecycle through LXC commands
   - YAML configuration parsing
   - Port forwarding via iptables
   - Status monitoring with IP and port display

2. **Installation Script** (`install.sh`)
   - Installs dependencies (LXD, Python packages)
   - Sets up networking and iptables
   - Creates `/usr/local/bin/lxc-compose` wrapper
   - Generates example configuration

## Configuration Format

Containers are defined in `lxc-compose.yml`:
```yaml
containers:
  - name: container-name
    image: ubuntu:22.04      # Optional, defaults to ubuntu:22.04
    ip: 10.0.3.10           # Optional static IP
    ports:
      - "8080:80"           # host:container format
      - "8443:443"
    mounts:
      - ./app:/var/www    # Simple format: host:container
      # OR explicit format:
      # - source: ./app
      #   target: /var/www
    services:
      - name: service-name
        command: command-to-run
        type: systemd       # Optional, creates systemd service
```

## Key Implementation Details

### Container Management
- Uses `lxc` CLI commands for container operations
- Containers are created with `lxc launch`
- Port forwarding implemented via iptables DNAT rules
- Mounts added as LXC devices
- Services run via `lxc exec` commands

### Data Storage
- Port forwards saved in `/etc/lxc-compose/port-forwards.json`
- Container registry in `/etc/lxc-compose/registry.json` (optional)
- Logs in `/var/log/lxc-compose/` (if used)

### Networking
- Default bridge: lxcbr0
- Default subnet: 10.0.3.0/24
- IP forwarding enabled via sysctl
- NAT configured through iptables

## Dependencies

- Python 3.8+ with packages: click, pyyaml
- System: LXD/LXC, iptables
- Ubuntu 22.04 or 24.04 LTS

## Common Development Tasks

### Adding New Commands
1. Add new method to `LXCCompose` class
2. Add Click command decorator and function
3. Test with `python3 srv/lxc-compose/cli/lxc_compose.py [command]`

### Modifying Container Creation
1. Edit `create_container()` method in lxc_compose.py
2. Update configuration parsing if needed
3. Test with sample config file

### Updating Port Forwarding
1. Modify `setup_port_forwarding()` method
2. Update port display in `list_containers()`
3. Ensure iptables rules are properly managed

## Testing Approach

Manual testing procedure:
1. Create test `lxc-compose.yml` file
2. Run `lxc-compose up` to create containers
3. Verify with `lxc-compose list` for status and ports
4. Test `lxc-compose down/start/stop` commands
5. Clean up with `lxc-compose destroy`
6. Check `/etc/lxc-compose/` for state files