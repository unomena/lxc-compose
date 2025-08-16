# Migrating from Docker Compose to LXC Compose

This guide helps you migrate existing Docker Compose applications to LXC Compose.

## Table of Contents
- [Key Differences](#key-differences)
- [Migration Strategy](#migration-strategy)
- [Configuration Translation](#configuration-translation)
- [Common Patterns](#common-patterns)
- [Migration Examples](#migration-examples)
- [Troubleshooting](#troubleshooting)

## Key Differences

### Container Types

| Docker Compose | LXC Compose |
|---------------|-------------|
| Application containers | System containers |
| Single process per container | Multiple services per container |
| Dockerfile builds | Template-based + packages |
| Ephemeral by default | Persistent by default |

### Networking

| Docker Compose | LXC Compose |
|---------------|-------------|
| Docker networks | Bridge network + /etc/hosts |
| Service discovery by name | Exact container names only |
| Network aliases supported | No aliases - unique names required |
| Dynamic IP allocation | Static IP allocation |

### Configuration

| Docker Compose | LXC Compose |
|---------------|-------------|
| `docker-compose.yml` | `lxc-compose.yml` |
| `build:` context | `template:` + `packages:` |
| `image:` specification | `template:` + `release:` |
| `networks:` section | Automatic bridge network |
| `volumes:` section | `mounts:` in container |

## Migration Strategy

### Step 1: Analyze Your Docker Compose File

Identify the key components:
- Services and their dependencies
- Port mappings
- Volume mounts
- Environment variables
- Networks and aliases

### Step 2: Plan Container Consolidation

Docker Compose often uses many single-purpose containers. With LXC, you can consolidate:

**Docker Compose** (multiple containers):
```yaml
services:
  web:
    image: nginx
  app:
    image: python:3.9
  worker:
    image: python:3.9
```

**LXC Compose** (consolidated):
```yaml
containers:
  myapp-web:
    template: ubuntu
    packages:
      - nginx
      - python3
    services:
      nginx:
        # Nginx service
      app:
        # Python app service
      worker:
        # Worker service
```

### Step 3: Choose Naming Convention

Replace Docker service names with namespaced container names:

```yaml
# Docker Compose
services:
  db:
  redis:
  web:

# LXC Compose (with namespace)
containers:
  myproject-db:
  myproject-redis:
  myproject-web:
```

## Configuration Translation

### Basic Service Translation

**Docker Compose:**
```yaml
version: '3.8'
services:
  web:
    image: nginx:latest
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html
    environment:
      - NGINX_HOST=example.com
```

**LXC Compose:**
```yaml
version: '1.0'
containers:
  myapp-web:
    template: ubuntu
    release: jammy
    ports:
      - 80:80
    mounts:
      - ./html:/usr/share/nginx/html
    packages:
      - nginx
    environment:
      NGINX_HOST: example.com
```

### Database Service Translation

**Docker Compose:**
```yaml
services:
  postgres:
    image: postgres:14
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypass
```

**LXC Compose:**
```yaml
containers:
  myapp-db:
    template: ubuntu
    release: jammy
    ports:
      - 5432:5432
    mounts:
      - /srv/data/myapp-db:/var/lib/postgresql
    packages:
      - postgresql
      - postgresql-contrib
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myuser
      POSTGRES_PASSWORD: mypass
    services:
      postgresql:
        type: system
        config: |
          sudo -u postgres psql <<EOF
          CREATE USER myuser WITH PASSWORD 'mypass';
          CREATE DATABASE myapp OWNER myuser;
          EOF
```

### Application with Dependencies

**Docker Compose:**
```yaml
services:
  redis:
    image: redis:alpine
    
  db:
    image: postgres:14
    
  web:
    build: .
    depends_on:
      - db
      - redis
    ports:
      - "8000:8000"
    environment:
      DATABASE_URL: postgresql://user:pass@db:5432/myapp
      REDIS_URL: redis://redis:6379
```

**LXC Compose:**
```yaml
containers:
  myapp-redis:
    template: ubuntu
    release: jammy
    packages:
      - redis-server
    ports:
      - 6379:6379
      
  myapp-db:
    template: ubuntu
    release: jammy
    packages:
      - postgresql
    ports:
      - 5432:5432
      
  myapp-web:
    template: ubuntu
    release: jammy
    depends_on:
      - myapp-db
      - myapp-redis
    ports:
      - 8000:8000
    mounts:
      - .:/app
    packages:
      - python3
      - python3-pip
    environment:
      DATABASE_URL: postgresql://user:pass@myapp-db:5432/myapp
      REDIS_URL: redis://myapp-redis:6379
```

## Common Patterns

### Pattern 1: Microservices to System Containers

**Docker (Microservices):**
```yaml
services:
  nginx:
    image: nginx
  api:
    image: node:16
  worker:
    image: node:16
```

**LXC (Consolidated):**
```yaml
containers:
  myapp-services:
    template: ubuntu
    packages:
      - nginx
      - nodejs
      - npm
    services:
      nginx:
        type: system
      api:
        command: node /app/api/server.js
      worker:
        command: node /app/worker/index.js
```

### Pattern 2: Development Environment

**Docker Compose:**
```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - .:/app
      - /app/node_modules
    command: npm run dev
```

**LXC Compose:**
```yaml
containers:
  myapp-dev:
    template: ubuntu
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
    services:
      app:
        command: npm run dev
        directory: /app
```

### Pattern 3: Multi-Stage Builds → Post-Install

**Docker (Multi-stage):**
```dockerfile
FROM node:16 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:16-slim
WORKDIR /app
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/index.js"]
```

**LXC Compose:**
```yaml
containers:
  myapp-prod:
    template: ubuntu
    packages:
      - nodejs
      - npm
    mounts:
      - .:/app
    post_install:
      - name: "Build application"
        command: |
          cd /app
          npm ci
          npm run build
    services:
      app:
        command: node dist/index.js
        directory: /app
```

## Migration Examples

### Example 1: WordPress Stack

**Docker Compose:**
```yaml
version: '3.8'

services:
  wordpress:
    image: wordpress:latest
    ports:
      - 8080:80
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    volumes:
      - wordpress:/var/www/html
    depends_on:
      - db

  db:
    image: mysql:5.7
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
      MYSQL_ROOT_PASSWORD: somewordpress
    volumes:
      - db:/var/lib/mysql

volumes:
  wordpress:
  db:
```

**LXC Compose:**
```yaml
version: '1.0'

containers:
  wordpress-db:
    template: ubuntu
    release: jammy
    ports:
      - 3306:3306
    packages:
      - mysql-server
    mounts:
      - /srv/data/wordpress-db:/var/lib/mysql
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpress
      MYSQL_ROOT_PASSWORD: somewordpress
    post_install:
      - name: "Configure MySQL"
        command: |
          mysql -u root <<EOF
          CREATE DATABASE IF NOT EXISTS wordpress;
          CREATE USER IF NOT EXISTS 'wordpress'@'%' IDENTIFIED BY 'wordpress';
          GRANT ALL ON wordpress.* TO 'wordpress'@'%';
          FLUSH PRIVILEGES;
          EOF

  wordpress-web:
    template: ubuntu
    release: jammy
    depends_on:
      - wordpress-db
    ports:
      - 8080:80
    packages:
      - apache2
      - php
      - php-mysql
      - libapache2-mod-php
      - wget
    mounts:
      - /srv/apps/wordpress:/var/www/html
    environment:
      WORDPRESS_DB_HOST: wordpress-db
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpress
      WORDPRESS_DB_NAME: wordpress
    post_install:
      - name: "Install WordPress"
        command: |
          cd /var/www/html
          wget https://wordpress.org/latest.tar.gz
          tar xzf latest.tar.gz --strip-components=1
          rm latest.tar.gz
          chown -R www-data:www-data /var/www/html
```

### Example 2: Node.js + MongoDB

**Docker Compose:**
```yaml
version: '3.8'

services:
  mongo:
    image: mongo:5
    ports:
      - 27017:27017
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: secret
    volumes:
      - mongo_data:/data/db

  app:
    build: .
    ports:
      - 3000:3000
    environment:
      MONGODB_URI: mongodb://admin:secret@mongo:27017
      NODE_ENV: production
    depends_on:
      - mongo
    volumes:
      - .:/app
      - /app/node_modules

volumes:
  mongo_data:
```

**LXC Compose:**
```yaml
version: '1.0'

containers:
  nodeapp-db:
    template: ubuntu
    release: jammy
    ports:
      - 27017:27017
    packages:
      - mongodb
    mounts:
      - /srv/data/nodeapp-mongo:/var/lib/mongodb
    services:
      mongodb:
        type: system
        config: |
          sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
          systemctl restart mongodb

  nodeapp-web:
    template: ubuntu
    release: jammy
    depends_on:
      - nodeapp-db
    ports:
      - 3000:3000
    mounts:
      - .:/app
    packages:
      - nodejs
      - npm
    environment:
      MONGODB_URI: mongodb://admin:secret@nodeapp-db:27017
      NODE_ENV: production
    post_install:
      - name: "Install dependencies"
        command: |
          cd /app
          npm ci --production
    services:
      app:
        command: node server.js
        directory: /app
        autostart: true
        autorestart: true
```

## Troubleshooting

### Issue: Container Name Conflicts

**Problem:** Container names from Docker Compose are too generic.

**Solution:** Add project namespace:
```yaml
# Instead of: db, web, cache
# Use: myproject-db, myproject-web, myproject-cache
```

### Issue: Missing Build Context

**Problem:** Docker Compose uses `build:` with Dockerfile.

**Solution:** Use `packages:` and `post_install:`:
```yaml
packages:
  - python3
  - python3-pip
post_install:
  - name: "Install requirements"
    command: pip install -r /app/requirements.txt
```

### Issue: Network Aliases

**Problem:** Docker Compose uses network aliases for service discovery.

**Solution:** Use exact container names and update connection strings:
```yaml
# Docker: redis://cache:6379
# LXC: redis://myapp-cache:6379
```

### Issue: Named Volumes

**Problem:** Docker Compose uses named volumes.

**Solution:** Use host mount points:
```yaml
# Docker: volumes: - mydata:/data
# LXC: mounts: - /srv/data/myapp:/data
```

### Issue: Health Checks

**Problem:** Docker Compose has built-in health checks.

**Solution:** Use supervisor with autorestart:
```yaml
services:
  app:
    command: /app/start.sh
    autorestart: true  # Restarts if unhealthy
```

## Best Practices for Migration

1. **Start with a single service** - Migrate incrementally
2. **Use namespaces from the start** - Avoid conflicts
3. **Consolidate related services** - Reduce container count
4. **Test locally first** - Use development configurations
5. **Document changes** - Note any behavioral differences
6. **Keep both configs** - Maintain Docker Compose for compatibility

## Next Steps

- Review the [Configuration Reference](configuration.md) for all options
- Check [Troubleshooting Guide](troubleshooting.md) for common issues
- See [Production Deployment](production.md) for best practices