# LXC Compose Service Library

Pre-configured, production-ready services that can be deployed instantly with LXC Compose. Each service follows Docker conventions with minimal configuration.

## Quick Deploy

```bash
# Copy service to your project
cp -r library/postgresql ~/myproject/

# Deploy
cd ~/myproject/postgresql
lxc-compose up

# Test
lxc-compose test
```

## Available Services

### Databases

#### PostgreSQL
- **Image**: Alpine 3.19
- **Port**: 5432
- **Env**: `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_USER`
- **Use for**: Relational data, ACID compliance

#### MySQL
- **Image**: Ubuntu 22.04
- **Port**: 3306
- **Env**: `MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE`, `MYSQL_USER`
- **Use for**: Web applications, WordPress, legacy apps

#### MongoDB
- **Image**: Ubuntu 22.04
- **Port**: 27017
- **Env**: `MONGO_INITDB_ROOT_USERNAME`, `MONGO_INITDB_ROOT_PASSWORD`
- **Use for**: Document storage, NoSQL, flexible schemas

### Caching

#### Redis
- **Image**: Alpine 3.19
- **Port**: 6379
- **Env**: `REDIS_PASSWORD` (optional)
- **Use for**: Caching, sessions, pub/sub, queues

#### Memcached
- **Image**: Alpine 3.19
- **Port**: 11211
- **Env**: `MEMCACHED_MEMORY`, `MEMCACHED_CONNECTIONS`
- **Use for**: Simple key-value caching, sessions

### Web/Proxy

#### Nginx
- **Image**: Alpine 3.19
- **Ports**: 80, 443
- **Mounts**: `./html`, `./conf.d`
- **Use for**: Static sites, reverse proxy, load balancing

#### HAProxy
- **Image**: Alpine 3.19
- **Ports**: 80, 443, 8404 (stats)
- **Mount**: `./haproxy.cfg`
- **Use for**: Load balancing, high availability

### Message Queues

#### RabbitMQ
- **Image**: Ubuntu 22.04
- **Ports**: 5672 (AMQP), 15672 (Management)
- **Env**: `RABBITMQ_DEFAULT_USER`, `RABBITMQ_DEFAULT_PASS`
- **Use for**: Message queuing, task distribution, microservices

### Monitoring/Search

#### Elasticsearch
- **Image**: Ubuntu 22.04
- **Ports**: 9200 (HTTP), 9300 (Transport)
- **Use for**: Full-text search, log analysis, analytics

#### Grafana
- **Image**: Ubuntu 22.04
- **Port**: 3000
- **Env**: `GF_SECURITY_ADMIN_PASSWORD`
- **Use for**: Metrics visualization, dashboards

#### Prometheus
- **Image**: Ubuntu 22.04
- **Port**: 9090
- **Mount**: `./prometheus.yml`
- **Use for**: Metrics collection, alerting

## Service Categories

### Lightweight Services (Alpine-based)
- PostgreSQL, Redis, Nginx, HAProxy, Memcached
- Small footprint (~150-200MB)
- Fast startup
- Good for microservices

### Full-Featured Services (Ubuntu-based)
- MySQL, MongoDB, RabbitMQ, Elasticsearch, Grafana, Prometheus
- Larger footprint (~500MB+)
- Full system utilities
- Better for complex requirements

## Environment Variables

All services follow Docker conventions for environment variables:

```bash
# PostgreSQL
POSTGRES_PASSWORD=secret lxc-compose up

# MySQL
MYSQL_ROOT_PASSWORD=secret lxc-compose up

# MongoDB
MONGO_INITDB_ROOT_USERNAME=admin \
MONGO_INITDB_ROOT_PASSWORD=secret \
lxc-compose up
```

## Testing

Every service includes comprehensive tests:

```bash
# Run all tests
lxc-compose test

# Run specific test
lxc-compose test <container-name> external
```

Tests verify:
- Port connectivity
- Service health
- Basic operations (CRUD where applicable)
- API endpoints (where available)

## Customization

### Modify Configuration
1. Copy service to your project
2. Edit `lxc-compose.yml`
3. Adjust environment variables in `.env`
4. Add custom mounts or packages

### Extend Services
```yaml
# Add to existing service
containers:
  postgresql:
    image: images:alpine/3.19
    packages:
      - postgresql15
      - postgresql15-contrib  # Add extensions
    mounts:
      - ./custom-config:/etc/postgresql  # Custom configs
```

## Best Practices

1. **Use .env files** for sensitive data
2. **Mount data directories** for persistence
3. **Run tests** after deployment
4. **Check logs** for issues: `lxc-compose logs <service>`
5. **Use appropriate images**:
   - Alpine for simple services
   - Ubuntu for complex requirements

## Connection Examples

### From Application Containers

```python
# Python - PostgreSQL
import psycopg2
conn = psycopg2.connect(
    host="postgresql",  # Container name
    database="myapp",
    user="postgres",
    password="secret"
)

# Python - Redis
import redis
r = redis.Redis(host='redis', port=6379)
```

```javascript
// Node.js - MongoDB
const MongoClient = require('mongodb').MongoClient;
const url = 'mongodb://mongodb:27017/myapp';

// Node.js - MySQL
const mysql = require('mysql2');
const connection = mysql.createConnection({
  host: 'mysql',
  user: 'root',
  password: 'secret'
});
```

## Networking

All services are accessible:
- **Between containers**: Use container name as hostname
- **From host**: Use container IP (get with `lxc list`)
- **From outside**: Configure port forwarding if needed

## Troubleshooting

### Service Won't Start
```bash
# Check logs
lxc-compose logs <service>

# Check process
lxc exec <service> -- ps aux

# Check ports
lxc exec <service> -- netstat -tln
```

### Connection Refused
- Verify service is running
- Check IP binding (should be 0.0.0.0, not 127.0.0.1)
- Verify firewall rules

### Performance Issues
- Increase memory/CPU limits
- Check logs for errors
- Monitor with `lxc info <container>`