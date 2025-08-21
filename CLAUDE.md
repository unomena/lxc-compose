# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LXC Compose is a minimalist container orchestration tool for LXC that provides Docker Compose-like YAML configuration. The tool prioritizes simplicity and security, with a small command set focused on essential operations.

## Core Architecture

### Main Components
- **CLI Implementation**: `cli/lxc_compose.py` - Single Python file with all functionality
- **Wrapper Script**: `cli/lxc-compose-wrapper.sh` - Handles sudo elevation
- **Installation**: `install.sh` and `get.sh` - System installation and quick setup

### Design Principles
- Stateless operation - derives all state from LXC runtime
- No daemon/background service - direct LXC command execution
- Security-first with iptables rules for port management
- Shared hosts file at `/srv/lxc-compose/etc/hosts` for container DNS
- Container IPs tracked in `/etc/lxc-compose/container-ips.json`

## Development Commands

### Running Without Installation
```bash
# From project root
python3 cli/lxc_compose.py up -f lxc-compose.yml
python3 cli/lxc_compose.py down -f lxc-compose.yml
python3 cli/lxc_compose.py list
python3 cli/lxc_compose.py destroy -f lxc-compose.yml

# Testing commands
python3 cli/lxc_compose.py test                          # Test all containers
python3 cli/lxc_compose.py test <container>              # Test specific container
python3 cli/lxc_compose.py test <container> list         # List available tests
python3 cli/lxc_compose.py test <container> internal     # Run internal tests only
python3 cli/lxc_compose.py test <container> external     # Run external tests only
python3 cli/lxc_compose.py test <container> port_forwarding  # Test port forwarding

# Logs command
python3 cli/lxc_compose.py logs <container>              # List available logs
python3 cli/lxc_compose.py logs <container> <log_name>   # View specific log
python3 cli/lxc_compose.py logs <container> <log_name> --follow  # Follow log output

# Shell access
python3 cli/lxc_compose.py exec <container>              # Get shell in container
```

### After Installation
```bash
lxc-compose up       # Create/start containers
lxc-compose down     # Stop containers
lxc-compose list     # List status
lxc-compose destroy  # Remove containers
lxc-compose test     # Run tests
lxc-compose logs <container> <log>  # View logs
lxc-compose exec <container>        # Shell access

# System-wide operations (requires confirmation)
lxc-compose up --all
lxc-compose down --all
lxc-compose destroy --all
```

## Configuration Structure

### YAML Format
```yaml
version: '1.0'
containers:
  container-name:
    template: ubuntu|ubuntu-minimal|alpine
    release: lts|jammy|3.19
    exposed_ports: [80, 443]
    depends_on: [other-container]
    
    mounts:
      - ./local:/container/path
      - source: ./config
        target: /etc/app
    
    packages: [nginx, python3]
    
    services:
      service-name:
        command: /path/to/command
        directory: /working/dir
        user: username
        autostart: true
        autorestart: true
        stdout_logfile: /var/log/service.log
        stderr_logfile: /var/log/service_err.log
    
    logs:
      - name:/path/to/log
      - error:/path/to/error.log
    
    tests:
      internal:
        - health:/app/tests/internal_tests.sh
      external:
        - health:/app/tests/external_tests.sh
      port_forwarding:
        - iptables:/app/tests/port_forwarding_tests.sh
    
    post_install:
      - name: "Setup step"
        command: |
          echo "Multi-line bash commands"
```

### Key Features
- Environment variable expansion: `${VAR}` or `${VAR:-default}`
- `.env` file auto-loading from project directory
- Services generate supervisor configs dynamically
- Tests support internal (in container), external (from host), and port forwarding checks

## Container Templates

### Alpine (alpine:3.19)
- Smallest footprint (~150MB)
- Best for datastores: PostgreSQL, Redis
- Uses apk package manager

### Ubuntu Minimal (ubuntu-minimal:lts)
- Balanced size (~300MB)
- Good for Python/Node apps
- Limited package set

### Ubuntu (ubuntu:lts)
- Full Ubuntu environment
- All packages available
- Development/production parity

## Networking Architecture

### Port Management
- `exposed_ports`: Only these ports accessible from outside
- iptables DNAT rules: Forward host ports to container IPs
- FORWARD chain rules: Block non-exposed ports
- Verification: `sudo iptables -t nat -L PREROUTING -n | grep DNAT`

### Container Communication
- Shared hosts file for name resolution
- Containers reference each other by name
- IPs stored in `/etc/lxc-compose/container-ips.json`

## Testing System

### Test Types
1. **Internal Tests**: Run inside container, check services and processes
2. **External Tests**: Run from host, verify network accessibility
3. **Port Forwarding Tests**: Check iptables rules and port mappings

### Container-Specific Tests
For multi-container apps (e.g., django-celery-app):
- Each container has its own internal test script
- External tests verify cross-container connectivity
- Port forwarding tests ensure security (only required ports exposed)

## Code Modification Guidelines

### CLI Structure (cli/lxc_compose.py)
- `LXCCompose` class: Core logic for all operations
- Direct `subprocess` calls to `lxc` commands
- Color constants: RED, GREEN, YELLOW, BLUE, NC
- All file operations require sudo/root
- System-wide operations need explicit user confirmation

### Adding New Commands
1. Add Click command decorator
2. Use `-f/--file` option for config file (default: lxc-compose.yml)
3. Handle both single container and --all operations
4. Use colored output for user feedback
5. Exit codes: 0 for success, 1 for errors

### Error Handling
- Always check subprocess return codes
- Provide clear error messages with context
- Use color coding: RED for errors, YELLOW for warnings, GREEN for success
- Clean up resources on failure (unmount, remove partial containers)

## Sample Applications

### Available Samples
- `django-celery-app`: Multi-container Django + Celery + PostgreSQL + Redis
- `django-minimal`: Single container Django + PostgreSQL
- `flask-app`: Flask + Redis in separate containers
- `nodejs-app`: Node.js + MongoDB
- `searxng-app`: Privacy-respecting search engine

### Testing Samples
```bash
cd samples/django-celery-app
lxc-compose up                    # Deploy
lxc-compose test                  # Run all tests
lxc-compose test sample-django-app internal  # Specific test
lxc-compose logs sample-django-app django --follow  # View logs
```

## Standards and Conventions

See `docs/STANDARDS.md` for:
- Container naming conventions
- Multi-container architecture patterns
- Service configuration via YAML (not .ini files)
- Log organization and paths
- Test structure requirements

## Dependencies and Requirements

- Python 3.8+ with PyYAML and Click
- LXD/LXC installed (`snap install lxd` or `apt install lxc`)
- Ubuntu 22.04 or 24.04 LTS
- Root/sudo access for container operations
- iptables for port forwarding management