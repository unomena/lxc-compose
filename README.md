# LXC Compose

Docker Compose-like orchestration for LXC containers with a focus on simplicity, security, and minimal footprint.

## Why LXC Compose?

### The Single-Server Renaissance

In an era where cloud costs are spiraling and Kubernetes complexity is overwhelming, **LXC Compose brings back the simplicity of single-server deployments** without sacrificing modern DevOps practices. 

### The Problem with Container Orchestration Today

- **Docker's Resource Tax**: Docker containers require pre-allocated resources, leading to waste and inefficiency. You're paying for CPU and memory that sits idle.
- **Kubernetes Overhead**: Running Kubernetes means multiple nodes, control planes, and massive complexity for what might be a simple application.
- **Cloud Lock-in**: Platforms like AWS Fargate or Google Cloud Run charge premium prices per container, making multi-container architectures expensive.
- **Lost Simplicity**: What happened to just deploying your app on a server? The simplicity is buried under layers of abstraction.

### The LXC Compose Solution

LXC Compose leverages **Linux Containers (LXC)** - the same technology that powers Docker - but removes the unnecessary layers:

- **System Containers vs Application Containers**: LXC runs system containers that behave like lightweight VMs. Multiple services can run in one container, reducing overhead.
- **Shared Kernel Efficiency**: Containers share the host kernel directly, using resources dynamically as needed - no pre-allocation required.
- **Single Server Power**: One modern server can efficiently run dozens of containers that would require multiple Docker hosts or Kubernetes nodes.
- **Familiar Syntax**: If you know Docker Compose, you already know LXC Compose. The same YAML format, the same concepts, just more efficient.

### Real Cost Comparison

Consider a typical web application with 5 services (web, api, worker, database, cache):

| Platform | Monthly Cost | Notes |
|----------|-------------|--------|
| **AWS Fargate** | ~$200-400 | Pay per container, per CPU/memory allocation |
| **Kubernetes (EKS)** | ~$150-300 | Minimum 2-3 nodes + control plane costs |
| **Docker on EC2** | ~$50-150 | Requires larger instance for resource allocation |
| **LXC Compose** | ~$20-40 | Single server, dynamic resource sharing |

### Perfect For

- **Startups**: Run your entire stack on one server until you truly need to scale
- **Side Projects**: Deploy multiple projects on one VPS without interference
- **Agencies**: Host client applications efficiently without container-per-client costs
- **Self-Hosting**: Run your own services (GitLab, Nextcloud, etc.) with minimal overhead
- **Development Teams**: Replicate production on modest hardware

### Not Another Docker

LXC Compose **isn't trying to replace Docker** for microservices or cloud-native applications. Instead, it's bringing back the **server-native deployment model** with modern tooling:

- ✅ **Use LXC Compose when**: You want to run on a single server, minimize costs, and keep things simple
- ❌ **Use Docker/K8s when**: You need multi-cloud deployment, have true microservices, or require orchestration at scale

### Migration is Simple

Already using Docker Compose? Migration is straightforward:

```yaml
# Your existing docker-compose.yml concepts map directly:
- image → template + packages
- ports → exposed_ports  
- volumes → mounts
- environment → .env file
- command → services section
```

