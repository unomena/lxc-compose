# LXC Compose Service Library

Production-ready services organized by base image. Each service is optimized for its specific base image and includes tests.

## Directory Structure

```
library/
├── alpine/
│   └── 3.19/           # Alpine Linux 3.19 (minimal, ~150MB)
│       ├── postgresql/
│       ├── redis/
│       ├── nginx/
│       ├── haproxy/
│       └── memcached/
│
├── ubuntu/
│   ├── 22.04/          # Ubuntu 22.04 LTS (full systemd, ~500MB)
│   │   ├── postgresql/
│   │   ├── mysql/
│   │   ├── mongodb/
│   │   ├── redis/
│   │   ├── nginx/
│   │   ├── rabbitmq/
│   │   ├── elasticsearch/
│   │   ├── grafana/
│   │   └── prometheus/
│   │
│   └── 24.04/          # Ubuntu 24.04 LTS (Noble)
│       └── postgresql/
│
├── ubuntu-minimal/
│   ├── 22.04/          # Ubuntu Minimal 22.04 (lightweight, ~300MB)
│   │   └── postgresql/
│   │
│   └── 24.04/          # Ubuntu Minimal 24.04
│
└── debian/
    ├── 11/             # Debian 11 (Bullseye)
    └── 12/             # Debian 12 (Bookworm)
        └── postgresql/
```

## Quick Start

### Deploy a Service

```bash
# Copy the service you need
cp -r library/alpine/3.19/postgresql ~/myproject/

# Or for Ubuntu
cp -r library/ubuntu/22.04/mysql ~/myproject/

# Deploy
cd ~/myproject/postgresql
lxc-compose up

# Test
lxc-compose test
```

## Image Selection Guide

### Alpine Linux 3.19
- **Size**: ~150MB
- **Best for**: Microservices, databases, caching
- **Pros**: Minimal size, fast startup, secure
- **Cons**: musl libc compatibility, limited packages
- **Services**: PostgreSQL, Redis, Nginx, HAProxy, Memcached

### Ubuntu 22.04 LTS
- **Size**: ~500MB
- **Best for**: Complex applications, full-featured services
- **Pros**: systemd, wide package support, familiar
- **Cons**: Larger size, more overhead
- **Services**: All services available

### Ubuntu 24.04 LTS
- **Size**: ~500MB
- **Best for**: Latest Ubuntu features
- **Pros**: Newest packages, long-term support
- **Services**: PostgreSQL, Redis, Nginx (more coming)

### Ubuntu Minimal
- **Size**: ~300MB
- **Best for**: Applications, web services
- **Pros**: Ubuntu compatibility, smaller size
- **Cons**: No systemd by default
- **Services**: PostgreSQL, Redis, web apps

### Debian
- **Size**: ~400MB
- **Best for**: Stable production systems
- **Pros**: Very stable, predictable
- **Services**: PostgreSQL, MySQL, web services

## Service Compatibility Matrix

| Service | Alpine 3.19 | Ubuntu 22.04 | Ubuntu 24.04 | Ubuntu Minimal | Debian 12 |
|---------|-------------|--------------|--------------|----------------|-----------|
| PostgreSQL | ✅ | ✅ | ✅ | ✅ | ✅ |
| MySQL | ❌ | ✅ | 🚧 | 🚧 | 🚧 |
| MongoDB | ❌ | ✅ | 🚧 | ❌ | 🚧 |
| Redis | ✅ | ✅ | 🚧 | 🚧 | 🚧 |
| Nginx | ✅ | ✅ | 🚧 | 🚧 | 🚧 |
| HAProxy | ✅ | 🚧 | 🚧 | 🚧 | 🚧 |
| Memcached | ✅ | 🚧 | 🚧 | 🚧 | 🚧 |
| RabbitMQ | ❌ | ✅ | 🚧 | ❌ | 🚧 |
| Elasticsearch | ❌ | ✅ | 🚧 | ❌ | 🚧 |
| Grafana | ❌ | ✅ | 🚧 | ❌ | 🚧 |
| Prometheus | ❌ | ✅ | 🚧 | ❌ | 🚧 |

Legend:
- ✅ Available and tested
- 🚧 In development
- ❌ Not recommended for this image

## Environment Variables

All services follow Docker conventions:

### PostgreSQL
- `POSTGRES_PASSWORD` - Required
- `POSTGRES_DB` - Optional database to create
- `POSTGRES_USER` - Optional user to create

### MySQL
- `MYSQL_ROOT_PASSWORD` - Required
- `MYSQL_DATABASE` - Optional
- `MYSQL_USER` - Optional
- `MYSQL_PASSWORD` - Optional

### Redis
- `REDIS_PASSWORD` - Optional

### MongoDB
- `MONGO_INITDB_ROOT_USERNAME` - Optional
- `MONGO_INITDB_ROOT_PASSWORD` - Optional
- `MONGO_INITDB_DATABASE` - Optional

## Package Name Differences

| Package | Alpine | Ubuntu/Debian |
|---------|--------|---------------|
| PostgreSQL | postgresql15 | postgresql |
| MySQL | mariadb | mysql-server |
| Redis | redis | redis-server |
| Python | python3, py3-pip | python3, python3-pip |
| Node.js | nodejs, npm | nodejs, npm |

## Testing

Every service includes tests:

```bash
# Test a service
lxc-compose test

# Specific test type
lxc-compose test postgres external
```

## Contributing

To add a new service variant:

1. Copy existing service as template
2. Adjust for target image:
   - Package names
   - Init system (systemd vs OpenRC)
   - File paths
3. Test thoroughly
4. Update compatibility matrix

## Notes

- Alpine services start faster but may have compatibility issues
- Ubuntu services have better compatibility but use more resources
- Debian services are most stable for production
- Ubuntu Minimal is good for applications but not complex services