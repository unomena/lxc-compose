# LXC Compose Documentation

**Docker Compose-like orchestration for LXC containers**

LXC Compose brings the simplicity and power of Docker Compose to Linux Containers (LXC), providing a declarative way to define and manage multi-container applications using lightweight system containers.

## What is LXC Compose?

LXC Compose is a container orchestration tool that:
- Uses YAML configuration files similar to Docker Compose
- Manages LXC containers instead of Docker containers
- Provides familiar commands (`up`, `down`, `ps`, `exec`)
- Handles networking, dependencies, and port forwarding automatically
- Integrates with system init for production deployments

## Key Features

### 🚀 Docker-Like Simplicity
- Define your entire application stack in a single `lxc-compose.yml` file
- Use familiar Docker Compose commands and workflows
- Simple, declarative configuration syntax

### 🔧 Production-Ready
- System containers with full init systems
- Supervisor-managed services within containers
- Automatic IP allocation and hostname resolution
- Host directory mounting for live code updates

### 🌐 Smart Networking
- Automatic IP address allocation (10.0.3.11+)
- Container hostname resolution via `/etc/hosts`
- Port forwarding with Docker-like syntax (`8080:80`)
- Bridge networking with static IPs

### 📦 Container Management
- Dependency resolution and ordered startup
- Integrated port forwards and dependencies
- Support for Ubuntu, Debian, and other distributions
- Template-based container creation

## Quick Start

```bash
# Install LXC Compose
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash

# Create your configuration
cat > lxc-compose.yml <<EOF
version: '1.0'

containers:
  myapp-db:
    template: ubuntu
    release: jammy
    ports:
      - 5432:5432  # PostgreSQL
    packages:
      - postgresql
      - postgresql-contrib

  myapp-web:
    template: ubuntu
    release: jammy
    depends_on:
      - myapp-db
    ports:
      - 8080:80  # Web server
    mounts:
      - .:/app
    packages:
      - python3
      - nginx
EOF

# Start your application
lxc-compose up

# Check status
lxc-compose ps

# Execute commands
lxc-compose exec myapp-web bash

# Stop everything
lxc-compose down
```

## Documentation

### Getting Started
- [Installation Guide](getting-started.md#installation)
- [Your First Application](getting-started.md#first-app)
- [Basic Commands](getting-started.md#basic-commands)

### Configuration
- [Configuration Reference](configuration.md)
- [Container Configuration](configuration.md#containers)
- [Networking](configuration.md#networking)
- [Port Forwarding](configuration.md#port-forwarding)
- [Dependencies](configuration.md#dependencies)

### Guides
- [Migrating from Docker Compose](docker-compose-migration.md)
- [Production Deployment](production.md)
- [Troubleshooting](troubleshooting.md)

### Advanced Topics
- [Custom Templates](advanced/templates.md)
- [Service Management](advanced/services.md)
- [Network Configuration](advanced/networking.md)

## Important Concepts

### Container Naming
Container names must be **globally unique** across your entire system. Use project namespaces to avoid conflicts:

```yaml
# Good - uses project namespace
containers:
  myproject-db:
  myproject-cache:
  myproject-web:

# Bad - too generic, will conflict
containers:
  db:
  cache:
  web:
```

### No Aliases
Unlike Docker Compose, LXC Compose does not support container aliases. Each container has exactly one name that serves as its hostname. Reference containers by their exact names:

```yaml
environment:
  DATABASE_URL: postgresql://user:pass@myproject-db:5432/dbname
  #                                   ^^^^^^^^^^^^
  #                                   Use exact container name
```

### Integrated Configuration
Port forwards and dependencies are defined within each container configuration, not in separate sections:

```yaml
containers:
  myapp-web:
    depends_on:           # Dependencies integrated here
      - myapp-db
    ports:                # Port forwards integrated here
      - 8080:80
    mounts:
      - .:/app
```

## System Requirements

- **OS**: Ubuntu 22.04/24.04 or Debian 11/12
- **Privileges**: sudo/root access required
- **Network**: Bridge network configuration
- **Storage**: Sufficient space for containers

## Architecture

LXC Compose manages system containers that:
- Run full Linux distributions with init systems
- Can host multiple services per container
- Share the host kernel (lightweight)
- Support systemd/supervisor service management
- Mount host directories for development

## Comparison with Docker Compose

| Feature | Docker Compose | LXC Compose |
|---------|---------------|-------------|
| Configuration | docker-compose.yml | lxc-compose.yml |
| Container Type | Application containers | System containers |
| Init System | Single process | Full systemd/init |
| Resource Usage | Higher overhead | Lightweight |
| Isolation | Strong isolation | Shared kernel |
| Port Syntax | `"8080:80"` | `"8080:80"` (same) |
| Networking | Docker networks | Bridge + /etc/hosts |

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/unomena/lxc-compose/issues)
- **Examples**: See the [examples/](https://github.com/unomena/lxc-compose/tree/main/examples) directory
- **Commands**: Run `lxc-compose --help` for command reference

## License

LXC Compose is open source software released under the MIT License.