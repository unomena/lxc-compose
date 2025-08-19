# LXC Compose

Simple container orchestration for LXC with Docker Compose-like YAML configuration.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash
```

## Commands

Only four commands, simple and focused:

```bash
lxc-compose up       # Create and start containers
lxc-compose down     # Stop containers  
lxc-compose list     # List containers with status
lxc-compose destroy  # Stop and remove containers
```

### System-wide Operations

Use `--all` flag to operate on ALL containers on the system (requires confirmation):

```bash
lxc-compose up --all       # Start ALL containers
lxc-compose down --all     # Stop ALL containers
lxc-compose list --all     # List ALL containers
lxc-compose destroy --all  # Destroy ALL containers (DANGEROUS!)
```

## Configuration

Create `lxc-compose.yml` in your project:

```yaml
version: '1.0'
containers:
  myapp:
    template: ubuntu
    release: jammy
    exposed_ports: [80, 443]  # Only these ports accessible from outside
    mounts: [".:/app"]
    packages: [nginx, python3]
```

**Key Features:**
- **Shared hosts file**: All containers can access each other by name
- **Exposed ports**: Only specified ports are accessible from outside
- **Security**: All other ports are blocked by iptables rules

## Sample Projects

See the `samples/` directory for ready-to-use configurations:

- **django-minimal**: Django + PostgreSQL in Alpine
- **flask-app**: Flask with Redis cache
- **nodejs-app**: Express.js with MongoDB

## Requirements

- Ubuntu 22.04 or 24.04 LTS
- LXD/LXC installed
- Python 3.8+

## License

MIT