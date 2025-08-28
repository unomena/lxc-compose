# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LXC Compose is a Docker Compose-like orchestration tool for Linux Containers (LXC) that provides simple, declarative configuration for managing multi-container applications. It offers the familiar Docker Compose YAML syntax while leveraging the efficiency of system containers over application containers, resulting in significantly lower resource usage and cost.

## High-Level Architecture

### System Flow
```
User → CLI (lxc_compose.py) → LXC/LXD API → Containers
         ↓                          ↓
    Template Handler          iptables rules
         ↓                          ↓
    Library Services         Port forwarding
```

### Core Components
- **CLI Implementation**: `cli/lxc_compose.py` - Monolithic Python file (~2000 lines) containing all orchestration logic
- **GitHub Template Handler**: `cli/github_template_handler.py` - Fetches templates/services from GitHub (primary)
- **Local Template Handler**: `cli/template_handler.py` - Fallback for local template/service loading
- **Library Structure**: 
  - `library/templates/` - Base OS templates (7 images: Alpine, Ubuntu, Ubuntu-minimal, Debian)
  - `library/services/{os}/{version}/{service}/` - Pre-configured services (77 total)
- **Installation**: `install.sh` - System-wide installation to `/usr/local/bin/lxc-compose`

### Critical Design Decisions
- **Stateless Operation**: No database or state files - all state derived from LXC runtime and `/srv/lxc-compose/etc/container-metadata.json`
- **Security Model**: iptables DNAT rules for port forwarding, FORWARD chain blocking for non-exposed ports
- **Networking**: Static IP assignment (10.0.3.0/24 subnet) with shared hosts file at `/srv/lxc-compose/etc/hosts`
- **Template Inheritance**: Base template → Library includes → Local configuration (deep merge)

## Essential Development Commands

### Quick Testing (No Installation Required)
```bash
# Container lifecycle
python3 cli/lxc_compose.py up -f lxc-compose.yml
python3 cli/lxc_compose.py down -f lxc-compose.yml
python3 cli/lxc_compose.py destroy -f lxc-compose.yml
python3 cli/lxc_compose.py list

# Container testing
python3 cli/lxc_compose.py test                    # Test all containers
python3 cli/lxc_compose.py test <container>        # Test specific container
python3 cli/lxc_compose.py test <container> list   # List available tests

# Debugging
python3 cli/lxc_compose.py logs <container>        # List available logs
python3 cli/lxc_compose.py logs <container> <log>  # View specific log
python3 cli/lxc_compose.py logs <container> <log> --follow
python3 cli/lxc_compose.py exec <container>        # Shell access

# Status checking
python3 cli/lxc_compose.py status                  # View all container statuses
python3 cli/lxc_compose.py status <container>      # View specific container
```

### Library Service Testing
```bash
# Test all 77 services (takes ~30 minutes)
sudo ./bulk_test.sh

# Test individual service
lxc-compose up -f library/alpine/3.19/postgresql/lxc-compose.yml
lxc-compose test postgresql-alpine-3-19
lxc-compose down -f library/alpine/3.19/postgresql/lxc-compose.yml

# Quick deployment test
./quick_server_test.sh
```

### Documentation Development
```bash
cd docs
make dev        # Live-reload server on http://localhost:8000
make build      # Build static site to site/
make test       # Test with strict mode
make deploy     # Deploy to GitHub Pages
```

### System Installation/Uninstallation
```bash
sudo ./install.sh       # Install to /usr/local/bin/lxc-compose
sudo ./install.sh -u    # Uninstall
```

## Configuration Architecture

### YAML Structure
```yaml
version: '1.0'
containers:
  myapp:
    template: alpine-3.19        # Base OS template
    includes:                    # Library services to include
      - postgresql
      - redis
    
    exposed_ports: [8080]        # Ports accessible from host
    packages: [python3]          # Additional packages to install
    
    mounts:                      # Volume mounts
      - ./app:/app
    
    environment_file: .env       # Environment variables file
    
    services:                    # Supervisor-managed services
      app:
        command: python3 /app/main.py
        directory: /app
    
    logs:                        # Log paths for viewing
      - app:/var/log/app.log
    
    tests:                       # Test scripts
      internal:
        - health:/app/tests/internal.sh
      external:
        - api:/app/tests/external.sh
```

### Template System

#### GitHub Fetching (Primary)
- Fetches from `https://raw.githubusercontent.com/unomena/lxc-compose/main/`
- Configurable via environment variables:
  - `LXC_COMPOSE_REPO`: Custom repository URL
  - `LXC_COMPOSE_BRANCH`: Specific branch/tag

#### Available Base Templates
- `alpine-3.19` - Minimal ~150MB
- `ubuntu-22.04`, `ubuntu-24.04` - Full environment ~400MB
- `ubuntu-minimal-22.04`, `ubuntu-minimal-24.04` - Balanced ~300MB
- `debian-11`, `debian-12` - Stable base ~400MB

