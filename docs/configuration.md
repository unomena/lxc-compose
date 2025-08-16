# Configuration Reference

Complete reference for LXC Compose configuration files.

## Table of Contents
- [File Structure](#file-structure)
- [Container Configuration](#containers)
- [Networking](#networking)
- [Port Forwarding](#port-forwarding)
- [Dependencies](#dependencies)
- [Mounts](#mounts)
- [Services](#services)
- [Environment Variables](#environment-variables)
- [Complete Example](#complete-example)

## File Structure

LXC Compose uses YAML configuration files, typically named `lxc-compose.yml`.

### Basic Structure

```yaml
version: '1.0'  # Configuration version

containers:     # Container definitions
  container-name:
    # Container configuration
```

### File Locations

LXC Compose looks for configuration files in this order:
1. File specified with `-f` flag
2. `lxc-compose.yml` in current directory
3. `lxc-compose.yaml` in current directory

## Container Configuration {#containers}

Each container is defined under the `containers` key with its name as the key.

### Basic Container

```yaml
containers:
  myapp-web:
    template: ubuntu       # Distribution template
    release: jammy        # Release version
```

### Container Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `template` | string | Distribution template (ubuntu, debian, alpine) | ubuntu |
| `release` | string | Release version (jammy, focal, bullseye) | jammy |
| `depends_on` | list | Container dependencies | [] |
| `ports` | list | Port forwarding rules | [] |
| `mounts` | list | Directory mounts | [] |
| `packages` | list | Packages to install | [] |
| `environment` | dict | Environment variables | {} |
| `services` | dict | Service configurations | {} |
| `post_install` | list | Post-installation commands | [] |

### Template Options

Available templates:
- `ubuntu` - Ubuntu Linux
- `debian` - Debian Linux
- `alpine` - Alpine Linux
- `centos` - CentOS Linux
- `fedora` - Fedora Linux

### Release Versions

Ubuntu releases:
- `jammy` - 22.04 LTS
- `focal` - 20.04 LTS
- `bionic` - 18.04 LTS

Debian releases:
- `bookworm` - 12
- `bullseye` - 11
- `buster` - 10

## Networking

### IP Allocation

LXC Compose automatically allocates IP addresses:
- Network: `10.0.3.0/24`
- Gateway: `10.0.3.1`
- Reserved: `10.0.3.1` - `10.0.3.10`
- Containers: `10.0.3.11` onwards

### Hostname Resolution

Container names are automatically added to `/etc/hosts`:
```
10.0.3.11    myapp-db
10.0.3.12    myapp-cache
10.0.3.13    myapp-web
```

### Container Naming Rules

- **Must be globally unique** across the entire system
- **No aliases allowed** - only exact container names
- Use project namespaces to avoid conflicts
- Valid characters: lowercase letters, numbers, hyphens

Good naming examples:
```yaml
containers:
  myproject-db:        # Project namespace
  myproject-cache:     # Clear service identification
  myproject-worker-1:  # Numbered instances
  com-example-api:     # Reverse domain notation
```

## Port Forwarding

Port forwarding uses Docker-like syntax within container configuration.

### Basic Syntax

```yaml
containers:
  myapp-web:
    ports:
      - 8080:80    # host:container
```

### Multiple Ports

```yaml
containers:
  myapp-services:
    ports:
      - 80:80      # HTTP
      - 443:443    # HTTPS
      - 3306:3306  # MySQL
```

### Port Examples with Comments

```yaml
ports:
  - 8080:80    # Nginx web server
  - 8000:8000  # Django development server
  - 5432:5432  # PostgreSQL database
```

## Dependencies

Dependencies ensure containers start in the correct order.

### Simple Dependencies

```yaml
containers:
  myapp-db:
    # No dependencies, starts first
    
  myapp-web:
    depends_on:
      - myapp-db  # Starts after myapp-db
```

### Multiple Dependencies

```yaml
containers:
  myapp-web:
    depends_on:
      - myapp-db
      - myapp-cache
      - myapp-queue
```

### Dependency Chain

```yaml
containers:
  myapp-db:        # Starts 1st
  
  myapp-cache:     # Starts 2nd
    depends_on:
      - myapp-db
      
  myapp-api:       # Starts 3rd
    depends_on:
      - myapp-db
      - myapp-cache
      
  myapp-web:       # Starts 4th
    depends_on:
      - myapp-api
```

## Mounts

Mount host directories into containers using Docker-like syntax.

### Basic Mounts

```yaml
containers:
  myapp-web:
    mounts:
      - .:/app           # Current directory to /app
      - ./data:/data     # Relative path
      - /var/log:/logs   # Absolute path
```

### Mount Syntax

```yaml
mounts:
  - host_path:container_path
```

- **Relative paths** are resolved from the configuration file location
- **Absolute paths** must start with `/`
- **Current directory** can be specified as `.`

### Mount Examples

```yaml
mounts:
  # Development
  - .:/app                          # Code directory
  - ./config:/etc/myapp             # Configuration
  - ./logs:/var/log/myapp           # Logs
  
  # Production
  - /srv/apps/myapp:/app            # Application code
  - /srv/data/myapp:/data           # Persistent data
  - /etc/myapp:/etc/myapp           # System config
```

## Services

Define services to run within containers using Supervisor.

### Service Configuration

```yaml
containers:
  myapp-web:
    services:
      web:
        command: python3 /app/server.py
        directory: /app
        autostart: true
        autorestart: true
        user: www-data
        stdout_logfile: /var/log/web.log
        stderr_logfile: /var/log/web_err.log
```

### Service Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `command` | string | Command to execute | required |
| `directory` | string | Working directory | / |
| `autostart` | bool | Start automatically | true |
| `autorestart` | bool | Restart on failure | true |
| `user` | string | User to run as | root |
| `stdout_logfile` | string | Stdout log file | /var/log/supervisor/%(program_name)s.log |
| `stderr_logfile` | string | Stderr log file | /var/log/supervisor/%(program_name)s_err.log |

### System Services

For system services (systemd), use type `system`:

```yaml
services:
  nginx:
    type: system
    config: |
      cat > /etc/nginx/sites-available/app <<EOF
      server {
          listen 80;
          location / {
              proxy_pass http://127.0.0.1:8000;
          }
      }
      EOF
      ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/
      systemctl restart nginx
```

## Environment Variables

Set environment variables for containers.

### Basic Variables

```yaml
containers:
  myapp-web:
    environment:
      DEBUG: "true"
      PORT: "3000"
      DATABASE_URL: "postgresql://user:pass@myapp-db:5432/db"
```

### Variable Types

```yaml
environment:
  # Strings
  APP_NAME: "MyApp"
  
  # Numbers (as strings)
  PORT: "3000"
  MAX_WORKERS: "4"
  
  # Booleans (as strings)
  DEBUG: "true"
  PRODUCTION: "false"
  
  # URLs and connections
  DATABASE_URL: "postgresql://user:pass@host:5432/db"
  REDIS_URL: "redis://myapp-cache:6379/0"
```

### Using Container Names

Reference other containers by their exact names:

```yaml
environment:
  DATABASE_HOST: myapp-db       # Container name
  CACHE_HOST: myapp-cache       # Container name
  API_URL: http://myapp-api:3000
```

## Packages

Install packages when creating containers.

### Package Installation

```yaml
containers:
  myapp-web:
    packages:
      - python3
      - python3-pip
      - nginx
      - postgresql-client
```

### Common Package Sets

```yaml
# Web server
packages:
  - nginx
  - apache2
  - nodejs
  - npm

# Database
packages:
  - postgresql
  - postgresql-contrib
  - mysql-server
  - redis-server

# Development tools
packages:
  - git
  - build-essential
  - python3-dev
  - curl
  - wget
```

## Post-Installation Commands

Run commands after container creation.

### Basic Commands

```yaml
containers:
  myapp-web:
    post_install:
      - name: "Create directories"
        command: |
          mkdir -p /app/logs
          mkdir -p /app/data
          
      - name: "Set permissions"
        command: |
          chown -R www-data:www-data /app
          chmod 755 /app
```

### Complex Setup

```yaml
post_install:
  - name: "Install Python dependencies"
    command: |
      cd /app
      python3 -m venv venv
      source venv/bin/activate
      pip install -r requirements.txt
      
  - name: "Initialize database"
    command: |
      cd /app
      source venv/bin/activate
      python manage.py migrate
      python manage.py collectstatic --noinput
      
  - name: "Create admin user"
    command: |
      cd /app
      source venv/bin/activate
      echo "from django.contrib.auth import get_user_model; \
            User = get_user_model(); \
            User.objects.create_superuser('admin', 'admin@example.com', 'admin123')" \
            | python manage.py shell
```

## Complete Example

Here's a complete example configuration for a web application:

```yaml
version: '1.0'

containers:
  # PostgreSQL Database
  myapp-db:
    template: ubuntu
    release: jammy
    
    ports:
      - 5432:5432
    
    packages:
      - postgresql
      - postgresql-contrib
    
    environment:
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: secret123
      POSTGRES_DB: myapp_production
    
    services:
      postgresql:
        type: system
        config: |
          # Configure PostgreSQL
          sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" \
            /etc/postgresql/14/main/postgresql.conf
          echo 'host all all 10.0.3.0/24 md5' >> /etc/postgresql/14/main/pg_hba.conf
          systemctl restart postgresql
          
          # Create database and user
          sudo -u postgres psql <<EOF
          CREATE USER myapp WITH PASSWORD 'secret123';
          CREATE DATABASE myapp_production OWNER myapp;
          GRANT ALL PRIVILEGES ON DATABASE myapp_production TO myapp;
          EOF

  # Redis Cache
  myapp-cache:
    template: ubuntu
    release: jammy
    
    ports:
      - 6379:6379
    
    packages:
      - redis-server
    
    services:
      redis:
        type: system
        config: |
          sed -i 's/bind 127.0.0.1/bind 0.0.0.0/g' /etc/redis/redis.conf
          sed -i 's/protected-mode yes/protected-mode no/g' /etc/redis/redis.conf
          systemctl restart redis-server

  # Web Application
  myapp-web:
    template: ubuntu
    release: jammy
    
    depends_on:
      - myapp-db
      - myapp-cache
    
    ports:
      - 80:80      # Nginx
      - 8000:8000  # App server
    
    mounts:
      - .:/app
      - ./logs:/var/log/myapp
    
    packages:
      - python3
      - python3-pip
      - python3-venv
      - nginx
      - supervisor
      - git
      - build-essential
      - libpq-dev
    
    environment:
      DJANGO_SETTINGS_MODULE: config.settings.production
      DATABASE_URL: postgresql://myapp:secret123@myapp-db:5432/myapp_production
      REDIS_URL: redis://myapp-cache:6379/0
      SECRET_KEY: "your-secret-key-here"
      DEBUG: "false"
      ALLOWED_HOSTS: "*"
    
    services:
      django:
        command: /app/venv/bin/gunicorn config.wsgi:application --bind 0.0.0.0:8000
        directory: /app
        autostart: true
        autorestart: true
        user: www-data
        stdout_logfile: /var/log/myapp/django.log
        stderr_logfile: /var/log/myapp/django_err.log
      
      celery:
        command: /app/venv/bin/celery -A config worker -l info
        directory: /app
        autostart: true
        autorestart: true
        user: www-data
        stdout_logfile: /var/log/myapp/celery.log
        stderr_logfile: /var/log/myapp/celery_err.log
      
      nginx:
        type: system
        config: |
          cat > /etc/nginx/sites-available/myapp <<EOF
          server {
              listen 80;
              server_name _;
              
              location /static/ {
                  alias /app/static/;
              }
              
              location /media/ {
                  alias /app/media/;
              }
              
              location / {
                  proxy_pass http://127.0.0.1:8000;
                  proxy_set_header Host \$host;
                  proxy_set_header X-Real-IP \$remote_addr;
              }
          }
          EOF
          ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
          rm -f /etc/nginx/sites-enabled/default
          systemctl restart nginx
    
    post_install:
      - name: "Setup Python environment"
        command: |
          cd /app
          python3 -m venv venv
          source venv/bin/activate
          pip install --upgrade pip
          pip install -r requirements.txt
      
      - name: "Run migrations"
        command: |
          cd /app
          source venv/bin/activate
          python manage.py migrate
          python manage.py collectstatic --noinput
      
      - name: "Set permissions"
        command: |
          chown -R www-data:www-data /app
          chmod -R 755 /app
```

## Best Practices

1. **Always use project namespaces** for container names
2. **Define dependencies explicitly** to ensure correct startup order
3. **Use environment variables** for configuration
4. **Mount code directories** for development
5. **Log to persistent volumes** for debugging
6. **Set appropriate user permissions** for services
7. **Use post_install for one-time setup** tasks