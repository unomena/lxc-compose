# Migrating from Docker Compose to LXC Compose

This guide helps you migrate existing Docker Compose applications to LXC Compose.

## Key Differences

### Container Philosophy

| Docker Compose | LXC Compose |
|---------------|-------------|
| Application containers | System containers |
| Single process per container | Multiple services per container |
| Ephemeral by default | Persistent by default |
| Dockerfile builds | Template + packages + post_install |
| Microservices architecture | Service-oriented architecture |

### Configuration Mapping

| Docker Compose | LXC Compose | Notes |
|---------------|-------------|-------|
| `image:` | `image:` | Use base OS image (e.g., `images:alpine/3.19`) |
| `build:` | `packages:` + `post_install:` | Install packages and run setup |
| `ports:` | `exposed_ports:` | Only list ports, no mapping syntax |
| `volumes:` | `mounts:` | Similar syntax, different behavior |
| `environment:` | `.env` file | Environment variables in separate file |
| `depends_on:` | `depends_on:` | Same concept |
| `command:` | `services:` section | Define as supervisor service |
| `networks:` | Automatic | Single bridge network |
| `restart:` | `autorestart:` in services | Per-service configuration |

## Migration Strategy

### Step 1: Analyze Your Docker Compose File

Identify the components:
- What base images are used?
- What services run in each container?
- What ports need exposure?
- What data needs persistence?
- What are the dependencies?

### Step 2: Consolidate or Separate Services

Docker Compose typically uses one container per service. With LXC Compose, you can:

**Option A: One Service Per Container** (Docker-like)
- Maintains microservices architecture
- Easier migration
- More containers to manage

**Option B: Consolidate Related Services** (Recommended)
- Group related services (e.g., app + nginx)
- Fewer containers
- Simpler networking

### Step 3: Map Configuration

Create your `lxc-compose.yml` based on the mapping table above.

## Migration Examples

### Example 1: Simple Web Application

**Docker Compose:**
```yaml
version: '3'
services:
  web:
    image: python:3.11-slim
    ports:
      - "5000:5000"
    volumes:
      - .:/app
    environment:
      - FLASK_ENV=development
    command: python app.py
```

**LXC Compose:**
```yaml
version: "1.0"
containers:
  web:
    image: ubuntu-minimal:lts
    packages:
      - python3
      - python3-pip
    exposed_ports:
      - 5000
    mounts:
      - .:/app
    services:
      flask:
        command: python3 /app/app.py
        directory: /app
        autostart: true
        autorestart: true
    post_install:
      - name: "Install Python dependencies"
        command: |
          cd /app
          pip3 install -r requirements.txt
```

### Example 2: Web + Database

**Docker Compose:**
```yaml
version: '3'
services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - db_data:/var/lib/postgresql/data
  
  web:
    image: node:18-alpine
    ports:
      - "3000:3000"
    depends_on:
      - db
    environment:
      DATABASE_URL: postgresql://user:pass@db:5432/myapp
    command: npm start

volumes:
  db_data:
```

**LXC Compose:**
```yaml
version: "1.0"
containers:
  db:
    image: images:alpine/3.19
    packages:
      - postgresql
    mounts:
      - ./data/postgres:/var/lib/postgresql/data
    post_install:
      - name: "Setup PostgreSQL"
        command: |
          su postgres -c "initdb -D /var/lib/postgresql/data"
          su postgres -c "pg_ctl start -D /var/lib/postgresql/data"
          su postgres -c "createdb myapp"
          su postgres -c "createuser user"
          su postgres -c "psql -c \"ALTER USER user PASSWORD 'pass'\""
  
  web:
    image: images:alpine/3.19
    depends_on:
      - db
    packages:
      - nodejs
      - npm
    exposed_ports:
      - 3000
    mounts:
      - .:/app
    services:
      node:
        command: npm start
        directory: /app
        autostart: true
        environment: DATABASE_URL=postgresql://user:pass@db:5432/myapp
    post_install:
      - name: "Install Node dependencies"
        command: |
          cd /app
          npm install
```

### Example 3: Multi-Service Application

**Docker Compose:**
```yaml
version: '3'
services:
  redis:
    image: redis:alpine
  
  db:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_PASSWORD: secret
  
  web:
    build: .
    ports:
      - "8000:8000"
    depends_on:
      - db
      - redis
  
  worker:
    build: .
    command: celery worker
    depends_on:
      - db
      - redis
  
  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - web
```

