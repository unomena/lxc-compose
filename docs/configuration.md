# Configuration Reference

Complete reference for LXC Compose configuration files.

## Table of Contents
- [Configuration Formats](#configuration-formats)
- [File Structure](#file-structure)
- [Container Configuration](#containers)
- [Networking](#networking)
- [Port Forwarding](#port-forwarding)
- [Dependencies](#dependencies)
- [Mounts](#mounts)
- [Services](#services)
- [Environment Variables](#environment-variables)
- [Sample Projects](#sample-projects)
- [Complete Examples](#complete-examples)

## Configuration Formats

LXC Compose supports two configuration formats for maximum flexibility:

### Dictionary Format (Recommended)
The dictionary format is compatible with the reference project structure and is recommended for new projects:

```yaml
version: '1.0'
containers:
  container-name:    # Container name as key
    template: ubuntu
    release: jammy
    # ... configuration
```

### List Format (Legacy)
The list format is supported for backward compatibility:

```yaml
containers:
  - name: container-name    # Name as property
    image: ubuntu:22.04
    # ... configuration
```

## File Structure

### File Naming Standards
- **Primary**: `lxc-compose.yml` (recommended)
- **Alternative**: `lxc-compose.yaml`
- **Custom**: Any name with `-f` flag

### File Locations
LXC Compose looks for configuration files in this order:
1. File specified with `-f` flag
2. `lxc-compose.yml` in current directory
3. `lxc-compose.yaml` in current directory

### Version Declaration
```yaml
version: '1.0'  # Optional but recommended
```

## Container Configuration {#containers}

### Container Properties

| Property | Type | Description | Dictionary Format | List Format |
|----------|------|-------------|-------------------|-------------|
| `name` | string | Container name | Key name | Required property |
| `template` | string | Distribution template | ✓ | Use `image` |
| `release` | string | Release version | ✓ | Part of `image` |
| `image` | string | Full image name | Alternative | ✓ |
| `depends_on` | list | Container dependencies | ✓ | ✓ |
| `ports` | list | Port forwarding rules | ✓ | ✓ |
| `mounts` | list | Directory mounts | ✓ | ✓ |
| `packages` | list | APT/APK packages | ✓ | Limited |
| `services` | dict/list | Service configurations | ✓ | ✓ |
| `post_install` | list | Post-installation commands | ✓ | Limited |
| `environment` | dict | Environment variables | ✓ | ✓ |

### Template vs Image

**Template + Release (Dictionary Format):**
```yaml
containers:
  myapp:
    template: ubuntu    # or alpine, debian
    release: jammy      # or 3.19, bookworm
```

**Image (List Format):**
```yaml
containers:
  - name: myapp
    image: ubuntu:22.04    # or alpine:3.19
```

### Template Options

| Template | Releases | Size | Package Manager |
|----------|----------|------|-----------------|
| `alpine` | 3.19, 3.18 | ~3MB | apk |
| `ubuntu` | jammy (22.04), focal (20.04) | ~100MB (minimal) | apt |
| `debian` | bookworm (12), bullseye (11) | ~120MB | apt |

## Networking

### Container Naming Rules and Restrictions

**Requirements:**
- **Globally unique** across the entire system
- **Valid characters**: lowercase letters, numbers, hyphens
- **No underscores** in container names (use hyphens)
- **Maximum length**: 63 characters

**Best Practices:**
```yaml
containers:
  # Good - project namespaced
  myproject-db:
  myproject-app:
  myproject-cache:
  
  # Bad - too generic
  db:
  app:
  cache:
```

### Hostname Resolution
Containers can reference each other by name:
```yaml
environment:
  DB_HOST: myproject-db    # Direct container name
  REDIS_URL: redis://myproject-cache:6379
```

## Port Forwarding

### Port Syntax
Both formats support the same port syntax:

```yaml
ports:
  - 8080:80         # host:container
  - "3000:3000"     # quoted (recommended)
  - 5432:5432       # database ports
```

### Port Restrictions
- Host ports must be available (not in use)
- Privileged ports (< 1024) require root/sudo
- Each host port can only be mapped once

## Dependencies

### Dependency Declaration
```yaml
containers:
  database:
    # No dependencies
    
  app:
    depends_on:
      - database    # Single dependency
      
  worker:
    depends_on:      # Multiple dependencies
      - database
      - cache
```

### Dependency Restrictions
- No circular dependencies allowed
- Maximum wait time: 60 seconds per dependency
- Non-existent dependencies cause startup failure

## Mounts

### Mount Formats

**Simple String Format:**
```yaml
mounts:
  - .:/app                    # Current directory
  - ./data:/var/lib/data      # Relative path
  - /srv/app:/app             # Absolute path
```

**Explicit Dictionary Format:**
```yaml
mounts:
  - source: ./app
    target: /var/www
  - source: /srv/data
    target: /data
```

### Mount Restrictions
- Source paths are converted to absolute paths
- Source directories are created if they don't exist
- Relative paths are resolved from config file location

## Services

### Service Types

**Supervisor Services (Default):**
```yaml
services:
  web:
    command: /app/venv/bin/python app.py
    directory: /app
    autostart: true
    autorestart: true
    user: www-data
    environment:
      PORT: "3000"
```

**System Services:**
```yaml
services:
  nginx:
    type: system
    config: |
      # Shell commands to configure service
      systemctl enable nginx
      systemctl start nginx
```

### Service Restrictions
- Supervisor services require `supervisor` package
- System services require systemd
- Service names must be unique within container

## Environment Variables

### Variable Format
```yaml
environment:
  # All values must be strings
  DEBUG: "true"           # Boolean as string
  PORT: "3000"           # Number as string
  DATABASE_URL: "postgresql://..."
```

### Variable Restrictions
- All values must be strings (quoted)
- No variable expansion/interpolation
- Available to all services in container

## Sample Projects

LXC Compose includes sample projects demonstrating best practices:

### 1. Django Minimal (`sample-configs/django-minimal/`)
- **Format**: Dictionary (recommended)
- **Features**: Single Alpine container with PostgreSQL and Django
- **Size**: ~150MB total
- **Use Case**: Minimal Django development

```yaml
containers:
  django-minimal:
    template: alpine
    release: "3.19"
    mounts:
      - .:/app
    ports:
      - 8000:8000
    # Full configuration in sample
```

### 2. Flask Application (`sample-configs/flask-app/`)
- **Format**: Dictionary (recommended)
- **Features**: Flask with Redis, Nginx proxy
- **Size**: ~200MB total
- **Use Case**: Microservice with caching

```yaml
containers:
  flask-redis:
    template: ubuntu
    release: jammy
    # Redis configuration
    
  flask-app:
    depends_on:
      - flask-redis
    # Flask configuration
```

### 3. Node.js Application (`sample-configs/nodejs-app/`)
- **Format**: Dictionary (recommended)
- **Features**: Express.js with MongoDB
- **Size**: ~250MB total
- **Use Case**: JavaScript full-stack application

```yaml
containers:
  nodejs-mongo:
    template: ubuntu
    release: jammy
    # MongoDB configuration
    
  nodejs-app:
    depends_on:
      - nodejs-mongo
    # Node.js configuration
```

### 4. Reference Django Project
Based on https://github.com/euan/sample-lxc-compose-app:
- **Format**: Dictionary with full features
- **Features**: Django, Celery, PostgreSQL, Redis
- **Use Case**: Production-ready Django application

## Complete Examples

### Minimal Single Container (Alpine)
```yaml
version: '1.0'
containers:
  app:
    template: alpine
    release: "3.19"
    ports:
      - "8080:80"
    mounts:
      - .:/app
    packages:
      - python3
      - py3-pip
    post_install:
      - name: "Setup app"
        command: |
          cd /app
          python3 -m venv venv
          source venv/bin/activate
          pip install -r requirements.txt
```

### Multi-Container Application (Ubuntu)
```yaml
version: '1.0'
containers:
  myapp-db:
    template: ubuntu
    release: jammy
    packages:
      - postgresql
      - postgresql-contrib
    services:
      postgresql:
        type: system
        config: |
          systemctl enable postgresql
          systemctl start postgresql
    environment:
      POSTGRES_USER: "myapp"
      POSTGRES_PASSWORD: "secret"
      POSTGRES_DB: "myapp_db"
    
  myapp-app:
    template: ubuntu
    release: jammy
    depends_on:
      - myapp-db
    ports:
      - "8000:8000"
    mounts:
      - .:/app
    packages:
      - python3
      - python3-pip
      - python3-venv
      - supervisor
    post_install:
      - name: "Setup virtual environment"
        command: |
          cd /app
          python3 -m venv venv
          source venv/bin/activate
          pip install -r requirements.txt
    services:
      app:
        command: /app/venv/bin/python /app/manage.py runserver 0.0.0.0:8000
        directory: /app
        autostart: true
        autorestart: true
        environment:
          DB_HOST: "myapp-db"
          DB_PORT: "5432"
          DB_NAME: "myapp_db"
          DB_USER: "myapp"
          DB_PASSWORD: "secret"
```

### Production-Ready Django (Alpine + PostgreSQL)
```yaml
version: '1.0'
containers:
  django-app:
    template: alpine
    release: "3.19"
    ports:
      - "8000:8000"  # Django
      - "5432:5432"  # PostgreSQL (optional external access)
    mounts:
      - .:/app
    packages:
      - postgresql
      - postgresql-client
      - python3
      - py3-pip
      - python3-dev
      - gcc
      - musl-dev
      - postgresql-dev
      - supervisor
    post_install:
      - name: "Setup PostgreSQL"
        command: |
          mkdir -p /run/postgresql
          chown postgres:postgres /run/postgresql
          su postgres -c "initdb -D /var/lib/postgresql/data"
          echo "host all all 127.0.0.1/32 md5" >> /var/lib/postgresql/data/pg_hba.conf
          su postgres -c "pg_ctl -D /var/lib/postgresql/data start"
          su postgres -c "createdb djangodb"
          su postgres -c "psql -c \"CREATE USER djangouser WITH PASSWORD 'djangopass';\""
          su postgres -c "psql -c \"GRANT ALL ON DATABASE djangodb TO djangouser;\""
      - name: "Setup Django"
        command: |
          cd /app
          python3 -m venv venv
          source venv/bin/activate
          pip install django psycopg2-binary whitenoise
          python manage.py migrate
          python manage.py collectstatic --noinput
    services:
      postgresql:
        type: system
        config: |
          su postgres -c "pg_ctl -D /var/lib/postgresql/data start"
      django:
        command: /app/venv/bin/python /app/manage.py runserver 0.0.0.0:8000
        directory: /app
        autostart: true
        autorestart: true
        environment:
          DB_NAME: "djangodb"
          DB_USER: "djangouser"
          DB_PASSWORD: "djangopass"
          DB_HOST: "localhost"
```

## Configuration Standards

### Required Fields
- Container must have either:
  - `template` + `release` (dictionary format)
  - `image` (list format)
  - `name` (list format only)

### Naming Conventions
1. Use hyphens, not underscores: `my-app` not `my_app`
2. Include project prefix: `projectname-service`
3. Be descriptive: `myapp-postgres` not `db`

### File Organization
1. Group related containers together
2. Order by dependency (databases first)
3. Use comments to explain complex configurations
4. Keep secrets in environment variables

### Best Practices
1. **Always specify versions** (template releases)
2. **Use dictionary format** for new projects
3. **Namespace container names** by project
4. **Mount project directory** for development
5. **Use post_install** for one-time setup
6. **Configure services** properly (supervisor/systemd)
7. **Set environment variables** for configuration

## Restrictions Summary

### Hard Restrictions
- No circular dependencies
- Container names must be globally unique
- Port mappings must be unique on host
- All environment values must be strings
- Relative mount paths converted to absolute

### Soft Restrictions (Warnings)
- Missing dependencies logged but don't stop execution
- Failed post_install commands logged but continue
- Service failures logged but container continues

### Format-Specific Restrictions

**Dictionary Format Only:**
- Full support for all features
- `template` + `release` syntax
- Complex service definitions
- Structured post_install commands

**List Format Only:**
- Basic feature support
- `image` syntax required
- Limited service options
- Simple command strings

## Migration Guide

To migrate from list to dictionary format:

**Before (List):**
```yaml
containers:
  - name: myapp
    image: ubuntu:22.04
    ports:
      - 8080:80
```

**After (Dictionary):**
```yaml
containers:
  myapp:
    template: ubuntu
    release: jammy
    ports:
      - 8080:80
```

### Flask with Redis Cache
```yaml
version: '1.0'
containers:
  flask-redis:
    template: alpine
    release: "3.19"
    packages:
      - redis
    services:
      redis:
        command: redis-server --bind 0.0.0.0
        autostart: true
        autorestart: true

  flask-app:
    template: alpine
    release: "3.19"
    depends_on:
      - flask-redis
    ports:
      - "5000:5000"
    mounts:
      - .:/app
    packages:
      - python3
      - py3-pip
      - python3-dev
      - gcc
      - musl-dev
    post_install:
      - name: "Install Flask app"
        command: |
          cd /app
          pip install flask redis gunicorn
    services:
      flask:
        command: gunicorn -w 4 -b 0.0.0.0:5000 app:app
        directory: /app
        autostart: true
        environment:
          REDIS_HOST: "flask-redis"
          REDIS_PORT: "6379"
```

### Node.js with MongoDB
```yaml
version: '1.0'
containers:
  nodejs-mongo:
    template: ubuntu
    release: jammy
    packages:
      - mongodb
    services:
      mongodb:
        type: system
        config: |
          systemctl enable mongodb
          systemctl start mongodb

  nodejs-app:
    template: ubuntu
    release: jammy
    depends_on:
      - nodejs-mongo
    ports:
      - "3000:3000"
    mounts:
      - .:/app
    packages:
      - nodejs
      - npm
    post_install:
      - name: "Install dependencies"
        command: |
          cd /app
          npm install
          npm install -g pm2
    services:
      nodejs:
        command: pm2 start /app/server.js --name app --no-daemon
        directory: /app
        autostart: true
        environment:
          NODE_ENV: "production"
          MONGO_URL: "mongodb://nodejs-mongo:27017/myapp"
```

For complete working examples, see the sample projects in `sample-configs/`.