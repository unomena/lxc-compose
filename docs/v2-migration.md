# LXC Compose v2 - Migration Guide

## Overview

LXC Compose v2 brings major improvements including simplified configuration, better container naming, and Docker Compose-like workflows. This guide covers migrating from v1 to v2.

## The New Structure

### Primary Scripts (User-Facing)

1. **`get.sh`** - Quick installer
   - Used for curl one-liners
   - Downloads and runs install.sh
   - Minimal, lightweight

2. **`install.sh`** - Complete installation  
   - Sets up host environment
   - Installs all dependencies
   - Configures networking
   - Creates lxc-compose command
   - **Replaces**: setup-lxc-host.sh

3. **`wizard.sh`** - Main management interface
   - Interactive menu system
   - Container management
   - System updates
   - Diagnostics (doctor)
   - Recovery tools
   - **Replaces**: update.sh, doctor.py, recover.sh, clean-update.sh

### Standalone Utility

4. **`create-django-sample.sh`** - Demo application
   - Educational example
   - Kept separate as it's optional

## What Changed

### Scripts Removed (Functionality Merged)
- ❌ `setup-lxc-host.sh` → Merged into `install.sh`
- ❌ `update.sh` → Merged into `wizard.sh`
- ❌ `recover.sh` → Merged into `wizard.sh`
- ❌ `clean-update.sh` → Merged into `wizard.sh`
- ❌ `install-doctor.sh` → Part of main install

### Scripts Moved to Internal
- `scripts/expose-services.sh` → `srv/lxc-compose/scripts/internal/`
- `scripts/fix-flask-manager.sh` → `srv/lxc-compose/scripts/internal/`
- `scripts/register-container.sh` → `srv/lxc-compose/scripts/internal/`
- `scripts/setup-port-forwarding.sh` → `srv/lxc-compose/scripts/internal/`

## User Experience

### Installation
```bash
# One-liner installation
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash
```

### Post-Installation
Everything through the wizard:

```bash
# Interactive menu
lxc-compose wizard

# Direct commands
lxc-compose wizard setup-db      # Setup database
lxc-compose wizard setup-app     # Setup application
lxc-compose wizard update        # Update system
lxc-compose wizard doctor        # Run diagnostics
lxc-compose wizard recover       # Recovery tools
lxc-compose wizard web           # Open web interface
```

### CLI Still Works
```bash
lxc-compose up
lxc-compose down
lxc-compose logs
lxc-compose exec <container> <command>
lxc-compose doctor --fix
```

## Benefits

1. **Clear Entry Points**: No confusion about which script to use
2. **Professional Structure**: Clean, maintainable codebase
3. **Consistent Interface**: Everything post-install through wizard
4. **Reduced Complexity**: From 10+ scripts to 3 main ones
5. **Better UX**: Interactive menus with command-line options

## Migration for Existing Users

Existing installations will automatically get the new structure on next update:

```bash
# On existing servers
lxc-compose update

# After update, use the new wizard
lxc-compose wizard
```

## Developer Notes

### Directory Structure
```
lxc-compose/
├── get.sh                          # Entry point 1: Download & install
├── install.sh                      # Entry point 2: Full installation
├── wizard.sh                       # Entry point 3: Management interface
├── create-django-sample.sh         # Standalone demo
└── srv/lxc-compose/
    ├── cli/
    │   ├── lxc_compose.py          # CLI implementation
    │   └── doctor.py               # Diagnostic tool
    └── scripts/
        └── internal/               # Internal scripts (not user-facing)
            ├── expose-services.sh
            ├── fix-flask-manager.sh
            ├── register-container.sh
            └── setup-port-forwarding.sh
```

### Integration Points

- CLI commands delegate to wizard for complex operations
- Wizard provides both interactive and command-line interfaces
- Internal scripts are called by wizard/CLI as needed
- Single source of truth for each functionality

## Configuration Changes in v2

### 1. No More Aliases
**v1 Configuration:**
```yaml
containers:
  datastore:
    aliases:
      - db
      - postgres
      - database
```

**v2 Configuration:**
```yaml
containers:
  myapp-datastore:  # Use explicit, namespaced names
    # No aliases - reference by exact name
```

### 2. Integrated Port Forwards and Dependencies
**v1 Configuration:**
```yaml
containers:
  web:
    # container config

port_forwards:
  - host_port: 8080
    container: web
    container_port: 80

dependencies:
  web:
    depends_on:
      - db
```

