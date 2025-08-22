# Configuration Reference

Complete reference for `lxc-compose.yml` configuration files.

> **New!** See [Templates and Library Services](templates-and-library.md) for information about template inheritance and using pre-configured services from the library.

## Table of Contents

- [Basic Structure](#basic-structure)
- [Container Configuration](#container-configuration)
- [Templates and Library Services](#templates-and-library-services)
- [Package Management](#package-management)
- [Mount Configuration](#mount-configuration)
- [Network Configuration](#network-configuration)
- [Service Definitions](#service-definitions)
- [Post-Install Commands](#post-install-commands)
- [Environment Variables](#environment-variables)
- [Container Dependencies](#container-dependencies)
- [Test Configuration](#test-configuration)
- [Log Configuration](#log-configuration)
- [Complete Example](#complete-example)

## Basic Structure

```yaml
version: "1.0"  # Required version string

containers:     # Container definitions
  container-name:
    # Container configuration
```

## Container Configuration

### Complete Container Options

```yaml
containers:
  container-name:
    # Base image configuration
    template: ubuntu              # Required: Base template
    release: jammy               # Required: Release version
    
    # Package management
    packages:                    # Optional: Packages to install
      - package1
      - package2
    
    # Networking
    exposed_ports:               # Optional: Ports accessible from host
      - 80
      - 443
    
    # File system
    mounts:                      # Optional: Directory/file mounts
      - source:target
      - ./local:/container
    
    # Dependencies
    depends_on:                  # Optional: Container dependencies
      - other-container
    
    # Services (Supervisor)
    services:                    # Optional: Service definitions
      service-name:
        command: /path/to/command
        # ... service options
    
    # Initialization
    post_install:                # Optional: Post-install commands
      - name: "Step name"
        command: |
          command to run
    
    # Logging
    logs:                        # Optional: Log definitions
      - name:/path/to/log
    
    # Testing
    tests:                       # Optional: Test configurations
      internal:
        - type:/path/to/test.sh
      external:
        - type:/path/to/test.sh
      port_forwarding:
        - type:/path/to/test.sh
```

## Templates and Library Services

### Quick Overview

LXC Compose now supports template inheritance and library services:

```yaml
containers:
  myapp:
    template: alpine-3.19        # Base OS template
    includes:                    # Include pre-configured services
      - postgresql
      - redis
    packages:                    # Additional packages
      - python3
    # ... rest of your config
```

### Available Templates

| Template | Alias | Base Size | Package Manager | Use Cases |
|----------|-------|-----------|-----------------|-----------|
| `alpine-3.19` | `alpine-latest` | ~150MB | apk | Minimal services, databases |
| `ubuntu-24.04` | `ubuntu-lts` | ~500MB | apt | Full environment |
| `ubuntu-22.04` | `ubuntu-jammy` | ~500MB | apt | Stable Ubuntu LTS |
| `ubuntu-minimal-24.04` | - | ~300MB | apt | Balanced size |
| `ubuntu-minimal-22.04` | - | ~300MB | apt | Lightweight Ubuntu |
| `debian-12` | `debian-bookworm` | ~450MB | apt | Stable Debian |
| `debian-11` | `debian-bullseye` | ~450MB | apt | Old stable |

### Library Services

Pre-configured services available for all base templates:
- **Databases**: PostgreSQL, MySQL, MongoDB
- **Caching**: Redis, Memcached  
- **Web**: Nginx, HAProxy
- **Messaging**: RabbitMQ
- **Search**: Elasticsearch
- **Monitoring**: Grafana, Prometheus

> **See [Templates and Library Services Guide](templates-and-library.md)** for complete documentation on template inheritance and building composite containers.

### Basic Template Usage

```yaml
# Minimal template only
template: alpine
release: "3.19"

# Ubuntu Minimal - for applications
template: ubuntu-minimal
release: lts

# Ubuntu Full - for development
template: ubuntu
release: jammy
```

## Package Management

Packages are installed based on the container's package manager:

```yaml
packages:
  # Alpine uses apk
  - postgresql
  - redis
  
  # Ubuntu uses apt
  - python3
  - python3-pip
  - nginx
```

## Mount Configuration

### Mount Formats

```yaml
# String format
mounts:
  - "./src:/app"
  - "/host/path:/container/path"

# Object format
mounts:
  - source: ./src
    target: /app
```

## Network Configuration

### Exposed Ports

Only exposed ports are accessible from the host:

```yaml
exposed_ports:
  - 80     # HTTP
  - 443    # HTTPS
  - 8080   # Alternative HTTP
```

## Service Definitions

Services are managed by Supervisor and automatically configured for container resilience:

### Container Resilience (Auto-start)

**🎉 New Feature**: Services automatically restart when containers are stopped and started!

When you define services in your configuration, LXC Compose automatically:
- Configures Supervisor to start at boot
- Detects your init system (systemd for Ubuntu/Debian, OpenRC for Alpine)
- Enables the appropriate service manager
- Ensures all services resume after container restarts

No configuration changes needed - this happens automatically for all containers with `services:` defined.

### Service Configuration

```yaml
services:
  web:
    command: /app/venv/bin/python app.py
    directory: /app
    user: www-data
    autostart: true
    autorestart: true
    stdout_logfile: /var/log/app.log
    stderr_logfile: /var/log/app_error.log
```

### How It Works

1. **Container Creation**: When services are defined, Supervisor is installed and configured
2. **Auto-start Setup**: LXC Compose enables Supervisor in the init system:
   - Alpine: `rc-update add supervisord default`
   - Ubuntu/Debian: `systemctl enable supervisor`
3. **Container Restart**: Services automatically resume without manual intervention

### Testing Resilience

```bash
# Create container with services
lxc-compose up -f lxc-compose.yml

# Stop and restart container
lxc stop <container-name>
lxc start <container-name>

# Verify services are running
lxc exec <container-name> -- supervisorctl status
```

## Post-Install Commands

Commands run after container creation:

```yaml
post_install:
  - name: "Setup database"
    command: |
      createdb myapp
      createuser myuser
  
  - name: "Install dependencies"
    command: |
      cd /app
      pip install -r requirements.txt
```

## Environment Variables

### Using .env Files

Create `.env` file in project root:

```env
DB_HOST=myapp-database
DB_PORT=5432
DB_NAME=myapp
DB_USER=appuser
DB_PASSWORD=secure_password
```

### Variable Expansion

```yaml
mounts:
  - ${DATA_DIR:-./data}:/var/lib/data

post_install:
  - name: "Create database"
    command: |
      createdb ${DB_NAME}
```

## Container Dependencies

```yaml
containers:
  database:
    template: alpine
    release: "3.19"
  
  app:
    template: ubuntu-minimal
    release: lts
    depends_on:
      - database  # Start after database
```

## Test Configuration

```yaml
tests:
  internal:           # Tests run inside container
    - health:/app/tests/internal_test.sh
  
  external:          # Tests run from host
    - connectivity:/app/tests/external_test.sh
  
  port_forwarding:   # iptables verification
    - security:/app/tests/port_test.sh
```

## Log Configuration

```yaml
logs:
  - app:/var/log/app.log
  - nginx:/var/log/nginx/access.log
  - error:/var/log/app/error.log
```

## Complete Example

### Modern Approach: Single Container with Library Services

```yaml
version: "1.0"

containers:
  # All-in-one container using library services
  myapp:
    # Use lightweight Ubuntu base
    template: ubuntu-minimal-24.04
    
    # Include pre-configured services from library
    includes:
      - postgresql  # Full PostgreSQL setup
      - redis       # Redis cache
      - nginx       # Web server
    
    # Add application-specific packages
    packages:
      - python3
      - python3-pip
      - python3-venv
    
    # Expose application port (library services ports are inherited)
    exposed_ports:
      - 8000  # Gunicorn
    
    # Mount application code
    mounts:
      - ./app:/app
      - ./data:/var/lib/postgresql/data
    
    # Define application service
    services:
      webapp:
        command: /app/venv/bin/gunicorn app:application --bind 0.0.0.0:8000
        directory: /app
        user: www-data
        autostart: true
        autorestart: true
        stdout_logfile: /var/log/webapp.log
        environment:
          DATABASE_URL: postgresql://localhost/myapp
          REDIS_URL: redis://localhost:6379
    
    # Application logs (library service logs are inherited)
    logs:
      - webapp:/var/log/webapp.log
    
    # Application tests (library service tests are inherited)
    tests:
      external:
        - api:/app/tests/test_api.sh
    
    # Application setup
    post_install:
      - name: "Setup Python environment"
        command: |
          cd /app
          python3 -m venv venv
          ./venv/bin/pip install -r requirements.txt
      
      - name: "Initialize database"
        command: |
          su - postgres -c "createdb myapp"
          su - postgres -c "psql myapp -c 'CREATE EXTENSION IF NOT EXISTS pg_trgm;'"
      
      - name: "Configure Nginx"
        command: |
          cat > /etc/nginx/sites-enabled/default << EOF
          server {
            listen 80;
            location / {
              proxy_pass http://localhost:8000;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
            }
          }
          EOF
          nginx -s reload
```

### Traditional Approach: Multiple Containers

```yaml
version: "1.0"

containers:
  # Database container
  myapp-db:
    template: alpine-3.19
    packages:
      - postgresql15
      - postgresql15-client
    exposed_ports:
      - 5432
    mounts:
      - ./data:/var/lib/postgresql/data
    post_install:
      - name: "Setup PostgreSQL"
        command: |
          mkdir -p /run/postgresql
          chown postgres:postgres /run/postgresql
          su - postgres -c "initdb -D /var/lib/postgresql/data"
          su - postgres -c "pg_ctl start -D /var/lib/postgresql/data"
          su - postgres -c "createdb myapp"

  # Application container
  myapp-web:
    template: ubuntu-minimal-24.04
    depends_on:
      - myapp-db
    packages:
      - python3
      - python3-pip
      - nginx
    exposed_ports:
      - 80
      - 443
    mounts:
      - .:/app
    services:
      app:
        command: /app/venv/bin/gunicorn app:application
        directory: /app
        user: www-data
        autostart: true
        autorestart: true
        stdout_logfile: /var/log/app.log
    logs:
      - app:/var/log/app.log
      - nginx:/var/log/nginx/access.log
    tests:
      internal:
        - health:/app/tests/health.sh
    post_install:
      - name: "Setup Python environment"
        command: |
          cd /app
          python3 -m venv venv
          ./venv/bin/pip install -r requirements.txt
```

## See Also

- [Commands Reference](commands.md)
- [Testing Guide](testing.md)
- [Networking Guide](networking.md)
- [Standards Guide](standards.md)