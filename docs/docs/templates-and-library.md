# Templates and Library Services

Complete guide to using base templates, library services, and template inheritance to build composite containers.

## Table of Contents

- [Overview](#overview)
- [Base Templates](#base-templates)
- [Library Services](#library-services)
- [Template Inheritance](#template-inheritance)
- [Building Composite Containers](#building-composite-containers)
- [Service Composition Examples](#service-composition-examples)
- [Custom Service Extensions](#custom-service-extensions)
- [Migration from Docker Compose](#migration-from-docker-compose)

## Overview

LXC Compose uses a three-tier inheritance system for container configuration:

```
Base Template → Library Services → Custom Configuration
     ↓              ↓                    ↓
 OS + Network   Pre-configured      Your specific
               services (DB, etc)    application
```

This allows you to:
- Start with a minimal base OS
- Include pre-configured services from the library
- Add your custom application on top

## Base Templates

### Available Base Images

LXC Compose provides 7 base templates optimized for different use cases:

| Template | Alias | Base Size | Package Manager | Init System | Use Case |
|----------|-------|-----------|-----------------|-------------|----------|
| `alpine-3.19` | `alpine-latest` | ~150MB | apk | OpenRC | Minimal services, databases |
| `ubuntu-24.04` | `ubuntu-lts`, `ubuntu-noble` | ~500MB | apt | systemd | Full Ubuntu environment |
| `ubuntu-22.04` | `ubuntu-jammy` | ~500MB | apt | systemd | Stable Ubuntu LTS |
| `ubuntu-minimal-24.04` | `ubuntu-minimal-lts` | ~300MB | apt | manual | Balanced size/features |
| `ubuntu-minimal-22.04` | `ubuntu-minimal-jammy` | ~300MB | apt | manual | Lightweight Ubuntu |
| `debian-12` | `debian-bookworm` | ~450MB | apt | systemd | Stable Debian |
| `debian-11` | `debian-bullseye` | ~450MB | apt | systemd | Old stable Debian |

### Template Selection Guide

```yaml
# For minimal footprint (databases, caches)
template: alpine-3.19

# For Python/Node.js applications
template: ubuntu-minimal-24.04

# For full development environment
template: ubuntu-24.04

# For maximum stability
template: debian-12
```

## Library Services

### Available Services

The library provides 77 pre-configured services (11 types × 7 base images):

#### Databases
- **PostgreSQL**: Full RDBMS with CRUD test suite
- **MySQL**: Compatible MySQL server with tests
- **MongoDB**: NoSQL document database

#### Caching
- **Redis**: In-memory data store
- **Memcached**: Distributed memory cache

#### Web Services
- **Nginx**: High-performance web server
- **HAProxy**: Load balancer and proxy

#### Message Queues
- **RabbitMQ**: AMQP message broker with management UI

#### Search & Analytics
- **Elasticsearch**: Full-text search engine

#### Monitoring
- **Grafana**: Visualization and dashboards
- **Prometheus**: Metrics collection and alerting

### Library Structure

```
library/
├── alpine/
│   └── 3.19/
│       ├── postgresql/
│       ├── redis/
│       ├── nginx/
│       └── ...
├── ubuntu/
│   ├── 24.04/
│   └── 22.04/
├── ubuntu-minimal/
│   ├── 24.04/
│   └── 22.04/
└── debian/
    ├── 12/
    └── 11/
```

## Template Inheritance

### How Inheritance Works

1. **Base Template**: Provides OS, networking, and core packages
2. **Library Includes**: Adds pre-configured services
3. **Custom Config**: Your application-specific configuration

### Basic Inheritance Example

```yaml
version: '1.0'
containers:
  myapp:
    # 1. Start with base template
    template: ubuntu-minimal-24.04
    
    # 2. Include library services
    includes:
      - postgresql  # Adds PostgreSQL with all configuration
      - redis       # Adds Redis cache
    
    # 3. Add custom configuration
    packages:
      - python3
      - python3-pip
    
    exposed_ports:
      - 8000  # Your app port
    
    mounts:
      - ./app:/app
    
    services:
      webapp:
        command: python3 /app/main.py
        directory: /app
```

### What Gets Inherited

When you include a library service:

✅ **Inherited automatically:**
- Package installations
- Service configurations
- Post-install scripts
- Test suites
- Log definitions
- Exposed ports

✅ **Can be extended:**
- Additional packages
- Extra services
- More exposed ports
- Custom mounts
- Additional tests

❌ **Cannot override:**
- Base template choice
- Core service configuration

## Building Composite Containers

### Multi-Service Application

```yaml
version: '1.0'
containers:
  api-server:
    template: alpine-3.19
    
    # Include multiple services
    includes:
      - postgresql
      - redis
      - nginx
    
    # Add your API server
    packages:
      - python3
      - py3-pip
    
    mounts:
      - ./api:/app
      - ./nginx-conf:/etc/nginx/conf.d
    
    services:
      api:
        command: python3 /app/server.py
        directory: /app
        environment:
          DATABASE_URL: postgresql://localhost/myapp
          REDIS_URL: redis://localhost:6379
    
    # Additional configuration for included services
    post_install:
      - name: "Configure Nginx for API"
        command: |
          cat > /etc/nginx/conf.d/api.conf << EOF
          server {
            listen 80;
            location / {
              proxy_pass http://localhost:8000;
            }
          }
          EOF
          nginx -s reload
```

### Development Environment

```yaml
version: '1.0'
containers:
  dev-env:
    template: ubuntu-24.04  # Full Ubuntu for development
    
    includes:
      - postgresql
      - redis
      - elasticsearch
    
    packages:
      - git
      - vim
      - build-essential
      - nodejs
      - npm
    
    mounts:
      - ./workspace:/workspace
      - ~/.ssh:/root/.ssh:ro
    
    exposed_ports:
      - 3000  # Node.js dev server
      - 5432  # PostgreSQL (inherited)
      - 6379  # Redis (inherited)
      - 9200  # Elasticsearch (inherited)
```

## Service Composition Examples

### WordPress-like Stack

```yaml
version: '1.0'
containers:
  wordpress:
    template: ubuntu-minimal-24.04
    
    includes:
      - mysql
      - nginx
      - redis  # For caching
    
    packages:
      - php8.1-fpm
      - php8.1-mysql
      - php8.1-redis
    
    mounts:
      - ./wordpress:/var/www/html
    
    post_install:
      - name: "Configure PHP-FPM"
        command: |
          sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php/8.1/fpm/php.ini
          systemctl restart php8.1-fpm
    
      - name: "Configure Nginx for WordPress"
        command: |
          cat > /etc/nginx/sites-available/wordpress << EOF
          server {
            listen 80;
            root /var/www/html;
            index index.php;
            
            location ~ \.php$ {
              include snippets/fastcgi-php.conf;
              fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
            }
          }
          EOF
          ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
          nginx -s reload
```

### Microservice with Monitoring

```yaml
version: '1.0'
containers:
  microservice:
    template: alpine-3.19  # Minimal footprint
    
    includes:
      - prometheus  # Metrics collection
      - grafana     # Visualization
    
    packages:
      - go
    
    mounts:
      - ./service:/app
    
    services:
      app:
        command: /app/bin/service
        directory: /app
    
    post_install:
      - name: "Configure Prometheus scraping"
        command: |
          cat >> /opt/prometheus/prometheus.yml << EOF
          
            - job_name: 'microservice'
              static_configs:
              - targets: ['localhost:8080']
          EOF
          pkill -HUP prometheus
```

## Custom Service Extensions

### Adding Custom Tests

When including library services, you can add your own tests:

```yaml
containers:
  myapp:
    template: ubuntu-minimal-24.04
    includes:
      - postgresql
    
    # PostgreSQL tests are inherited automatically
    # Add your application-specific tests
    tests:
      external:
        - app_api:/tests/test_api.sh
        - app_health:/tests/test_health.sh
```

### Extending Service Configuration

```yaml
containers:
  database:
    template: alpine-3.19
    includes:
      - postgresql
    
    # Extend PostgreSQL configuration
    post_install:
      - name: "Custom PostgreSQL setup"
        command: |
          # Create application database
          su - postgres -c "createdb myapp"
          
          # Create application user
          su - postgres -c "psql -c \"CREATE USER myapp WITH PASSWORD 'secret';\""
          su - postgres -c "psql -c \"GRANT ALL ON DATABASE myapp TO myapp;\""
          
          # Custom PostgreSQL configuration
          echo "max_connections = 200" >> /var/lib/postgresql/data/postgresql.conf
          
          # Restart PostgreSQL
          su - postgres -c "pg_ctl restart -D /var/lib/postgresql/data"
```

### Adding Custom Logs

```yaml
containers:
  webapp:
    template: ubuntu-minimal-24.04
    includes:
      - nginx
    
    # Nginx logs are inherited
    # Add your application logs
    logs:
      - app:/var/log/app/app.log
      - app_error:/var/log/app/error.log
```

## Migration from Docker Compose

### Docker Compose to LXC Compose Mapping

| Docker Compose | LXC Compose | Notes |
|----------------|-------------|-------|
| `image: postgres:alpine` | `template: alpine-3.19`<br>`includes: [postgresql]` | Use template + includes |
| `build: .` | `post_install:` commands | No Dockerfile equivalent |
| `ports: ["5432:5432"]` | `exposed_ports: [5432]` | Automatic port mapping |
| `volumes:` | `mounts:` | Same syntax |
| `environment:` | `.env` file | Use env file |
| `command:` | `services:` section | Supervisor-managed |
| `depends_on:` | `depends_on:` | Same syntax |
| `healthcheck:` | `tests:` section | Test-based health checks |

### Migration Example

**Docker Compose:**
```yaml
version: '3'
services:
  db:
    image: postgres:alpine
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - ./data:/var/lib/postgresql/data
    
  redis:
    image: redis:alpine
    
  app:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      - db
      - redis
    environment:
      DATABASE_URL: postgresql://db/myapp
      REDIS_URL: redis://redis:6379
```

**LXC Compose equivalent:**
```yaml
version: '1.0'
containers:
  backend:
    template: alpine-3.19
    
    # Combine services in one container
    includes:
      - postgresql
      - redis
    
    # App configuration
    packages:
      - python3
      - py3-pip
    
    exposed_ports:
      - 8000
    
    mounts:
      - ./data:/var/lib/postgresql/data
      - ./app:/app
    
    services:
      app:
        command: python3 /app/main.py
        directory: /app
        environment:
          DATABASE_URL: postgresql://localhost/myapp
          REDIS_URL: redis://localhost:6379
    
    post_install:
      - name: "Install Python dependencies"
        command: |
          cd /app
          pip3 install -r requirements.txt
```

## Best Practices

### 1. Choose the Right Base Template
- Use Alpine for services that don't need a full OS
- Use Ubuntu-minimal for most applications
- Use full Ubuntu/Debian only when necessary

### 2. Leverage Library Services
- Don't reinvent the wheel - use library services
- They're tested and optimized for each base image
- Include only what you need

### 3. Container Composition
- Combine related services in one container
- Unlike Docker, LXC containers can efficiently run multiple services
- This reduces overhead and complexity

### 4. Test Inheritance
- Library service tests are automatically included
- Add your own tests for custom functionality
- Use the three test types appropriately

### 5. Log Management
- Library services include log definitions
- Add your application logs to the logs section
- Use meaningful log names for easy identification

## Advanced Patterns

### Service Override Pattern

While you can't override core service configuration, you can disable and replace:

```yaml
containers:
  custom-nginx:
    template: ubuntu-24.04
    includes:
      - nginx
    
    post_install:
      - name: "Replace default Nginx with custom build"
        command: |
          # Stop included nginx
          systemctl stop nginx
          systemctl disable nginx
          
          # Install custom nginx
          # ... your custom installation ...
```

### Multi-Environment Configuration

Use environment variables for different deployments:

```yaml
containers:
  app:
    template: ${BASE_IMAGE:-ubuntu-minimal-24.04}
    
    includes:
      - postgresql
      - ${CACHE_SERVICE:-redis}  # Could be memcached
    
    exposed_ports:
      - ${APP_PORT:-8000}
```

### Testing Composite Containers

```bash
# Test all inherited and custom tests
lxc-compose test myapp

# Test only inherited PostgreSQL tests
lxc-compose test myapp external postgresql

# Test only custom application tests
lxc-compose test myapp external app_api
```

## Troubleshooting

### Service Conflicts

If included services conflict:
```yaml
# Wrong: Both services use port 80
includes:
  - nginx
  - haproxy

# Solution: Configure one to use different port
post_install:
  - name: "Move HAProxy to port 8080"
    command: |
      sed -i 's/:80/:8080/g' /etc/haproxy/haproxy.cfg
      systemctl restart haproxy
```

### Missing Dependencies

Library services assume base template packages:
```yaml
# Ensure base packages for your template
template: alpine-3.19
packages:
  - bash  # Some services need bash
  - curl  # For health checks
```

### Test Path Resolution

Tests are resolved from library service directory:
```yaml
# Library service test
tests:
  external:
    - postgresql:/tests/test.sh  # Looks in library/.../postgresql/tests/

# Your custom test
tests:
  external:
    - myapp:./tests/test.sh  # Looks in your project directory
```