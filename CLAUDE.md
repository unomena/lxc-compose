# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LXC Compose is a minimalist container orchestration tool for LXC that provides exactly 4 commands: up, down, list, and destroy. It uses Docker Compose-like YAML configuration but specifically for LXC containers. The tool prioritizes simplicity and security over features.

## Architecture

### Core Implementation
- **Main CLI**: `srv/lxc-compose/cli/lxc_compose.py` - Single Python file implementing all functionality
- **Wrapper Script**: `srv/lxc-compose/cli/lxc-compose-wrapper.sh` - Handles sudo elevation
- **Installation**: `install.sh` and `get.sh` - System installation scripts

### Key Design Principles
- No daemon or background service - direct LXC command execution
- Stateless operation - derives state from LXC runtime
- Security-first: iptables rules block all non-exposed ports
- Shared hosts file at `/srv/lxc-compose/etc/hosts` for container name resolution
- Container IPs tracked in `/etc/lxc-compose/container-ips.json`

## Development Commands

```bash
# Test without installation (from project root)
python3 srv/lxc-compose/cli/lxc_compose.py up -f lxc-compose.yml
python3 srv/lxc-compose/cli/lxc_compose.py list
python3 srv/lxc-compose/cli/lxc_compose.py down
python3 srv/lxc-compose/cli/lxc_compose.py destroy

# Install system-wide
sudo ./install.sh

# After installation
lxc-compose up       # Create/start containers from lxc-compose.yml
lxc-compose down     # Stop containers
lxc-compose list     # List container status
lxc-compose destroy  # Remove containers

# System-wide operations (requires confirmation)
lxc-compose up --all
lxc-compose down --all
lxc-compose list --all
lxc-compose destroy --all
```

## Configuration Format

The CLI supports two container formats in `lxc-compose.yml`:

1. **Dictionary format**: `containers: {name: {...}}`
2. **List format**: `containers: [{name: foo}, ...]`

Mount formats:
- String: `"./path:/container/path"`
- Object: `{source: ./path, target: /container/path}`

Key features:
- Environment variable expansion: `${VAR}` or `${VAR:-default}`
- `.env` file support for environment variables
- Container dependencies via `depends_on`
- Post-install commands for setup
- Package manager auto-detection (apt/apk)

## Networking and Security

- **Port Security**: Only `exposed_ports` are accessible from outside via iptables DNAT rules
- **Container Communication**: All containers share `/srv/lxc-compose/etc/hosts` for name resolution
- **IP Management**: Container IPs saved in `/etc/lxc-compose/container-ips.json`
- **Firewall Rules**: Automatic iptables FORWARD rules block non-exposed ports

To verify port forwarding:
```bash
sudo iptables -t nat -L PREROUTING -n | grep DNAT
sudo iptables -L FORWARD -n | grep lxc-compose
```

## Testing Sample Projects

```bash
# Django + PostgreSQL (single Alpine container)
cd samples/django-minimal
python3 ../../srv/lxc-compose/cli/lxc_compose.py up

# Flask with Redis
cd samples/flask-app
python3 ../../srv/lxc-compose/cli/lxc_compose.py up

# Node.js with MongoDB
cd samples/nodejs-app
python3 ../../srv/lxc-compose/cli/lxc_compose.py up
```

## Code Modifications

When modifying the CLI:
- All logic is in `srv/lxc-compose/cli/lxc_compose.py`
- The LXCCompose class handles all operations
- Container operations use direct `lxc` commands via subprocess
- Error handling uses colored output (RED, GREEN, YELLOW, BLUE constants)
- System-wide operations require explicit confirmation

## Dependencies

- Python 3.8+ with PyYAML and Click
- LXD/LXC installed and configured
- Ubuntu 22.04 or 24.04 LTS
- Root/sudo access for container and network operations