#### Available Library Services (per OS)
- Databases: `postgresql`, `mysql`, `mongodb`
- Caching: `redis`, `memcached`
- Web: `nginx`, `haproxy`
- Messaging: `rabbitmq`
- Search: `elasticsearch`
- Monitoring: `grafana`, `prometheus`
- Runtime: `python3`, `supervisor`

### Container Naming Convention
- Library services: `{service}-{os}-{version}` (e.g., `postgresql-alpine-3-19`)
- Custom containers: User-defined in YAML
- Must be globally unique to prevent conflicts

## Critical Implementation Details

### LXCCompose Class (cli/lxc_compose.py)

#### Key Methods and Line References
- `load_config()` (Line ~200): YAML parsing with env var expansion
- `setup_container_environment()` (Line ~950): Mounts, networking setup
- `manage_exposed_ports()` (Line ~450): iptables rule management
- `setup_services()` (Line ~1072): OS-aware supervisor config generation
- `enable_supervisor_autostart()` (Line ~1113): Init system configuration
- `setup_port_forwarding()` (Line ~561): UPF rule creation with cleanup
- `remove_port_forwarding()` (Line ~585): Enhanced rule cleanup
- `run_post_install()` (Line ~1200): Post-install command execution
- `run_tests()` (Line ~1400): Test execution framework

#### v2.1 Production Resilience Features
1. **OS Detection** (Line 1072-1120)
   - Uses `which systemctl` to differentiate Ubuntu/Debian from Alpine
   - Ubuntu/Debian: `/etc/supervisor/conf.d/*.conf`
   - Alpine: `/etc/supervisor.d/*.ini`

2. **Environment Wrapper** (Line 1089-1091)
   - All commands wrapped with `/usr/local/bin/load-env.sh`
   - Sources `/app/.env` before execution

3. **Port Forwarding Recovery** (Line 561-606)
   - Always removes existing rules before adding
   - Matches hostname, destination, and comment patterns

4. **Auto-Start Services** (Line 1113-1136)
   - Systemd: `systemctl enable supervisor`
   - OpenRC: `rc-update add supervisord default`

### State Management Files
- `/srv/lxc-compose/etc/container-metadata.json` - Container IPs and ports
- `/srv/lxc-compose/etc/hosts` - Shared DNS resolution
- `/srv/lxc-compose/etc/port-mappings.json` - UPF port mappings

### Network Architecture
- **Subnet**: 10.0.3.0/24 (configurable in code)
- **IP Assignment**: Static, sequential from .2
- **Port Forwarding**: iptables DNAT from host to container
- **Security**: Default DROP with explicit ACCEPT for exposed ports

## Testing Framework

### Test Types
1. **Internal**: Run inside container
2. **External**: Run from host
3. **Port Forwarding**: Verify iptables rules

### Test Inheritance
Library includes automatically inherit their tests:
```yaml
includes:
  - postgresql  # Inherits CRUD test
tests:
  external:
    - custom:/tests/mytest.sh  # Additional test
```

### Bulk Testing
- `bulk_test.sh`: Sequential testing of all library services
- Generates timestamped logs in test-results/
- Creates summary report with pass/fail status

## Common Issues and Solutions

### Container IP Conflicts
```bash
# Check metadata
cat /srv/lxc-compose/etc/container-metadata.json

# Full reset
lxc-compose destroy -f config.yml
rm /srv/lxc-compose/etc/container-metadata.json
lxc-compose up -f config.yml
```

### Port Forwarding Issues
```bash
# Check iptables
sudo iptables -t nat -L PREROUTING -n | grep DNAT
sudo iptables -L FORWARD -n | grep <container_ip>

# Manual test
nc -zv localhost <port>
```

### Service Not Starting
```bash
# Check supervisor status
lxc-compose exec <container>
supervisorctl status

# Check logs
cat /var/log/supervisor/supervisord.log
```

### Test Failures
```bash
# Run specific test type
lxc-compose test <container> internal
lxc-compose test <container> external

# Debug interactively
lxc-compose exec <container>
```

## Performance Characteristics

### Resource Usage
- Alpine: ~150MB RAM per container
- Ubuntu-minimal: ~300MB RAM per container
- Full Ubuntu/Debian: ~400-500MB RAM per container
- Dynamic CPU allocation (shared kernel advantage)

### Timing
- First container creation: 5-10 seconds
- Subsequent starts: 1-2 seconds
- Service startup: Varies by post_install complexity
- Container operations: Sequential (dependency ordering)

## Architectural Constraints

1. **No Dockerfile Support**: Use post_install commands
2. **No Private Registry**: GitHub or local templates only
3. **Single Host**: No multi-host orchestration
4. **No Auto-scaling**: Manual container management
5. **Limited Health Checks**: Test-based, not continuous
6. **Sequential Operations**: No parallel container creation
7. **Root Required**: Most operations need sudo/root access

## Sample Projects Location

Full examples available in `samples/` directory:
- `django-celery-app/` - Multi-service Django with Celery, Redis, PostgreSQL
- `flask-app/` - Flask with Redis backend
- `nodejs-app/` - Node.js application
- `searxng/` - Privacy-focused search engine
- `docs-server/` - MkDocs documentation server

Each sample includes complete configuration, tests, and README.