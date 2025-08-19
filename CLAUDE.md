# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LXC Compose is a simple container orchestration tool for LXC. It provides only 4 commands: up, down, list, and destroy. Each command supports the --all flag for system-wide operations.

## Key Commands

```bash
# Test without installation
python3 srv/lxc-compose/cli/lxc_compose.py up
python3 srv/lxc-compose/cli/lxc_compose.py list

# Install
sudo ./install.sh

# Use after installation
lxc-compose up       # Create/start containers from lxc-compose.yml
lxc-compose down     # Stop containers
lxc-compose list     # List status
lxc-compose destroy  # Remove containers

# System-wide (requires confirmation)
lxc-compose up --all
lxc-compose down --all
lxc-compose list --all
lxc-compose destroy --all
```

## Core Implementation

The CLI (`srv/lxc-compose/cli/lxc_compose.py`) supports:
- Dictionary format: `containers: {name: {...}}`
- List format: `containers: [{name: foo}, ...]`
- Mount formats: `"./path:/container"` or `{source: path, target: path}`
- Exposed ports with iptables security (no port forwarding)
- Shared hosts file at `/srv/lxc-compose/etc/hosts`
- Package installation (apt/apk auto-detected)
- Post-install commands
- Container dependencies

## Networking

- Shared hosts file mounted in all containers for name resolution
- Only exposed_ports are accessible from outside
- All other ports blocked by iptables FORWARD rules
- Container IPs saved in `/etc/lxc-compose/container-ips.json`

## Sample Projects

In `samples/` directory:
- `django-minimal/`: Single Alpine container with Django + PostgreSQL
- `flask-app/`: Flask with Redis
- `nodejs-app/`: Express.js with MongoDB

## Testing

```bash
# Test with sample
cd samples/django-minimal
python3 ../../srv/lxc-compose/cli/lxc_compose.py up

# Check port forwarding
sudo iptables -t nat -L PREROUTING -n | grep DNAT
```