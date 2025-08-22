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
- **Template Handler**: `cli/template_handler.py` - Manages template inheritance and library service includes
- **Library Services**: `library/{base}/{version}/{service}/` - 77 pre-configured services across 7 base images
- **Installation**: `install.sh` - System-wide installation to `/usr/local/bin/lxc-compose`

### Critical Design Decisions
- **Stateless Operation**: No database or state files - all state derived from LXC runtime and `/etc/lxc-compose/container-ips.json`
- **Security Model**: iptables DNAT rules for port forwarding, FORWARD chain blocking for non-exposed ports
- **Networking**: Static IP assignment with shared hosts file at `/srv/lxc-compose/etc/hosts`
- **Template Inheritance**: Base template → Library includes → Local configuration

## Development Commands

### Documentation Development
```bash
cd docs
make dev        # Live-reload server on port 8000
make build      # Build static site
make test       # Test with strict mode
make deploy     # Deploy to GitHub Pages
```

### CLI Testing Without Installation
```bash
# Basic operations
python3 cli/lxc_compose.py up -f lxc-compose.yml
python3 cli/lxc_compose.py down -f lxc-compose.yml
python3 cli/lxc_compose.py list
python3 cli/lxc_compose.py destroy -f lxc-compose.yml

# Container testing
python3 cli/lxc_compose.py test                    # Test all
python3 cli/lxc_compose.py test <container>        # Test specific
python3 cli/lxc_compose.py test <container> list   # List tests

# Logs viewing
python3 cli/lxc_compose.py logs <container>        # List logs
python3 cli/lxc_compose.py logs <container> <log>  # View log
python3 cli/lxc_compose.py logs <container> <log> --follow

# Shell access
python3 cli/lxc_compose.py exec <container>
```

### Library Service Testing
```bash
# Test all 77 services
sudo ./bulk_test.sh

# Test individual service
lxc-compose up -f library/alpine/3.19/postgresql/lxc-compose.yml
lxc-compose test postgresql-alpine-3-19
lxc-compose down -f library/alpine/3.19/postgresql/lxc-compose.yml

# Quick server deployment test
./quick_server_test.sh
```

## Configuration Architecture

### YAML Structure with Template Inheritance
```yaml
version: '1.0'
containers:
  myapp:
    template: alpine-3.19        # Base template from templates/
    includes:                    # Library services to include
      - postgresql
      - redis
    
    exposed_ports: [8080]        # Additional ports
    packages: [python3]          # Additional packages
    
    mounts:
      - ./app:/app
    
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
- **Base Templates** (`templates/`): 7 base images with aliases
  - Alpine 3.19 (minimal ~150MB)
  - Ubuntu 22.04/24.04 LTS (full environment)
  - Ubuntu-minimal 22.04/24.04 (balanced ~300MB)
  - Debian 11/12 (stable base)

- **Library Services** (`library/{base}/{version}/{service}/`): 11 service types × 7 bases = 77 configs
  - Databases: PostgreSQL, MySQL, MongoDB
  - Caching: Redis, Memcached
  - Web: Nginx, HAProxy
  - Messaging: RabbitMQ
  - Search: Elasticsearch
  - Monitoring: Grafana, Prometheus

### Container Naming Convention
- Library services: `{service}-{os}-{version}` (e.g., `postgresql-alpine-3-19`)
- Custom containers: User-defined in YAML
- Must be unique across the system to prevent conflicts

## Critical Implementation Details

### LXCCompose Class Methods (cli/lxc_compose.py)
Key methods that handle core functionality:
- `load_config()`: Parses YAML with environment variable expansion
- `setup_container_environment()`: Mounts hosts file, sets up networking
- `manage_exposed_ports()`: Creates/removes iptables rules
- `generate_supervisor_config()`: Converts services to supervisor configs
- `handle_post_install()`: Executes post-install commands in container
- `run_tests()`: Executes internal/external/port_forwarding tests

### Template Handler (cli/template_handler.py)
- `load_template()`: Loads base template from templates/
- `load_library_service()`: Loads and merges library service configs
- `merge_configs()`: Deep merges template → includes → local config
- Stores `__library_service_path__` metadata for test inheritance

### Network Management
- **IP Assignment**: Static IPs from 10.0.3.0/24 subnet
- **Port Forwarding**: iptables DNAT rules from host to container
- **Security**: Default DROP policy with explicit ACCEPT for exposed ports
- **DNS**: Shared hosts file mounted at `/etc/hosts` in all containers

### State Persistence
- `/etc/lxc-compose/container-ips.json`: Maps container names to IPs and ports
- `/srv/lxc-compose/etc/hosts`: Shared hosts file for container DNS
- No other state files - everything else derived from LXC runtime

## Testing Architecture

### Test Types
1. **Internal Tests**: Run inside container, check services/processes
2. **External Tests**: Run from host, verify network accessibility  
3. **Port Forwarding Tests**: Verify iptables rules and security

### Test Inheritance
When using library includes, tests are automatically inherited:
```yaml
includes:
  - postgresql  # Inherits postgresql CRUD test
tests:
  external:
    - myapp:/tests/myapp.sh  # Additional custom test
```

### Bulk Testing Script
`bulk_test.sh` tests all library services:
- Creates control file with timestamps
- Deploys each service sequentially
- Runs all defined tests
- Logs results to individual files
- Generates summary report

## Security Considerations

### Port Security Model
1. Default: All container ports blocked from external access
2. `exposed_ports`: Creates iptables DNAT rules for access
3. Container-to-container: Full access via internal network
4. Host-to-container: Only through exposed ports

### Privilege Requirements
- Container operations require sudo/root
- Wrapper script (`lxc-compose-wrapper.sh`) handles elevation
- System-wide operations (--all flag) require confirmation

## Common Troubleshooting

### Container IP Issues
```bash
# Check saved IPs
cat /etc/lxc-compose/container-ips.json

# Reset container networking
lxc-compose down -f config.yml
lxc-compose destroy -f config.yml
lxc-compose up -f config.yml
```

### Port Forwarding Not Working
```bash
# Check iptables rules
sudo iptables -t nat -L PREROUTING -n | grep DNAT
sudo iptables -L FORWARD -n

# Manually test port
nc -zv localhost <port>
```

### Test Failures
```bash
# Run specific test type
lxc-compose test <container> internal
lxc-compose test <container> external

# Check container logs
lxc-compose logs <container>
lxc-compose exec <container>  # Debug interactively
```

## Performance Characteristics

### Resource Usage
- Alpine containers: ~150MB RAM, minimal CPU
- Ubuntu-minimal: ~300MB RAM
- Full Ubuntu/Debian: ~400-500MB RAM
- Shared kernel = dynamic resource allocation (unlike Docker's pre-allocation)

### Startup Times
- Container creation: 5-10 seconds (first time)
- Container start: 1-2 seconds (subsequent)
- Service startup: Depends on post_install complexity
- No parallel container startup (sequential for dependency order)

## Limitations and Constraints

1. **No Dockerfile Equivalent**: Use post_install commands instead
2. **No Private Registry**: Templates and library services are local
3. **Single Host Only**: No multi-host orchestration
4. **No Auto-scaling**: Manual container management
5. **Limited Health Checks**: Test-based, not continuous monitoring
6. **Sequential Startup**: No parallel container creation