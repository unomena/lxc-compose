# LXC Compose Sample Projects

Ready-to-use sample projects demonstrating various deployment scenarios with LXC Compose.

## Available Samples

Each sample is in its own directory with a `lxc-compose.yml` file and README.

### 🎯 django-ubuntu-minimal
**Full-featured Django application with PostgreSQL and Redis**
- Two containers: datastore (PostgreSQL + Redis) and app server
- Ubuntu Minimal base (~100MB per container)
- Includes requirements.txt and auto-setup
- Perfect for Django development

```bash
cd django-ubuntu-minimal
lxc-compose up
# Access at http://localhost:8000
```

### 🏔️ django-alpine
**Ultra-lightweight Django setup using Alpine Linux**
- Alpine base (~8MB per container)
- Same Django + PostgreSQL + Redis stack
- ~75% smaller than Ubuntu version
- Note: May have Python package compatibility issues

```bash
cd django-alpine
lxc-compose up
# Access at http://localhost:8001
```

### 🚀 django-production
**Production-ready Django with Gunicorn, Celery, and Nginx**
- Complete production stack
- Supervisor for process management
- Separate containers for app and database
- Volume mounts for data persistence

```bash
cd django-production
lxc-compose up
# Access at http://localhost:80
```

### ⚡ flask-minimal
**Simple Flask application in Alpine**
- Single container (~60MB total)
- Auto-creates sample app if none exists
- Perfect for microservices
- Includes API endpoint examples

```bash
cd flask-minimal
lxc-compose up
# Access at http://localhost:5000
```

### 📊 image-comparison
**Compare the same app across different base images**
- Runs identical Flask app in:
  - Alpine (~60MB)
  - Ubuntu Minimal (~150MB)
  - Ubuntu Full (~450MB)
- Great for understanding size/performance tradeoffs

```bash
cd image-comparison
lxc-compose up
# Alpine: http://localhost:3000
# Ubuntu Minimal: http://localhost:3001
# Ubuntu Full: http://localhost:3002
```

## Quick Start

### During Installation

The installer will ask if you want to copy samples to `~/lxc-samples`:

```bash
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash
# Answer 'y' when asked about copying samples
```

### Manual Usage

Clone the repo and navigate to any sample:

```bash
git clone https://github.com/unomena/lxc-compose.git
cd lxc-compose/sample-configs/flask-minimal
lxc-compose up
```

## Project Structure

Each sample project contains:
- `lxc-compose.yml` - Container configuration
- `README.md` - Project-specific documentation
- Application files (where applicable)

```
sample-configs/
├── django-ubuntu-minimal/
│   ├── lxc-compose.yml
│   ├── requirements.txt
│   ├── manage.py
│   └── README.md
├── django-alpine/
│   └── lxc-compose.yml
├── django-production/
│   └── lxc-compose.yml
├── flask-minimal/
│   ├── lxc-compose.yml
│   └── README.md
└── image-comparison/
    └── lxc-compose.yml
```

## Customization

Each sample can be customized:
1. Copy the sample directory to your workspace
2. Modify the `lxc-compose.yml` as needed
3. Add your application code
4. Run `lxc-compose up`

## Image Size Comparison

| Sample | Base Image | Container Size | Use Case |
|--------|------------|----------------|----------|
| flask-minimal | Alpine 3.18 | ~60MB | Microservices |
| django-alpine | Alpine 3.18 | ~100MB | Lightweight Django |
| django-ubuntu-minimal | Ubuntu Minimal | ~300MB | Standard Django |
| django-production | Ubuntu Minimal | ~400MB | Production Django |
| image-comparison | Mixed | 60-450MB | Testing/Comparison |

## Network Configuration

Default IP ranges used by samples:
- `10.0.3.20-29`: Database containers
- `10.0.3.30-39`: Application containers  
- `10.0.3.40-49`: Production containers
- `10.0.3.50-59`: Test containers

Adjust IPs in `lxc-compose.yml` if they conflict with your network.

## Tips

- **Development**: Use `django-ubuntu-minimal` or `flask-minimal`
- **Production**: Use `django-production` as a starting point
- **Microservices**: Use Alpine-based samples for smallest footprint
- **Learning**: Use `image-comparison` to understand tradeoffs

## Troubleshooting

If a sample doesn't work:
1. Check port conflicts: `lxc-compose list`
2. Ensure IPs don't conflict: `ip addr show`
3. Check logs: `lxc exec <container-name> -- journalctl -f`
4. Destroy and recreate: `lxc-compose destroy && lxc-compose up`