# LXC Compose Commands Reference

Complete reference for all LXC Compose commands and their options.

## Table of Contents

- [Command Overview](#command-overview)
- [Core Commands](#core-commands)
  - [up](#up-command)
  - [down](#down-command)
  - [list](#list-command)
  - [destroy](#destroy-command)
- [Additional Commands](#additional-commands)
  - [logs](#logs-command)
  - [test](#test-command)
- [Global Options](#global-options)
- [Command Examples](#command-examples)
- [Exit Codes](#exit-codes)

## Command Overview

```bash
lxc-compose [OPTIONS] COMMAND [ARGS]...

Commands:
  up       Create and start containers
  down     Stop containers
  list     List containers and their status
  destroy  Stop and remove containers
  logs     View container logs
  test     Run container health tests
```

## Core Commands

### up Command

Create and start containers from configuration file.

#### Synopsis
```bash
lxc-compose up [OPTIONS]
```

#### Options
- `-f, --file FILE` - Specify configuration file (default: `lxc-compose.yml`)
- `--all` - Start ALL containers on the system (requires confirmation)

#### Behavior
1. Reads configuration from YAML file
2. Loads environment variables from `.env` if present
3. Creates containers if they don't exist
4. Installs packages
5. Sets up mounts
6. Configures networking and port forwarding
7. Runs post-install commands
8. Generates supervisor configurations from services
9. Starts containers

#### Examples
```bash
# Use default lxc-compose.yml
lxc-compose up

# Use custom config file
lxc-compose up -f production.yml

# Start ALL containers system-wide
lxc-compose up --all
```

#### Container Creation Process
1. **Dependency Resolution**: Containers with `depends_on` start after their dependencies
2. **Template Launch**: Creates container from specified template and release
3. **Package Installation**: Installs packages using apt (Ubuntu) or apk (Alpine)
4. **Mount Setup**: Creates mount points and binds directories/files
5. **Network Configuration**: Sets up shared hosts file and IP tracking
6. **Port Forwarding**: Creates iptables DNAT rules for exposed ports
7. **Service Configuration**: Generates supervisor configs from services definitions
8. **Post-Install**: Executes post-install commands in order
9. **Container Start**: Ensures container is running

### down Command

Stop running containers without removing them.

#### Synopsis
```bash
lxc-compose down [OPTIONS]
```

#### Options
- `-f, --file FILE` - Specify configuration file (default: `lxc-compose.yml`)
- `--all` - Stop ALL containers on the system (requires confirmation)

#### Behavior
1. Reads configuration to identify containers
2. Stops containers in reverse dependency order
3. Containers remain created but stopped
4. Mounts and configuration remain intact
5. Port forwarding rules are removed

#### Examples
```bash
# Stop containers from default config
lxc-compose down

# Stop containers from custom config
lxc-compose down -f production.yml

# Stop ALL containers system-wide
lxc-compose down --all
```

### list Command

List containers and their current status.

#### Synopsis
```bash
lxc-compose list [OPTIONS]
```

#### Options
- `-f, --file FILE` - Specify configuration file (default: `lxc-compose.yml`)
- `--all` - List ALL containers on the system

#### Output Format
```
Container Status:
┌─────────────────────┬─────────┬────────────┬──────────────┐
│ Container           │ Status  │ IPv4       │ Exposed Ports│
├─────────────────────┼─────────┼────────────┼──────────────┤
│ sample-datastore    │ RUNNING │ 10.0.3.100 │ 5432, 6379   │
│ sample-django-app   │ RUNNING │ 10.0.3.101 │ 80           │
└─────────────────────┴─────────┴────────────┴──────────────┘
```

#### Status Values
- `RUNNING` - Container is active and running
- `STOPPED` - Container exists but is stopped
- `FROZEN` - Container is frozen/suspended
- `NOT CREATED` - Container defined in config but doesn't exist

#### Examples
```bash
# List containers from default config
lxc-compose list

# List containers from custom config
lxc-compose list -f production.yml

# List ALL containers on system
lxc-compose list --all
```

### destroy Command

Stop and permanently remove containers.

#### Synopsis
```bash
lxc-compose destroy [OPTIONS]
```

#### Options
- `-f, --file FILE` - Specify configuration file (default: `lxc-compose.yml`)
- `--all` - Destroy ALL containers on the system (DANGEROUS - requires confirmation)

#### Behavior
1. Stops containers if running
2. Removes containers permanently
3. Cleans up port forwarding rules
4. Updates hosts file
5. Removes IP tracking entries
6. **WARNING**: This is irreversible - all container data is lost

#### Confirmation
- Always asks for confirmation before destroying
- Type `yes` to confirm destruction
- `--all` flag requires additional confirmation

#### Examples
```bash
# Destroy containers from default config
lxc-compose destroy
# Confirmation: Are you sure you want to destroy containers? Type 'yes': 

# Destroy containers from custom config
lxc-compose destroy -f production.yml

# Destroy ALL containers system-wide (VERY DANGEROUS)
lxc-compose destroy --all
# Confirmation: This will destroy ALL containers. Type 'yes': 
```

## Additional Commands

### logs Command

View and follow container logs.

#### Synopsis
```bash
lxc-compose logs CONTAINER [LOG_NAME] [OPTIONS]
```

#### Arguments
- `CONTAINER` - Container name (required)
- `LOG_NAME` - Specific log to view (optional)

#### Options
- `-f, --file FILE` - Specify configuration file (default: `lxc-compose.yml`)
- `--follow` - Follow log output in real-time (like `tail -f`)

#### Behavior
1. Without `LOG_NAME`: Lists all available logs for the container
2. With `LOG_NAME`: Displays the specified log
3. With `--follow`: Continuously shows new log entries
4. Auto-discovers logs from supervisor service definitions

#### Log Discovery
Logs come from two sources:
1. **Explicit logs**: Defined in `logs:` section of config
2. **Auto-discovered**: From supervisor service stdout/stderr definitions

#### Examples
```bash
# List available logs for container
lxc-compose logs sample-django-app
# Output:
# Available logs for sample-django-app:
# - django
# - django-error
# - celery
# - nginx
# - supervisor

# View specific log
lxc-compose logs sample-django-app django

# Follow log in real-time
lxc-compose logs sample-django-app nginx --follow

# Use custom config file
lxc-compose logs -f production.yml myapp nginx
```

### test Command

Run health check tests for containers.

#### Synopsis
```bash
lxc-compose test [CONTAINER] [TEST_TYPE] [OPTIONS]
```

#### Arguments
- `CONTAINER` - Container name (optional, tests all if omitted)
- `TEST_TYPE` - Type of test to run (optional, runs all if omitted)
  - `all` - Run all test types (default)
  - `list` - List available tests
  - `internal` - Run internal tests only
  - `external` - Run external tests only
  - `port_forwarding` - Run port forwarding tests only

#### Options
- `-f, --file FILE` - Specify configuration file (default: `lxc-compose.yml`)

#### Test Types

##### Internal Tests
- Run inside the container
- Verify services are running
- Check ports are listening
- Test internal functionality

##### External Tests
- Run from the host
- Verify connectivity to container
- Test exposed services
- Check API endpoints

##### Port Forwarding Tests
- Verify iptables DNAT rules
- Check port forwarding configuration
- Ensure security rules are in place

#### Output Format
```
Running tests for sample-django-app...

[INTERNAL TESTS]
✓ health: All services running
✓ database: PostgreSQL connection successful

[EXTERNAL TESTS]
✓ http: Web server responding
✓ api: API endpoints accessible

[PORT FORWARDING]
✓ iptables: Port 80 forwarding configured
✗ security: Port 5432 should not be forwarded

Tests: 6 passed, 1 failed
```

#### Examples
```bash
# Test all containers
lxc-compose test

# Test specific container
lxc-compose test sample-django-app

# List available tests for container
lxc-compose test sample-django-app list

# Run only internal tests
lxc-compose test sample-django-app internal

# Run only external tests
lxc-compose test sample-datastore external

# Run only port forwarding tests
lxc-compose test sample-django-app port_forwarding

# Use custom config file
lxc-compose test -f production.yml myapp
```

## Global Options

### Configuration File
All commands support the `-f` or `--file` option to specify a custom configuration file:

```bash
lxc-compose -f custom.yml COMMAND
lxc-compose --file /path/to/config.yml COMMAND
```

Default: `lxc-compose.yml` in current directory

### System-Wide Operations
Core commands support the `--all` flag for system-wide operations:

```bash
lxc-compose COMMAND --all
```

**Available for:**
- `up --all` - Start ALL containers on system
- `down --all` - Stop ALL containers on system
- `list --all` - List ALL containers on system
- `destroy --all` - Destroy ALL containers (DANGEROUS)

**Note:** System-wide operations require confirmation to prevent accidents.

## Command Examples

### Development Workflow
```bash
# Start development environment
lxc-compose up

# Check status
lxc-compose list

# View logs
lxc-compose logs app-container django --follow

# Run tests
lxc-compose test

# Stop for the day
lxc-compose down
```

### Production Deployment
```bash
# Use production config
lxc-compose up -f production.yml

# Monitor logs
lxc-compose logs -f production.yml web nginx --follow

# Run health checks
lxc-compose test -f production.yml

# Graceful shutdown
lxc-compose down -f production.yml
```

### Debugging Workflow
```bash
# List all containers on system
lxc-compose list --all

# Check specific container logs
lxc-compose logs myapp supervisor

# Run internal tests
lxc-compose test myapp internal

# Check port forwarding
lxc-compose test myapp port_forwarding

# View iptables rules directly
sudo iptables -t nat -L PREROUTING -n | grep lxc-compose
```

### Cleanup Operations
```bash
# Stop project containers
lxc-compose down

# Remove project containers
lxc-compose destroy
# Type 'yes' to confirm

# Emergency: stop everything
lxc-compose down --all

# Nuclear option: remove everything (CAREFUL!)
lxc-compose destroy --all
# Type 'yes' twice to confirm
```

## Exit Codes

LXC Compose uses standard exit codes:

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | Command completed successfully |
| 1 | General Error | Command failed with error |
| 2 | Config Error | Configuration file error |
| 3 | Container Error | Container operation failed |
| 4 | Network Error | Network configuration failed |
| 5 | Permission Error | Insufficient permissions (need sudo) |
| 127 | Command Not Found | LXC/LXD not installed |

### Checking Exit Codes
```bash
# Run command
lxc-compose up

# Check exit code
echo $?
# 0 = success, non-zero = error
```

### Error Handling in Scripts
```bash
#!/bin/bash

# Exit on error
set -e

# Start containers
if lxc-compose up; then
    echo "Containers started successfully"
else
    echo "Failed to start containers"
    exit 1
fi

# Run tests
if lxc-compose test; then
    echo "All tests passed"
else
    echo "Tests failed"
    lxc-compose down
    exit 1
fi
```

## Command Completion

### Bash Completion
Add to `~/.bashrc`:
```bash
_lxc_compose() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="up down list destroy logs test"
    
    case "${prev}" in
        lxc-compose)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
        -f|--file)
            COMPREPLY=( $(compgen -f -X '!*.yml' -- ${cur}) )
            return 0
            ;;
    esac
}
complete -F _lxc_compose lxc-compose
```

### Common Aliases
Add to `~/.bashrc` or `~/.bash_aliases`:
```bash
alias lcu='lxc-compose up'
alias lcd='lxc-compose down'
alias lcl='lxc-compose list'
alias lct='lxc-compose test'
alias lclog='lxc-compose logs'
alias lcdestroy='lxc-compose destroy'
```

## Best Practices

1. **Always use configuration files**: Keep infrastructure as code
2. **Test before production**: Run `lxc-compose test` before deploying
3. **Use specific configs**: Separate dev/staging/production configs
4. **Monitor logs**: Use `--follow` to watch logs during operations
5. **Graceful shutdown**: Use `down` before `destroy`
6. **Backup before destroy**: Container destruction is permanent
7. **Use dependencies**: Define `depends_on` for proper startup order
8. **Validate configs**: Check YAML syntax before running
9. **Environment variables**: Use `.env` files for configuration
10. **Regular testing**: Automate `lxc-compose test` in CI/CD