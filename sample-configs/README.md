# LXC Compose Sample Configurations

This directory contains example configurations for various deployment scenarios.

## Django Samples

### django-ubuntu-minimal.yml
- **Base Image**: ubuntu-minimal:22.04 (~100MB)
- **Components**: Django, PostgreSQL, Redis, Nginx
- **Use Case**: Lightweight Django development
- **Total Size**: ~300MB per container

### django-alpine.yml
- **Base Image**: alpine:3.18 (~8MB)
- **Components**: Django, PostgreSQL, Redis, Nginx
- **Use Case**: Ultra-minimal Django deployment
- **Total Size**: ~100MB per container
- **Note**: May have compatibility issues with some Python packages due to musl libc

### django-production.yml
- **Base Image**: ubuntu-minimal:22.04
- **Components**: Django, Gunicorn, Celery, PostgreSQL, Redis, Nginx
- **Use Case**: Production-ready Django with worker processes
- **Features**: Supervisor, log rotation, security settings

## Comparison Samples

### image-comparison.yml
- Demonstrates the same Flask app running on:
  - Alpine Linux (~60MB total)
  - Ubuntu Minimal (~150MB total)
  - Ubuntu Full (~450MB total)
- Great for understanding size/performance trade-offs

## Image Selection Guide

| Image | Base Size | Use Case | Package Manager | Notes |
|-------|-----------|----------|-----------------|-------|
| alpine:3.18 | ~8MB | Microservices, simple apps | apk | Smallest, may have compatibility issues |
| ubuntu-minimal:22.04 | ~100MB | Most applications | apt | Good balance of size and compatibility |
| ubuntu:22.04 | ~400MB | Complex apps, legacy code | apt | Everything included, largest |

## Quick Start

1. Choose a sample config:
```bash
cp sample-configs/django-ubuntu-minimal.yml lxc-compose.yml
```

2. Start the containers:
```bash
lxc-compose up
```

3. Check status:
```bash
lxc-compose list
```

## Tips

- **Alpine**: Use for Node.js, Go, or static binaries. Be cautious with Python due to musl libc.
- **Ubuntu Minimal**: Best default choice. Has apt but minimal packages.
- **Ubuntu Full**: Use when you need many system tools pre-installed.

## Container Sizing

Typical container sizes after package installation:

- **Nginx on Alpine**: ~15MB
- **Nginx on Ubuntu Minimal**: ~130MB
- **PostgreSQL on Alpine**: ~40MB
- **PostgreSQL on Ubuntu Minimal**: ~200MB
- **Django + deps on Alpine**: ~100MB
- **Django + deps on Ubuntu Minimal**: ~250MB

## Network Configuration

All samples use the 10.0.3.x subnet:
- 10.0.3.20-29: Database containers
- 10.0.3.30-39: Application containers
- 10.0.3.40-49: Production containers
- 10.0.3.50-59: Test containers

Adjust IPs if they conflict with your network.