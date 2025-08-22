# LXC Compose Documentation

**Docker Compose-like orchestration for LXC containers**

LXC Compose brings the simplicity of Docker Compose to Linux Containers (LXC), providing a declarative way to define and manage multi-container applications using lightweight system containers.

## Why Choose LXC Compose?

### The Single-Server Renaissance

In an era where cloud costs are spiraling and Kubernetes complexity is overwhelming, **LXC Compose brings back the simplicity of single-server deployments** without sacrificing modern DevOps practices.

### The Problem with Container Orchestration Today

Modern container orchestration has become unnecessarily complex and expensive:

- **Docker's Resource Tax**: Docker containers require pre-allocated resources, leading to waste. You're paying for CPU and memory that sits idle.
- **Kubernetes Overhead**: Even simple applications require multiple nodes, control planes, and extensive configuration.
- **Cloud Platform Costs**: AWS Fargate, Google Cloud Run, and Azure Container Instances charge premium prices per container.
- **Lost Simplicity**: Deploying a simple web app now requires understanding networking, service meshes, and orchestration concepts.

### The LXC Compose Solution

LXC Compose leverages **Linux Containers (LXC)** - the same technology that powers Docker - but removes unnecessary layers:

#### System Containers vs Application Containers
- **Docker**: One process per container (application containers)
- **LXC**: Full system containers that behave like lightweight VMs
- **Result**: Run multiple services in one container, reducing overhead by 5-10x

#### Resource Efficiency
- **Dynamic allocation**: Containers use only the resources they need
- **No pre-allocation**: No wasted reserved CPU or memory
- **Shared kernel**: Direct kernel access without Docker daemon overhead
- **Real numbers**: Run 50+ containers on a single 4GB VPS

### Real-World Cost Comparison

Consider a typical web application with 5 services (web, api, worker, database, cache):

| Platform | Monthly Cost | Configuration | Hidden Costs |
|----------|-------------|---------------|--------------|
| **AWS Fargate** | ~$200-400 | 0.25 vCPU × 5 containers | NAT gateway, load balancer |
| **Kubernetes (EKS)** | ~$150-300 | 3 × t3.medium nodes | Control plane, monitoring |
| **Docker on EC2** | ~$50-150 | t3.large instance | Larger instance for headroom |
| **LXC Compose** | ~$20-40 | t3.small/medium | None - everything included |

### Perfect Use Cases

✅ **LXC Compose excels when you need:**
- Single-server deployments with multiple services
- Cost-effective hosting for multiple projects
- Development and staging environments
- Self-hosted applications (GitLab, Nextcloud, etc.)
- Agency hosting for client applications
- Side projects and personal infrastructure

❌ **Consider alternatives when you need:**
- Multi-region deployment
- Automatic horizontal scaling
- Kubernetes-specific features (operators, CRDs)
- Serverless/FaaS architecture
- Multi-cloud portability

### Migration Path

Already using Docker Compose? Migration takes less than an hour:

```yaml
# Docker Compose → LXC Compose
image: node:18        → template: ubuntu-minimal + packages: [nodejs]
ports: "3000:3000"    → exposed_ports: [3000]
volumes: ./app:/app   → mounts: ["./app:/app"]
environment: KEY=val  → .env file with KEY=val
command: npm start    → services: {app: {command: "npm start"}}
```

[Complete migration guide →](docker-compose-migration.md)

## What is LXC Compose?

LXC Compose is a minimalist container orchestration tool that:
- Uses familiar Docker Compose-like YAML syntax
- Manages LXC system containers instead of Docker application containers
- Provides simple commands (`up`, `down`, `list`, `destroy`)
- Handles networking and port forwarding automatically
- Focuses on simplicity and security

## Key Features

### 🚀 Simple & Lightweight
- Only 4 core commands needed
- Single Python file implementation
- No daemon or background service
- Direct LXC command execution

### 🔒 Security-First
- Default-deny networking with explicit port exposure
- iptables-based port forwarding
- Container isolation by default
- No unnecessary attack surface

### 📦 Flexible Containers
- Alpine Linux (~150MB) for databases and services
- Ubuntu Minimal (~300MB) for applications
- Full Ubuntu for development environments
- Dynamic service configuration via YAML

