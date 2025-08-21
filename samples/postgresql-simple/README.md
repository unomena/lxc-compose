# Simple PostgreSQL Server

Minimal PostgreSQL setup following Docker's official postgres image conventions.

## Quick Start

```bash
# Deploy with default password
lxc-compose up

# Or set a custom password
POSTGRES_PASSWORD=mysecret lxc-compose up
```

## Environment Variables

- `POSTGRES_PASSWORD` - Password for postgres user (required)
- `POSTGRES_DB` - Create a database (optional, default: postgres)  
- `POSTGRES_USER` - Create a user (optional)

## Connect

```bash
# Get container IP
lxc list postgres

# Connect with psql
PGPASSWORD=postgres psql -h <IP> -U postgres
```

## Examples

### Django
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'HOST': '<container-ip>',
        'PORT': '5432',
        'NAME': 'postgres',
        'USER': 'postgres', 
        'PASSWORD': 'postgres',
    }
}
```

### Node.js
```javascript
const pg = require('pg');
const client = new pg.Client({
  host: '<container-ip>',
  port: 5432,
  database: 'postgres',
  user: 'postgres',
  password: 'postgres'
});
```