# Simple Memcached Server

Minimal Memcached setup following Docker's official memcached image conventions.

## Quick Start

```bash
# Default: 64MB memory
lxc-compose up

# Custom: 256MB memory
MEMCACHED_MEMORY=256 lxc-compose up
```

## Environment Variables

- `MEMCACHED_MEMORY` - Memory limit in MB (default: 64)
- `MEMCACHED_CONNECTIONS` - Max connections (default: 1024)

## Connect

```bash
# Get container IP
lxc list memcached

# Test with telnet
telnet <IP> 11211
> stats
> quit

# Test with nc
echo "stats" | nc <IP> 11211
```

## Examples

### Python
```python
import memcache
mc = memcache.Client(['<container-ip>:11211'])
mc.set("key", "value")
print(mc.get("key"))
```

### PHP
```php
$memcached = new Memcached();
$memcached->addServer('<container-ip>', 11211);
$memcached->set('key', 'value');
echo $memcached->get('key');
```

### Node.js
```javascript
const Memcached = require('memcached');
const memcached = new Memcached('<container-ip>:11211');
memcached.set('key', 'value', 10, (err) => {
  memcached.get('key', (err, data) => {
    console.log(data);
  });
});
```