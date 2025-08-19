# LXC Compose

Simple Docker Compose-like orchestration for Linux Containers (LXC).

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash

# Create a lxc-compose.yml file
cat > lxc-compose.yml << EOF
containers:
  - name: web
    image: ubuntu-minimal:22.04
    ports:
      - "8080:80"
    mounts:
      - ./app:/var/www
EOF

# Start containers
lxc-compose up

# List containers
lxc-compose list
```

## Features

- 🚀 Simple YAML-based configuration
- 📦 Container lifecycle management
- 🔌 Port forwarding support
- 📁 Directory mounting
- 🔧 Service management
- 📊 Status monitoring with port mappings

## Commands

### Standard Commands (config-scoped)
```bash
lxc-compose up       # Create and start containers from config
lxc-compose down     # Stop containers from config
lxc-compose start    # Start stopped containers from config
lxc-compose stop     # Stop running containers from config
lxc-compose list     # List containers from config with status and ports
lxc-compose status   # Alias for list
lxc-compose destroy  # Stop and remove containers from config
```

### System-wide Commands (--all flag)
```bash
lxc-compose up --all       # Start ALL containers on system
lxc-compose down --all     # Stop ALL containers on system
lxc-compose start --all    # Start ALL stopped containers on system
lxc-compose stop --all     # Stop ALL running containers on system
lxc-compose destroy --all  # Destroy ALL containers on system (DANGEROUS!)
```

**Safety:** When using `--all`, you must type the full confirmation phrase:
- "Yes, I want to [action] all containers. I am aware of the risks involved."

All commands support `-f` flag to specify a custom config file (default: `lxc-compose.yml`).
By default, commands only affect containers defined in the config file.

## Configuration

Create a `lxc-compose.yml` file in your project:

```yaml
containers:
  - name: app-server
    image: ubuntu-minimal:22.04  # Uses minimal image by default (smaller/faster)
    ip: 10.0.3.10                # Optional static IP
    ports:
      - "8080:80"           # host:container
      - "8443:443"
    mounts:
      - ./app:/var/www    # Simple format: host:container
    services:
      - name: nginx
        command: apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'
        
  - name: database
    image: ubuntu-minimal:22.04
    ip: 10.0.3.11
    ports:
      - "5432:5432"
    mounts:
      - ./data:/var/lib/postgresql
    services:
      - name: postgresql
        command: |
          apt-get update && apt-get install -y postgresql
          service postgresql start
```

### Configuration Options

- **name**: Container name (required)
- **image**: Base image options:
  - `ubuntu-minimal:22.04` (default, ~100MB) - Minimal Ubuntu, has apt
  - `ubuntu:22.04` (~400MB) - Full Ubuntu server
  - `alpine:3.18` (~8MB) - Ultra-minimal, uses apk package manager
  - `debian:12` (~120MB) - Debian stable
  - `rockylinux:9` (~120MB) - RHEL-compatible
- **ip**: Static IP address (optional)
- **ports**: Port mappings as "host:container"
- **mounts**: Directory mappings
- **services**: Services to run in the container

## Requirements

- Ubuntu 22.04 or 24.04 LTS
- LXD/LXC installed
- Python 3.8+
- Root/sudo access for container management

## Installation

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh -o install.sh
sudo bash install.sh
```

The installer will:
- Install LXD/LXC and Python dependencies
- Setup networking and port forwarding
- Install the `lxc-compose` command
- Create sample configuration

## Alpine Linux Example

For ultra-minimal containers (~8MB), use Alpine Linux:

```yaml
containers:
  - name: alpine-web
    image: alpine:3.18
    ports:
      - "8080:80"
    services:
      - name: web-server
        command: |
          apk add --no-cache python3
          cd /tmp && python3 -m http.server 80
```

Note: Alpine uses `apk` instead of `apt` for package management.

## Architecture

LXC Compose provides a thin orchestration layer over LXC, similar to Docker Compose but for system containers. It manages:
- Container lifecycle (create, start, stop, destroy)
- Network configuration and port forwarding via iptables
- Directory mounting between host and containers
- Service installation and startup

## License

MIT License - See LICENSE file for details.