Most applications can be migrated in under an hour. [See our migration guide →](docs/docker-compose-migration.md)

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Commands](#commands)
- [Configuration](#configuration)
- [Directory Structure](#directory-structure)
- [Sample Projects](#sample-projects)
- [Testing](#testing)
- [Networking](#networking)
- [Logs](#logs)
- [Security](#security)
- [Requirements](#requirements)
- [Documentation](#documentation)
- [License](#license)

## Features

- **Docker Compose-like syntax**: Familiar YAML configuration for LXC containers
- **Minimal footprint**: Alpine Linux support for ~150MB containers
- **Dynamic service configuration**: Define services in YAML, auto-generate supervisor configs
- **Comprehensive testing**: Built-in health checks with internal, external, and port forwarding tests
- **Shared networking**: Containers communicate via shared hosts file
- **Security-first**: iptables rules block all non-exposed ports
- **Log aggregation**: Centralized log viewing with follow mode
- **Environment variables**: Full `.env` file support with variable expansion
- **Container dependencies**: Ordered startup with `depends_on`
- **Post-install automation**: Flexible container initialization

## Installation

### Quick Install (One-line)

```bash
# Using curl
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash

# Or using wget
wget -qO- https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash

# Note: The pipe to 'sudo bash' is important - don't use 'sudo curl'
```

### Local Installation

```bash
git clone https://github.com/unomena/lxc-compose.git
cd lxc-compose
sudo ./install.sh
```

The install script automatically detects whether it's being run locally or remotely and handles the installation accordingly.

## Commands

### Core Commands

#### `lxc-compose up`
Create and start containers from configuration.

```bash
lxc-compose up                    # Use lxc-compose.yml in current directory
lxc-compose up -f custom.yml      # Use custom config file
lxc-compose up --all              # Start ALL containers system-wide (requires confirmation)
```

#### `lxc-compose down`
Stop running containers.

```bash
lxc-compose down                  # Stop containers from lxc-compose.yml
lxc-compose down -f custom.yml    # Stop containers from custom config
lxc-compose down --all            # Stop ALL containers system-wide (requires confirmation)
```

#### `lxc-compose list`
List containers and their status.

```bash
lxc-compose list                  # List containers from lxc-compose.yml
lxc-compose list -f custom.yml    # List containers from custom config
lxc-compose list --all            # List ALL containers system-wide
```

#### `lxc-compose destroy`
Stop and permanently remove containers.

```bash
lxc-compose destroy               # Destroy containers from lxc-compose.yml
lxc-compose destroy -f custom.yml # Destroy containers from custom config
lxc-compose destroy --all         # Destroy ALL containers (DANGEROUS - requires confirmation)
```

### Additional Commands

#### `lxc-compose logs`
View and follow container logs.

```bash
lxc-compose logs <container>                    # List available logs for container
lxc-compose logs <container> <log-name>         # View specific log
lxc-compose logs <container> <log-name> --follow # Follow log in real-time

Examples:
lxc-compose logs sample-django-app              # List all available logs
lxc-compose logs sample-django-app django       # View Django application log
lxc-compose logs sample-django-app nginx --follow # Follow nginx access log
```

#### `lxc-compose test`
Run health check tests for containers.

```bash
lxc-compose test                           # Test all containers
lxc-compose test <container>               # Test specific container
lxc-compose test <container> list          # List available tests for container
lxc-compose test <container> internal      # Run only internal tests
lxc-compose test <container> external      # Run only external tests
lxc-compose test <container> port_forwarding # Run only port forwarding tests

Examples:
lxc-compose test                           # Run all tests for all containers
lxc-compose test sample-django-app         # Run all tests for Django app
lxc-compose test sample-datastore internal # Run internal tests for datastore
```

## Configuration

### Basic Configuration

```yaml
version: "1.0"

containers:
  myapp:
    image: ubuntu:jammy      # Base OS image (ubuntu:22.04, images:alpine/3.19, etc.)
    packages:                # Packages to install
      - nginx
      - python3
    exposed_ports: [80, 443] # Ports accessible from host
    mounts:                  # Directory/file mounts
      - ".:/app"             # Mount current directory to /app
```

### Advanced Configuration

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for complete configuration reference including:
- Container templates and releases
- Service definitions
- Environment variables
- Mount configurations
- Post-install commands
- Container dependencies
- Test configurations
- Log definitions

## Directory Structure

### Project Directory

```
project/
├── lxc-compose.yml          # Main configuration file
├── .env                     # Environment variables
├── requirements.txt         # Python dependencies (Python projects)
├── package.json            # Node dependencies (Node projects)
├── config/                 # Configuration files
│   ├── container-name/     # Per-container configs
│   │   ├── supervisord.conf
│   │   ├── nginx.conf
│   │   └── redis.conf
├── tests/                  # Test scripts
│   ├── internal_tests.sh   # Tests run inside container
│   ├── external_tests.sh   # Tests run from host
│   └── port_forwarding_tests.sh # Port forwarding verification
├── src/                    # Application source code
└── README.md              # Project documentation
```

### System Installation

```
/srv/lxc-compose/           # Installation directory
├── cli/
│   └── lxc_compose.py     # Main CLI script
├── docs/                  # Documentation
├── samples/               # Sample projects
└── etc/
    └── hosts              # Shared hosts file for containers

/etc/lxc-compose/
└── container-ips.json     # Container IP tracking

/var/log/lxc-compose/      # Log directory
```

## Sample Projects

Ready-to-use configurations in `samples/` directory:

### django-celery-app
Full-featured Django application with Celery workers, PostgreSQL, and Redis.
- Multi-container setup with proper dependencies
- Alpine datastore (~150MB) + Ubuntu Minimal app (~300MB)
- Nginx reverse proxy
- Supervisor for process management
- Comprehensive test suite

```bash
cd samples/django-celery-app
lxc-compose up
# Access at http://localhost
```

### django-minimal
Simplified Django + PostgreSQL in a single Alpine container (~150MB).
- Minimal footprint
- PostgreSQL and Django in one container
- Ideal for development

```bash
cd samples/django-minimal
lxc-compose up
# Access at http://localhost:8000
```

### flask-app
Flask application with Redis caching.
- Redis for session/cache storage
- Nginx reverse proxy
- Production-ready configuration

```bash
cd samples/flask-app
lxc-compose up
# Access at http://localhost
```

### nodejs-app
Express.js application with MongoDB.
- MongoDB for data persistence
- PM2 for process management
- API-ready configuration

```bash
cd samples/nodejs-app
lxc-compose up
# Access at http://localhost:3000
```

## Testing

LXC Compose includes a comprehensive testing framework:

### Test Types

1. **Internal Tests**: Run inside the container to verify services
2. **External Tests**: Run from host to verify connectivity
3. **Port Forwarding Tests**: Verify iptables DNAT rules

### Writing Tests

See [docs/TESTING.md](docs/TESTING.md) for complete testing documentation.

## Networking

### Container Communication
- All containers share `/srv/lxc-compose/etc/hosts` for name resolution
- Containers can communicate using container names as hostnames
- Container IPs are tracked in `/etc/lxc-compose/container-ips.json`

### Port Security
- Only `exposed_ports` are accessible from the host
- iptables DNAT rules handle port forwarding
- All other ports are blocked by default FORWARD rules

See [docs/NETWORKING.md](docs/NETWORKING.md) for detailed networking documentation.

## Logs

### Log Management
- Define logs in `lxc-compose.yml` for each container
- View logs with `lxc-compose logs` command
- Follow logs in real-time with `--follow` flag
- Logs are automatically discovered from supervisor configs

### Example Log Configuration

```yaml
logs:
  - django:/var/log/django/django.log
  - nginx:/var/log/nginx/access.log
  - postgres:/var/lib/postgresql/logfile
```

## Security

### Security Features
- **Port isolation**: Only explicitly exposed ports are accessible
- **iptables rules**: Automatic firewall configuration
- **Container isolation**: LXC provides kernel-level isolation
- **Environment variables**: Sensitive data kept in `.env` files
- **No hardcoded credentials**: All configuration via environment

### Best Practices
- Never expose database ports unless necessary
- Use `.env` files for all sensitive configuration
- Regularly update container packages
- Monitor logs for suspicious activity

## Requirements

### System Requirements
- **OS**: Ubuntu 22.04 or 24.04 LTS
- **LXD/LXC**: Installed and configured
- **Python**: 3.8 or higher
- **Dependencies**: python3-yaml, python3-click
- **Privileges**: Root/sudo access for container operations

### Network Requirements
- IP forwarding enabled
- iptables available
- Bridge network configured (lxdbr0)

## Documentation

### Detailed Guides
- [Configuration Reference](docs/CONFIGURATION.md) - Complete YAML configuration guide
- [Commands Reference](docs/COMMANDS.md) - Detailed command documentation
- [Testing Guide](docs/TESTING.md) - Writing and running tests
- [Networking Guide](docs/NETWORKING.md) - Network configuration and security
- [Standards Guide](docs/STANDARDS.md) - Project configuration standards

### Quick References
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Migration Guide](docs/MIGRATION.md) - Migrating from Docker Compose
- [API Reference](docs/API.md) - Python API for custom integrations

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT - See [LICENSE](LICENSE) for details