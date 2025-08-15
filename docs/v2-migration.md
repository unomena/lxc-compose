# LXC Compose v2 - Consolidated Structure

## Overview

LXC Compose has been refactored from 10+ confusing scripts to a clean, professional structure with just **3 main entry points**.

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

## Version

This is LXC Compose v2.0 - a major refactor focused on usability and maintainability.