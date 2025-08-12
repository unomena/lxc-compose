# LXC Compose

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()
[![Python](https://img.shields.io/badge/python-3.8+-blue)]()

A Docker Compose-like orchestration tool for LXC containers that provides simple, declarative configuration for deploying and managing multi-container applications using Linux Containers (LXC).

## 🚀 Quick Start

Install with one command:
```bash
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash
```

## Features

- **Docker Compose-like syntax** - Familiar YAML configuration format
- **Static IP assignment** - Predictable networking for containers
- **Service orchestration** - Manage multiple services per container with Supervisor
- **Persistent storage** - Automatic directory mounting and data persistence
- **Centralized logging** - Structured log management across all containers
- **Template-based deployment** - Reusable container templates for different service types

## Quick Usage Example

After installation:

```bash
# Deploy database container
lxc-compose up -f /srv/lxc-compose/configs/database.yaml

# Deploy application
lxc-compose up -f /srv/lxc-compose/configs/app-1.yaml

# Check status
lxc-compose ps

# View logs
lxc-compose logs -f /srv/lxc-compose/configs/app-1.yaml
```

## Prerequisites

- Ubuntu 22.04 or 24.04 LTS
- User with passwordless sudo access
- Minimum 2GB RAM, 20GB disk space
- Python 3.8+ (installed automatically)

## Installation

### Quick Install (Recommended)

Install and configure LXC Compose with a single command:

```bash
# Using curl (recommended)
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash

# Or using wget
wget -qO- https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash
```

This will automatically:
1. Download the latest version from GitHub
2. Install all files to `/srv/lxc-compose/`
3. Create the `lxc-compose` command
4. **Run the full LXC host setup** (install LXC, configure networking, etc.)
5. Configure your system for container management

The entire process takes about 2-3 minutes and your system will be ready to use.

### Manual Installation

If you prefer more control over the installation process:

#### 1. Clone Repository
```bash
git clone https://github.com/unomena/lxc-compose.git
cd lxc-compose
```

#### 2. Installation Options
```bash
# Full installation (files + host setup) - same as one-liner
sudo ./install.sh

# Install files only (skip host setup)
SKIP_SETUP=true sudo ./install.sh

# Just run host setup (if files already installed)
sudo /srv/lxc-compose/setup-lxc-host.sh
```

### Post-Installation

After installation, the setup script will:
- Install and configure LXC/LXD
- Setup bridge networking (10.0.3.0/24)
- Create required directories in `/srv/`
- Install Python dependencies
- Configure system parameters
- Create helper scripts and aliases

### Verify Installation
```bash
# Check LXC status
lxc list

# Verify network bridge
ip addr show lxcbr0

# Test CLI tool
lxc-compose --help

# View available commands
lxc-compose
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         Host Machine                        │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Bridge Network (lxcbr0)                 │   │
│  │                  10.0.3.0/24                         │   │
│  └──────────────────────────────────────────────────────┘   │
│      │              │              │              │         │
│  ┌───▼────┐    ┌───▼────┐    ┌───▼────┐    ┌───▼────┐       │
│  │App-1   │    │App-2   │    │DB/Redis│    │Monitor │       │
│  │10.0.3.11│   │10.0.3.12│   │10.0.3.2│    │10.0.3.3│       │
│  └────────┘    └────────┘    └────────┘    └────────┘       │
│                                                             │
│  /srv/                                                      │
│  ├── lxc-compose/           # System files                  │
│  ├── apps/                  # Application data              │
│  ├── shared/                # Shared resources              │
│  └── logs/                  # Centralized logs              │
└─────────────────────────────────────────────────────────────┘
```

# Directory Structure
```
/srv/
├── lxc-compose/
│   ├── cli/                     # CLI tool
│   ├── templates/               # LXC templates
│   │   ├── base/               # Base OS templates
│   │   ├── app/                # Application container template
│   │   ├── database/           # Database container template
│   │   └── monitor/            # Monitoring container template
│   ├── configs/                # Container configurations
│   │   ├── app-1.yaml
│   │   ├── app-2.yaml
│   │   ├── database.yaml
│   │   └── monitor.yaml
│   └── scripts/                # Helper scripts
│
├── apps/                       # Per-app directories
│   ├── app-1/
│   │   ├── code/              # Git cloned code
│   │   ├── config/            # App config files
│   │   ├── media/             # Django media files
│   │   └── secrets.env        # Environment variables
│   └── app-2/
│       └── ...
│
├── shared/
│   ├── database/
│   │   ├── postgres/          # Postgres data
│   │   └── redis/             # Redis data
│   └── media/                 # Shared media if needed
│
└── logs/
    ├── app-1/
    │   ├── django.log
    │   ├── django.log.1        # Yesterday's log
    │   ├── celery.log
    │   └── nginx.log
    └── app-2/
        └── ...
```

## Usage

### Basic Container Management

```bash
# Create and start container with all services
lxc-compose up -f /srv/lxc-compose/configs/app-1.yaml

# Stop and destroy container
lxc-compose down -f /srv/lxc-compose/configs/app-1.yaml

# Restart all services in container
lxc-compose restart -f /srv/lxc-compose/configs/app-1.yaml
```

### Service Management

```bash
# View logs for a specific service
lxc-compose logs -f /srv/lxc-compose/configs/app-1.yaml django

# Execute commands in container context
lxc-compose exec -f /srv/lxc-compose/configs/app-1.yaml django python manage.py migrate

# Access container shell
lxc exec app-1 -- /bin/bash
```

### Application Deployment Example

```bash
# 1. Setup application directory
sudo mkdir -p /srv/apps/myapp/{code,config,media}

# 2. Clone your application code
cd /srv/apps/myapp
sudo git clone https://github.com/yourrepo/myapp.git code

# 3. Create environment file
sudo tee /srv/apps/myapp/secrets.env << EOF
DEBUG=False
DATABASE_URL=postgresql://user:pass@10.0.3.2:5432/myapp
REDIS_URL=redis://10.0.3.2:6379/0
SECRET_KEY=your-secret-key
EOF

# 4. Deploy the application
lxc-compose up -f /srv/lxc-compose/configs/myapp.yaml

# 5. Run database migrations
lxc-compose exec -f /srv/lxc-compose/configs/myapp.yaml django python manage.py migrate

# 6. Create superuser
lxc-compose exec -f /srv/lxc-compose/configs/myapp.yaml django python manage.py createsuperuser
```

## Configuration Reference

### Container Configuration (YAML)

```yaml
container:
  name: "app-1"
  template: "app"  # Template from /srv/lxc-compose/templates/
  ip: "10.0.3.11"

mounts:
  - host: "/srv/apps/app-1"
    container: "/app"
  - host: "/srv/logs/app-1"
    container: "/var/log/app"

services:
  django:
    command: "python manage.py runserver 0.0.0.0:8000"
    directory: "/app/code"
    environment:
      - "DEBUG=False"
    
  celery:
    command: "celery -A myproject worker -l info"
    directory: "/app/code"
    
  nginx:
    command: "nginx -g 'daemon off;'"
    config_template: "nginx.conf.j2"
```

### Available Templates

| Template | Purpose | Installed Packages |
|----------|---------|-------------------|
| `base` | Minimal OS | Essential utilities |
| `app` | Application containers | Python, Nginx, Supervisor |
| `database` | Database services | PostgreSQL, Redis |
| `monitor` | Monitoring stack | Prometheus, Grafana |

### Network Configuration

- **Bridge Network**: `10.0.3.0/24`
- **Gateway**: `10.0.3.1` (host)
- **Database**: `10.0.3.2`
- **Monitor**: `10.0.3.3`
- **Applications**: `10.0.3.11+`

## Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check LXC status
sudo systemctl status lxc
sudo systemctl status lxc-net

# Verify bridge network
ip addr show lxcbr0

# Check container logs
lxc info container-name --show-log
```

#### Networking Issues
```bash
# Restart LXC networking
sudo systemctl restart lxc-net

# Check iptables rules
sudo iptables -L -n

# Test container connectivity
lxc exec container-name -- ping 10.0.3.1
```

#### Permission Issues
```bash
# Fix ownership of /srv directories
sudo chown -R ubuntu:ubuntu /srv/apps/
sudo chown -R ubuntu:ubuntu /srv/logs/

# Check container mount permissions
lxc exec container-name -- ls -la /app/
```

#### Service Not Starting
```bash
# Check supervisor status
lxc-compose exec -f config.yaml service supervisorctl status

# View service logs
lxc-compose logs -f config.yaml service-name

# Restart specific service
lxc exec container-name -- supervisorctl restart service-name
```

### Debug Mode

```bash
# Enable verbose logging in LXC
echo "lxc.loglevel = DEBUG" | sudo tee -a /etc/lxc/default.conf

# Check system resources
free -h
df -h /srv/
lxc list
```

## Best Practices

- **Resource Management**: Monitor container resource usage with `lxc info`
- **Backup Strategy**: Regularly backup `/srv/apps/` and `/srv/shared/database/`
- **Security**: Use environment files for secrets, never commit credentials
- **Monitoring**: Deploy monitoring container for production environments
- **Updates**: Keep host system and container templates updated

## Contributing

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Follow coding standards**: PEP 8 for Python, use meaningful commit messages
4. **Add tests**: Include unit tests for new functionality
5. **Update documentation**: Update README and code comments
6. **Commit changes**: `git commit -m 'Add amazing feature'`
7. **Push to branch**: `git push origin feature/amazing-feature`
8. **Open a Pull Request**

### Development Setup

```bash
# Clone and setup development environment
git clone <repository-url>
cd devops

# Create Python virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install development dependencies
pip install -r requirements-dev.txt

# Run tests
python -m pytest tests/

# Code formatting
black srv/lxc-compose/cli/
flake8 srv/lxc-compose/cli/
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: Check this README and inline code comments
- **Issues**: Report bugs and feature requests via GitHub Issues
- **Community**: Join discussions in GitHub Discussions

---

**Note**: This tool is designed for development and testing environments. For production use, ensure proper security hardening, monitoring, and backup procedures are in place.