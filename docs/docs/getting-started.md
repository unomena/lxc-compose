# Getting Started Tutorial

A step-by-step guide to building your first multi-container application with LXC Compose.

## Prerequisites

Before starting, ensure you have:
- Ubuntu 22.04 or 24.04 LTS
- sudo/root access
- Basic familiarity with YAML and command line

## Step 1: Installation

Install LXC Compose using the quick installer:

```bash
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash
```

Verify the installation:

```bash
lxc-compose list
```

You should see an empty container list.

## Step 2: Create a Simple Web Application

Let's build a Python Flask application with Redis caching.

### Create Project Directory

```bash
mkdir ~/my-flask-app
cd ~/my-flask-app
```

### Create the Flask Application

Create `app.py`:

```python
from flask import Flask
import redis
import os

app = Flask(__name__)
cache = redis.Redis(
    host=os.environ.get('REDIS_HOST', 'localhost'),
    port=6379,
    decode_responses=True
)

@app.route('/')
def hello():
    count = cache.incr('hits')
    return f'Hello! This page has been viewed {count} times.\n'

@app.route('/health')
def health():
    return 'OK\n'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

### Create Requirements File

Create `requirements.txt`:

```
flask==3.0.0
redis==5.0.1
gunicorn==21.2.0
```

### Create Environment Configuration

Create `.env`:

```env
REDIS_HOST=myapp-cache
FLASK_ENV=development
```

## Step 3: Define Container Configuration

You have two options for configuring your containers:

### Option A: Modern Approach with Library Services (Recommended)

Create `lxc-compose.yml`:

```yaml
version: "1.0"

containers:
  # Single container with all services
  myapp:
    template: ubuntu-minimal-24.04
    
    # Include pre-configured Redis from library
    includes:
      - redis
    
    # Add Python for our app
    packages:
      - python3
      - python3-pip
    
    # Expose Flask port
    exposed_ports:
      - 5000
    
    # Mount application code
    mounts:
      - .:/app
    
    # Define Flask service
    services:
      webapp:
        command: python3 /app/app.py
        directory: /app
        autostart: true
        autorestart: true
        stdout_logfile: /var/log/webapp.log
        environment:
          REDIS_HOST: localhost
          FLASK_ENV: development
    
    # Application logs (Redis logs inherited)
    logs:
      - webapp:/var/log/webapp.log
    
    # Setup
    post_install:
      - name: "Install Python dependencies"
        command: |
          cd /app
          pip3 install -r requirements.txt
```

### Option B: Traditional Multi-Container Approach

Create `lxc-compose.yml`:

```yaml
version: "1.0"

containers:
  # Redis cache container
  myapp-cache:
    template: alpine-3.19
    packages:
      - redis
    post_install:
      - name: "Start Redis"
        command: |
          redis-server --daemonize yes --bind 0.0.0.0

  # Flask application container
  myapp-web:
    template: ubuntu-minimal
    release: lts
    depends_on:
      - myapp-cache
    packages:
      - python3
      - python3-pip
      - python3-venv
    exposed_ports:
      - 5000
    mounts:
      - .:/app
    services:
      flask:
        command: /app/venv/bin/gunicorn -b 0.0.0.0:5000 app:app
        directory: /app
        autostart: true
        autorestart: true
        stdout_logfile: /var/log/flask.log
    logs:
      - flask:/var/log/flask.log
    post_install:
      - name: "Setup Python environment"
        command: |
          cd /app
          python3 -m venv venv
          ./venv/bin/pip install -r requirements.txt
```

## Step 4: Deploy the Application

### Start Containers

```bash
lxc-compose up
```

You'll see output showing:
- Container creation
- Package installation
- Service configuration
- Port forwarding setup

### Check Status

```bash
lxc-compose list
```

Output:
```
Container Status:
┌──────────────┬─────────┬────────────┬──────────────┐
│ Container    │ Status  │ IPv4       │ Exposed Ports│
├──────────────┼─────────┼────────────┼──────────────┤
│ myapp-cache  │ RUNNING │ 10.0.3.100 │              │
│ myapp-web    │ RUNNING │ 10.0.3.101 │ 5000         │
└──────────────┴─────────┴────────────┴──────────────┘
```

### Test the Application

```bash
# Test the application
curl http://localhost:5000
# Output: Hello! This page has been viewed 1 times.

curl http://localhost:5000
# Output: Hello! This page has been viewed 2 times.

# Check health endpoint
curl http://localhost:5000/health
# Output: OK
```

## Step 5: Manage the Application

### View Logs

```bash
# List available logs
lxc-compose logs myapp-web

# View Flask logs
lxc-compose logs myapp-web flask

# Follow logs in real-time
lxc-compose logs myapp-web flask --follow
```

### Access Container Shell

```bash
# Access the web container
lxc exec myapp-web -- /bin/bash

# Check Python environment
ls -la /app/venv/

# Exit container
exit
```

### Run Tests

Create `tests/health_check.sh`:

```bash
#!/bin/bash
# Simple health check
curl -f http://localhost:5000/health || exit 1
echo "Health check passed!"
```

Update `lxc-compose.yml` to add tests:

```yaml
containers:
  myapp-web:
    # ... existing configuration ...
    tests:
      external:
        - health:/app/tests/health_check.sh
```

Run tests:

```bash
lxc-compose test
```

## Step 6: Stop and Clean Up

### Stop Containers

```bash
lxc-compose down
```

Containers are stopped but not removed.

### Destroy Containers

```bash
lxc-compose destroy
```

This removes containers permanently.

## Next Steps

### Try Advanced Features

1. **Add a Database**: Extend the application with PostgreSQL
2. **Multiple Services**: Run multiple services in one container
3. **Production Setup**: Add Nginx reverse proxy
4. **CI/CD Integration**: Automate deployment

### Explore Sample Applications

```bash
# Django with Celery, PostgreSQL, and Redis
cd ~/lxc-samples/django-celery-app
lxc-compose up

# Minimal Django application
cd ~/lxc-samples/django-minimal
lxc-compose up
```

### Learn More

- [Configuration Reference](configuration.md) - All YAML options
- [Commands Reference](commands.md) - Detailed command usage
- [Testing Guide](testing.md) - Writing comprehensive tests
- [Networking Guide](networking.md) - Port forwarding details

## Troubleshooting

### Container Won't Start

Check LXD status:
```bash
lxc list
sudo systemctl status lxd
```

### Port Already in Use

Find what's using the port:
```bash
sudo lsof -i :5000
```

### Permission Denied

Ensure you're using sudo:
```bash
sudo lxc-compose up
```

### Can't Connect to Application

Check iptables rules:
```bash
sudo iptables -t nat -L PREROUTING -n | grep 5000
```

## Summary

You've learned how to:
- Install LXC Compose
- Create a multi-container application
- Define services and dependencies
- Deploy and manage containers
- View logs and run tests
- Clean up resources

LXC Compose makes container orchestration simple and secure. Continue exploring with the sample applications and documentation!