**LXC Compose (Consolidated):**
```yaml
version: "1.0"
containers:
  # Data services container
  data:
    image: images:alpine/3.19
    packages:
      - postgresql
      - redis
    post_install:
      - name: "Setup services"
        command: |
          # PostgreSQL
          su postgres -c "initdb -D /var/lib/postgresql/data"
          su postgres -c "pg_ctl start -D /var/lib/postgresql/data"
          su postgres -c "createdb myapp"
          
          # Redis
          redis-server --daemonize yes
  
  # Application container (web + worker + nginx)
  app:
    image: ubuntu-minimal:lts
    depends_on:
      - data
    packages:
      - python3
      - python3-pip
      - nginx
      - supervisor
    exposed_ports:
      - 80
    mounts:
      - .:/app
      - ./nginx.conf:/etc/nginx/sites-available/default
    services:
      web:
        command: /app/venv/bin/gunicorn myapp:app
        directory: /app
        autostart: true
      worker:
        command: /app/venv/bin/celery -A myapp worker
        directory: /app
        autostart: true
    post_install:
      - name: "Setup application"
        command: |
          cd /app
          python3 -m venv venv
          ./venv/bin/pip install -r requirements.txt
          
          # Start nginx
          service nginx start
```

## Common Patterns

### Pattern 1: Database Containers

Docker often uses official database images. In LXC:

```yaml
# PostgreSQL in Alpine (~150MB)
postgres:
  template: alpine
  release: "3.19"
  packages: [postgresql]
  post_install:
    - name: "Initialize PostgreSQL"
      command: |
        su postgres -c "initdb -D /var/lib/postgresql/data"
        su postgres -c "pg_ctl start -D /var/lib/postgresql/data"

# MySQL in Alpine
mysql:
  template: alpine
  release: "3.19"
  packages: [mysql, mysql-client]
  post_install:
    - name: "Initialize MySQL"
      command: |
        mysql_install_db --user=mysql
        mysqld_safe &
```

### Pattern 2: Application Runtime

Replace Docker base images with OS packages:

| Docker Base Image | LXC Template + Packages |
|------------------|------------------------|
| `python:3.11` | `ubuntu-minimal` + `python3, python3-pip` |
| `node:18` | `ubuntu-minimal` + `nodejs, npm` |
| `ruby:3.2` | `ubuntu-minimal` + `ruby, bundler` |
| `golang:1.21` | `ubuntu-minimal` + `golang` |
| `openjdk:17` | `ubuntu-minimal` + `openjdk-17-jdk` |
| `nginx` | `alpine` + `nginx` |
| `redis` | `alpine` + `redis` |

### Pattern 3: Build Process

Docker's build process becomes post_install commands:

```yaml
# Docker
build:
  context: .
  dockerfile: Dockerfile

# LXC Compose equivalent
post_install:
  - name: "Build application"
    command: |
      cd /app
      # Install dependencies
      pip install -r requirements.txt
      # Run build steps
      python setup.py install
      # Compile assets
      npm run build
```

### Pattern 4: Environment Variables

Docker Compose embeds environment variables. LXC Compose uses `.env` files:

```env
# .env file
DB_HOST=data
DB_PORT=5432
DB_NAME=myapp
DB_USER=appuser
DB_PASSWORD=secret
REDIS_HOST=data
REDIS_PORT=6379
```

## Troubleshooting Migration

### Issue: Missing Docker Image Features

**Problem**: Docker image includes specific tools/configurations

**Solution**: Add required packages and configuration in `post_install`:
```yaml
post_install:
  - name: "Install additional tools"
    command: |
      apt-get update
      apt-get install -y specific-tool
      # Configure as needed
```

### Issue: Complex Networking

**Problem**: Docker Compose uses custom networks

**Solution**: LXC Compose uses a single bridge network. Use container names for internal communication:
```yaml
# Containers can reach each other by name
DATABASE_URL: postgresql://user:pass@db-container:5432/myapp
```

### Issue: Volume Permissions

**Problem**: Docker volumes have different permissions

**Solution**: Set permissions in post_install:
```yaml
post_install:
  - name: "Fix permissions"
    command: |
      chown -R www-data:www-data /app
      chmod -R 755 /app
```

### Issue: Init System

**Problem**: Docker containers don't have init systems

**Solution**: LXC containers have full init. Services can be managed properly:
```yaml
services:
  myservice:
    command: /usr/bin/myservice
    autostart: true
    autorestart: true
```

## Migration Checklist

- [ ] Inventory all Docker services
- [ ] Decide on consolidation strategy
- [ ] Map images to templates + packages
- [ ] Convert port mappings to exposed_ports
- [ ] Convert volumes to mounts
- [ ] Move environment variables to .env
- [ ] Convert commands to services
- [ ] Add post_install for setup
- [ ] Test each service individually
- [ ] Test inter-service communication
- [ ] Verify data persistence
- [ ] Document any custom configurations

## Benefits After Migration

1. **Lower Resource Usage**: System containers share more resources
2. **Persistent State**: Containers maintain state between restarts
3. **Full System Access**: Complete init system and standard tools
4. **Simpler Networking**: Direct container-to-container communication
5. **Better for Stateful Apps**: Designed for persistent services

## See Also

- [Configuration Reference](configuration.md)
- [Getting Started Tutorial](getting-started.md)
- [Sample Applications](../samples/)