**v2 Configuration:**
```yaml
containers:
  myapp-web:
    depends_on:      # Integrated
      - myapp-db
    ports:           # Integrated with Docker-like syntax
      - 8080:80
```

### 3. Simplified Mount Syntax
**v1 Configuration:**
```yaml
mounts:
  - host: /srv/app
    container: /app
    type: bind
    create: true
```

**v2 Configuration:**
```yaml
mounts:
  - /srv/app:/app  # Docker-like syntax
  # or
  - .:/app         # Current directory
```

### 4. Container Name Requirements
- **Must be globally unique** across the system
- **No aliases allowed** - only exact names
- **Use namespaces** to avoid conflicts:
  - `projectname-db`
  - `projectname-web`
  - `com-example-api`

## Hostname Resolution Changes

### v1: Static IP Configuration
```yaml
containers:
  db:
    container:
      ip: 10.0.3.100/24
```

### v2: Automatic IP Allocation
```yaml
containers:
  myapp-db:
    # IP automatically allocated starting from 10.0.3.11
    # Hostname resolution via /etc/hosts
```

## Network Architecture

### IP Allocation Strategy
- **10.0.3.1**: Gateway
- **10.0.3.2-10**: Reserved for system services
- **10.0.3.11+**: Automatically allocated to containers
- Managed via `/srv/lxc-compose/ip-allocations.json`

### /etc/hosts Management
Containers are automatically added to `/etc/hosts`:
```
# BEGIN LXC Compose managed section - DO NOT EDIT
10.0.3.11    myapp-db
10.0.3.12    myapp-cache
10.0.3.13    myapp-web
# END LXC Compose managed section
```

## Command Changes

### New Docker Compose-like Commands
```bash
# v2 adds familiar commands
lxc-compose up           # Start containers from lxc-compose.yml
lxc-compose up -d        # Start in background
lxc-compose down         # Stop containers
lxc-compose ps           # List containers
lxc-compose exec web bash # Execute in container
lxc-compose logs         # View logs
lxc-compose restart      # Restart containers
```

### Configuration File Discovery
v2 automatically finds configuration:
1. `-f` flag: `lxc-compose up -f custom.yml`
2. Current directory: `./lxc-compose.yml`
3. Current directory: `./lxc-compose.yaml`

## Breaking Changes

### 1. Container Aliases Removed
- **Impact**: Connection strings using aliases will break
- **Fix**: Update all references to use exact container names

### 2. Name Conflicts Not Allowed
- **Impact**: Generic names like `db`, `web` will conflict
- **Fix**: Use project namespaces for all containers

### 3. Port Forward Format
- **Impact**: Old verbose format not supported
- **Fix**: Use Docker-like syntax `"8080:80"`

## Migration Checklist

- [ ] **Update container names** to use namespaces
- [ ] **Remove all aliases** from configuration
- [ ] **Update connection strings** to use exact container names
- [ ] **Convert port forwards** to Docker-like syntax
- [ ] **Move dependencies** into container configuration
- [ ] **Simplify mount syntax** to `host:container` format
- [ ] **Test hostname resolution** after migration
- [ ] **Verify no naming conflicts** with existing containers

## Example Migration

### Complete v1 Configuration
```yaml
containers:
  datastore:
    container:
      name: datastore
      template: ubuntu
      release: jammy
      ip: 10.0.3.100/24
    aliases:
      - db
      - postgres
    mounts:
      - host: /srv/data
        container: /data
        type: bind

  app:
    container:
      name: app
      template: ubuntu
      release: jammy
      ip: 10.0.3.101/24
    aliases:
      - web
      - frontend

port_forwards:
  - host_port: 8080
    container: app
    container_port: 80

dependencies:
  app:
    depends_on:
      - datastore
```

### Migrated v2 Configuration
```yaml
version: '1.0'

containers:
  myproject-datastore:
    template: ubuntu
    release: jammy
    # IP auto-allocated
    mounts:
      - /srv/data:/data
    ports:
      - 5432:5432

  myproject-app:
    template: ubuntu
    release: jammy
    depends_on:
      - myproject-datastore
    ports:
      - 8080:80
    environment:
      DATABASE_HOST: myproject-datastore  # Use exact name
```

## Version

This is LXC Compose v2.0 - featuring simplified configuration, automatic IP management, and Docker Compose compatibility.