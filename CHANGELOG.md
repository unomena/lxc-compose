# Changelog

All notable changes to LXC Compose will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2024-08-22

### 🚀 Major Production Resilience Improvements

This release focuses on making LXC Compose truly production-ready with automatic recovery, proper service management, and resilient networking. The system now achieves "pull the plug" resilience - everything recovers automatically after system restart.

### Added

#### Automatic Service Recovery
- **Supervisor Auto-Start**: Supervisor now automatically starts on container restart
  - Ubuntu/Debian: Enabled via `systemctl enable supervisor`
  - Alpine: Enabled via `rc-update add supervisord default`
- **Database Auto-Start**: PostgreSQL, MySQL, and other database services configured to start automatically
  - Alpine PostgreSQL: `rc-update add postgresql default` added to library service
  - Similar fixes applied to other database services

#### Environment Variable Inheritance
- **Load-Env Wrapper**: All services now wrapped with `/usr/local/bin/load-env.sh`
  - Automatically sources `/app/.env` before executing service commands
  - Ensures all services have access to environment variables
  - Works for both Alpine (`/bin/sh`) and Ubuntu (`/bin/bash`)

#### OS-Aware Configuration
- **Supervisor Config Placement**: Automatic detection of correct config directory
  - Ubuntu/Debian: `/etc/supervisor/conf.d/*.conf`
  - Alpine: `/etc/supervisor.d/*.ini`
  - Detection based on presence of `systemctl` command

#### Port Forwarding Resilience
- **UPF Rule Cleanup**: Enhanced cleanup and update mechanism
  - Always removes existing rules before adding new ones
  - Prevents stale rules after container destroy/recreate
  - Matches rules by hostname, destination, and comment patterns
- **Hostname-Based Forwarding**: Uses container names for resilient forwarding
  - Rules survive container IP changes
  - Automatic resolution via `/etc/hosts`

### Changed

#### CLI Improvements (cli/lxc_compose.py)
- `setup_services()`: Now detects OS and places configs correctly
- `enable_supervisor_autostart()`: New method for init system configuration  
- `setup_port_forwarding()`: Always cleans before creating rules
- `remove_port_forwarding()`: Enhanced pattern matching for cleanup

#### Library Service Updates
- **Alpine Supervisor**: Added environment loader script creation
- **Ubuntu Supervisor**: Added systemd enablement and loader script
- **Alpine PostgreSQL**: Added auto-start configuration

#### Sample Updates
- **Django Minimal**: Removed redundant environment variables
- **Flask App**: Cleaned up environment configuration
- Both samples now demonstrate best practices for production deployment

### Fixed

#### Critical Issues Resolved
1. **Supervisor Not Starting**: Services now auto-recover after container restart
2. **Environment Variables Missing**: Services inherit .env variables correctly
3. **Port Forwarding Stale Rules**: Proper cleanup prevents routing issues
4. **Supervisor Config Not Found**: Configs placed in OS-appropriate directories
5. **Database Not Auto-Starting**: Databases now start automatically on boot

### Documentation

- **README.md**: Added comprehensive troubleshooting section
- **README.md**: Added production resilience features section
- **CLAUDE.md**: Updated with v2.1 implementation details
- **Test Scripts**: Enhanced documentation in sample test files

### Testing

Comprehensive lifecycle testing performed:
- Deploy → Stop → Start → Verify same IPs/ports
- Destroy → Recreate → Verify new IPs with updated forwarding
- Multiple cycles tested with Django and Flask samples
- All services recover automatically after restart

## [2.0.0] - 2024-08-20

### Added
- GitHub-based template fetching system
- Supervisor service with auto-inclusion
- Environment variable support in YAML
- UPF (Uncomplicated Port Forwarding) integration

## [1.0.0] - 2024-08-15

### Initial Release
- Core LXC orchestration functionality
- Docker Compose-like YAML syntax
- Template inheritance system
- Library of pre-configured services
- Test framework with inheritance
- Port forwarding and networking