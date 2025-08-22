# Simple Redis Server

Minimal Redis setup following Docker's official redis image conventions.

## Quick Start

```bash
# Deploy Redis without password
lxc-compose up

# Or with a password
REDIS_PASSWORD=mysecret lxc-compose up
```

## Environment Variables

- `REDIS_PASSWORD` - Set a password (optional)

## Connect

```bash
# Get container IP
lxc list redis

# Connect with redis-cli
redis-cli -h <IP>

# With password
redis-cli -h <IP> -a mysecret
```

## Examples

### Python
```python
import redis
r = redis.Redis(host='<container-ip>', port=6379, decode_responses=True)
# With password: password='mysecret'
```

### Node.js
```javascript
const redis = require('redis');
const client = redis.createClient({
  host: '<container-ip>',
  port: 6379,
  // password: 'mysecret'
});
```

### Django
```python
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.redis.RedisCache',
        'LOCATION': 'redis://<container-ip>:6379',
    }
}
```