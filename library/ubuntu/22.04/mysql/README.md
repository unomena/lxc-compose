# Simple MySQL Server

Minimal MySQL setup following Docker's official mysql image conventions.

## Quick Start

```bash
# With default password
lxc-compose up

# With custom password
MYSQL_ROOT_PASSWORD=secret lxc-compose up
```

## Environment Variables

- `MYSQL_ROOT_PASSWORD` - Root password (required)
- `MYSQL_DATABASE` - Create database (optional)
- `MYSQL_USER` - Create user (optional)
- `MYSQL_PASSWORD` - User password (optional)

## Connect

```bash
# Get container IP
lxc list mysql

# Connect with mysql client
mysql -h <IP> -u root -p

# Connect as custom user
mysql -h <IP> -u appuser -p myapp
```

## Examples

### PHP
```php
$conn = new mysqli('<container-ip>', 'root', 'mysql', 'myapp');
```

### Python
```python
import mysql.connector
conn = mysql.connector.connect(
    host='<container-ip>',
    user='root',
    password='mysql',
    database='myapp'
)
```

### Node.js
```javascript
const mysql = require('mysql2');
const connection = mysql.createConnection({
  host: '<container-ip>',
  user: 'root',
  password: 'mysql',
  database: 'myapp'
});
```