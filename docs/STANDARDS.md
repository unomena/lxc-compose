# LXC Compose Project Configuration Standards

This document defines the configuration standards for LXC Compose projects, based on the reference implementation in `samples/django-celery-app`.

## Project Structure

```
project/
├── lxc-compose.yml          # Main configuration file
├── .env                     # Environment variables
├── requirements.txt         # Python dependencies (for Python projects)
├── package.json            # Node dependencies (for Node projects)
├── config/                 # Configuration files
│   ├── sample-{container}/ # Per-container config directories
│   │   ├── supervisord.conf # Supervisor base config (if needed)
│   │   ├── nginx.conf      # Nginx config (if needed)
│   │   └── redis.conf      # Redis config (if needed)
├── src/                    # Application source code
└── README.md              # Project documentation
```

## Container Configuration Standards

### 1. Container Naming
- Use descriptive prefixes: `sample-` for examples, or project-specific prefixes
- Multi-container apps should have clear role-based names:
  - `{prefix}-datastore` for database/cache containers
  - `{prefix}-app` for main application containers
  - `{prefix}-worker` for background job containers

### 2. Base Images
- **Alpine Linux** (`alpine:3.19`) for lightweight containers with:
  - PostgreSQL, Redis, or other system services
  - Smallest footprint requirements (~150MB)
- **Ubuntu Minimal** (`ubuntu-minimal:lts`) for:
  - Python/Node applications requiring Ubuntu compatibility
  - Smaller footprint than full Ubuntu (~300MB)
  - Good balance between size and compatibility
- **Ubuntu** (`ubuntu:lts`) for:
  - Complex applications needing full Ubuntu environment
  - When all standard Ubuntu packages are needed
  - Development environments that mirror production

### 3. Services Configuration
Services should be defined inline in `lxc-compose.yml` using the `services:` section:

```yaml
services:
  service-name:
    command: /path/to/command
    directory: /working/directory
    user: username
    autostart: true
    autorestart: true
    stdout_logfile: /var/log/service.log
    stderr_logfile: /var/log/service_err.log
    startsecs: 10
    stopwaitsecs: 600
```

**Important**: System services (PostgreSQL, Redis) should NOT be managed by Supervisor. They should run as daemons.

### 4. Package Management
Always specify exact packages needed:
```yaml
packages:
  # For Python apps
  - python3
  - python3-pip
  - python3-venv
  - python3-dev
  - build-essential
  
  # For database connectivity
  - postgresql-client
  - libpq-dev
  
  # For web apps
  - nginx
  - curl
  
  # For process management (only for app containers)
  - supervisor
```

### 5. Environment Variables
- Use `.env` file for all configuration
- Never hardcode credentials or settings
- Standard variables:
  ```env
  # Debug/Environment
  DEBUG=True
  
  # Database
  DB_NAME=dbname
  DB_USER=dbuser
  DB_PASSWORD=dbpass
  DB_HOST=sample-datastore
  DB_PORT=5432
  
  # Cache
  REDIS_HOST=sample-datastore
  REDIS_PORT=6379
  
  # Admin
  ADMIN_USER=admin
  ADMIN_EMAIL=admin@example.com
  ADMIN_PASSWORD=admin123
  ```

### 6. Mounts Configuration
Keep mounts minimal and purposeful:
```yaml
mounts:
  - .:/app                    # Application code
  - ./config/sample-{container}/supervisord.conf:/etc/supervisord.conf
  - ./config/sample-{container}/nginx.conf:/etc/nginx/sites-available/app
  - ./config/sample-{container}/redis.conf:/etc/redis.conf
```

### 7. Post-Install Commands
Structure post-install commands logically:

1. **Setup system services** (PostgreSQL, Redis)
   - Create directories with proper ownership
   - Initialize databases
   - Start as daemons

2. **Setup application environment**
   - Create Python virtual environment
   - Install dependencies
   - Create required directories

3. **Database operations**
   - Wait for database readiness
   - Run migrations
   - Create initial data

4. **Web server setup** (if needed)
   - Configure nginx
   - Remove default sites
   - Start service

5. **Start application services**
   - Start supervisor (for app processes only)
   - Verify services are running

### 8. Health Checks
Always include health checks for service dependencies:

```yaml
post_install:
  - name: "Wait for database"
    command: |
      for i in $(seq 1 30); do
        if PGPASSWORD=${DB_PASSWORD} psql -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} -c "SELECT 1" > /dev/null 2>&1; then
          echo "Database is ready!"
          break
        fi
        echo "Waiting for database... (attempt $i/30)"
        sleep 2
      done
```

### 9. Exposed Ports
Only expose necessary ports:
```yaml
exposed_ports:
  - 80    # Nginx (for web apps)
  - 5432  # PostgreSQL (only if external access needed)
  - 6379  # Redis (only if external access needed)
```

**Note**: Don't expose application ports (like 8000 for Django) if nginx is proxying.

### 10. Dependencies
Use `depends_on` for container dependencies:
```yaml
depends_on:
  - sample-datastore
```

## Python Project Standards

### Virtual Environment
Always use virtual environments:
```yaml
- name: "Setup Python environment"
  command: |
    cd /app
    python3 -m venv venv
    ./venv/bin/pip install --upgrade pip setuptools wheel
    ./venv/bin/pip install -r requirements.txt
```

### Running Python Commands
Use explicit venv paths:
```yaml
# Good
../venv/bin/python manage.py migrate

# Bad (relies on activation)
source venv/bin/activate && python manage.py migrate
```

## Service Management Standards

### Application Services (via Supervisor)
- Django/Flask applications
- Celery workers
- Celery beat schedulers
- Custom application daemons

### System Services (run directly)
- PostgreSQL (`pg_ctl`)
- Redis (`redis-server --daemonize yes`)
- Nginx (`service nginx start`)
- MongoDB (`mongod`)

## Configuration File Standards

### supervisord.conf
Basic supervisor configuration:
```ini
[unix_http_server]
file=/run/supervisord.sock

[supervisord]
logfile=/var/log/supervisord.log
loglevel=info
pidfile=/run/supervisord.pid
nodaemon=false

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///run/supervisord.sock

[include]
files = /etc/supervisor.d/*.ini
```

### nginx.conf
Standard proxy configuration:
```nginx
server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
    
    location /static/ {
        alias /app/static/;
        expires 30d;
    }
    
    location /media/ {
        alias /app/media/;
        expires 30d;
    }
}
```

### redis.conf
Standard Redis configuration:
```conf
bind 0.0.0.0
protected-mode no
port 6379
dir /var/lib/redis
logfile /var/log/redis/redis.log
pidfile /run/redis/redis.pid
daemonize no
```

## Best Practices

1. **Container Separation**: Separate datastores from application containers
2. **Minimal Images**: Use Alpine where possible, Ubuntu Minimal when needed
3. **Service Generation**: Define services in YAML, let LXC Compose generate configs
4. **Environment Variables**: All configuration through .env files
5. **Health Checks**: Always verify service availability before dependent operations
6. **Logging**: Consistent log file locations and rotation settings
7. **Security**: Never expose unnecessary ports or hardcode credentials
8. **Documentation**: Always include a README with setup and usage instructions