### 🌐 Smart Networking
- Automatic container networking via shared hosts file
- Selective port exposure with iptables DNAT rules
- Container name-based communication
- Bridge network with IP tracking

### 🔄 Container Resilience
- **Automatic service recovery** after container restarts
- Supervisor auto-start on boot (systemd/OpenRC)
- No manual intervention needed for service restoration
- Works with all base images automatically

## Quick Start

### Installation

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash

# Or clone and install
git clone https://github.com/unomena/lxc-compose.git
cd lxc-compose
sudo ./install.sh
```

### Your First Application

1. **Create a configuration file** (`lxc-compose.yml`):

```yaml
version: "1.0"

containers:
  myapp:
    template: ubuntu-minimal
    release: lts
    packages:
      - python3
      - python3-pip
    exposed_ports:
      - 8000
    mounts:
      - .:/app
    post_install:
      - name: "Install dependencies"
        command: |
          cd /app
          pip3 install -r requirements.txt
```

2. **Start your application**:

```bash
lxc-compose up
```

3. **Check status**:

```bash
lxc-compose list
```

4. **Stop when done**:

```bash
lxc-compose down
```

## Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `up` | Create and start containers | `lxc-compose up` |
| `down` | Stop containers | `lxc-compose down` |
| `list` | Show container status | `lxc-compose list` |
| `destroy` | Remove containers | `lxc-compose destroy` |
| `logs` | View container logs | `lxc-compose logs myapp` |
| `test` | Run health checks | `lxc-compose test` |

## Sample Applications

Ready-to-use examples in `~/lxc-samples/`:

- **django-celery-app** - Full Django stack with Celery, PostgreSQL, and Redis
- **django-minimal** - Simple Django with PostgreSQL (~150MB total)
- **flask-app** - Flask with Redis caching
- **nodejs-app** - Express.js with MongoDB
- **searxng-app** - Privacy-respecting search engine

Try one:
```bash
cd ~/lxc-samples/django-minimal
lxc-compose up
```

## Documentation

### Essential Guides
- [Configuration Reference](configuration.md) - Complete YAML syntax and options
- [Commands Reference](commands.md) - Detailed command documentation
- [Getting Started](getting-started.md) - Step-by-step tutorial

### Advanced Topics
- [Networking Guide](networking.md) - Port forwarding and security
- [Testing Guide](testing.md) - Writing and running tests
- [Standards Guide](standards.md) - Best practices and conventions

### Migration & Troubleshooting
- [Docker Compose Migration](docker-compose-migration.md) - Migrate from Docker
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

## System Requirements

- **OS**: Ubuntu 22.04/24.04 LTS
- **Dependencies**: LXD/LXC, Python 3.8+, iptables
- **Privileges**: Root/sudo for container operations
- **Network**: Bridge network (lxdbr0)

## Architecture

LXC Compose operates as a thin orchestration layer over LXC:

```
YAML Config → Python CLI → LXC Commands → Containers
     ↓             ↓             ↓
   .env      iptables rules   Supervisor
  variables   port forward    services
```

Key design principles:
- **Stateless**: No database, derives state from LXC
- **Direct**: No daemon, direct LXC command execution
- **Secure**: Default-deny networking, explicit exposure
- **Simple**: Minimal commands, clear configuration

## Why LXC Compose?

### vs Docker Compose
- **System containers**: Full init system, multiple services per container
- **Lighter**: No Docker daemon overhead
- **Persistent**: Containers are stateful by default
- **Simpler**: Only essential features, no bloat

### vs Kubernetes
- **Minimal complexity**: No clusters, operators, or CRDs
- **Single-node**: Designed for single server deployments
- **Quick setup**: Install and run in minutes
- **Low overhead**: Direct LXC, no orchestration layer

### vs LXD directly
- **Declarative config**: Define infrastructure as code
- **Multi-container apps**: Manage related containers together
- **Simplified networking**: Automatic port forwarding
- **Service management**: Built-in supervisor integration

## Getting Help

- **Documentation**: This guide and linked references
- **Issues**: [GitHub Issues](https://github.com/unomena/lxc-compose/issues)
- **Source**: [GitHub Repository](https://github.com/unomena/lxc-compose)

## License

MIT License - See [LICENSE](https://github.com/unomena/lxc-compose/blob/main/LICENSE) for details.