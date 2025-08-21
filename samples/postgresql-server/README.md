# Standalone PostgreSQL Server

A production-ready PostgreSQL server that can be shared across multiple applications. Perfect for development, testing, and QA environments where you need a persistent database that doesn't get rebuilt with each application deployment.

## Features

- **Persistent Database**: Survives application rebuilds
- **Multi-tenant**: Support for multiple databases and users
- **Auto-configuration**: Creates databases and users from environment variables
- **Performance Tuned**: Optimized PostgreSQL settings for development/testing
- **Monitoring Ready**: Built-in slow query logging and metrics
- **Alpine-based**: Minimal footprint (~150MB)
- **Init Scripts**: Support for custom SQL/shell initialization scripts

## Quick Start

### 1. Deploy the PostgreSQL Server

```bash
cd samples/postgresql-server
lxc-compose up
```

### 2. Get Connection Details

```bash
# Get the container IP
lxc list postgresql-server

# Default connection strings:
# Superuser: postgresql://postgres:postgres@<IP>:5432/postgres
# App user:  postgresql://appuser:apppassword@<IP>:5432/development
```

### 3. Connect from Your Application

Update your application's `.env` file:
```env
DB_HOST=10.92.13.x  # Use actual IP from lxc list
DB_PORT=5432
DB_NAME=development
DB_USER=appuser
DB_PASSWORD=apppassword
```

## Configuration

### Environment Variables (.env)

```env
# PostgreSQL superuser password
POSTGRES_PASSWORD=postgres

# Additional admin user
ADMIN_USER=dbadmin
ADMIN_PASSWORD=dbadmin123

# Default application user
DEFAULT_APP_USER=appuser
DEFAULT_APP_PASSWORD=apppassword

# Databases to create (space-separated)
DATABASES="development testing production app_dev app_test"

# Application users (format: "user:password user2:password2")
APP_USERS="django:django123 flask:flask123 nodejs:node123"
```

### Default Databases

The following databases are created by default:
- `development` - For development work
- `testing` - For running tests
- `production` - For production-like testing

### Default Users

- `postgres` - Superuser (password: `postgres`)
- `dbadmin` - Admin user (password: `dbadmin123`)
- `appuser` - Default application user (password: `apppassword`)

Additional users can be configured via `APP_USERS` environment variable.

## Connecting from Applications

### From Django

```python
# settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'django_dev',
        'USER': 'django',
        'PASSWORD': 'django123',
        'HOST': '10.92.13.x',  # PostgreSQL container IP
        'PORT': '5432',
    }
}
```

### From Flask/SQLAlchemy

```python
# config.py
SQLALCHEMY_DATABASE_URI = 'postgresql://flask:flask123@10.92.13.x:5432/flask_dev'
```

### From Node.js

```javascript
// config.js
const pgConfig = {
  host: '10.92.13.x',
  port: 5432,
  database: 'nodejs_dev',
  user: 'nodejs',
  password: 'node123'
};
```

### Using psql Command Line

```bash
# Connect as superuser
PGPASSWORD=postgres psql -h 10.92.13.x -U postgres -d postgres

# Connect as application user
PGPASSWORD=apppassword psql -h 10.92.13.x -U appuser -d development

# Connect with connection string
psql postgresql://appuser:apppassword@10.92.13.x:5432/development
```

## Advanced Usage

### Custom Initialization Scripts

Place SQL or shell scripts in `config/init-scripts/`:

```bash
# SQL scripts are executed as postgres user
echo "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;" > config/init-scripts/01-extensions.sql

# Shell scripts are also supported
cat > config/init-scripts/02-custom-setup.sh << 'EOF'
#!/bin/sh
psql -U postgres -c "CREATE DATABASE myapp;"
EOF
```

### Data Persistence

To persist data between container rebuilds, uncomment the data mount in `lxc-compose.yml`:

```yaml
mounts:
  # Uncomment for data persistence
  - ./data:/var/lib/postgresql/data
```

### Performance Tuning

Adjust PostgreSQL settings in the `.env` file:

```env
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=512MB
POSTGRES_EFFECTIVE_CACHE_SIZE=2GB
POSTGRES_WORK_MEM=8MB
```

### Monitoring

View slow queries:
```bash
lxc-compose logs postgresql-server postgresql-slow
```

Check database sizes:
```bash
lxc exec postgresql-server -- su postgres -c "psql -c \"SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;\""
```

Active connections:
```bash
lxc exec postgresql-server -- su postgres -c "psql -c \"SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;\""
```

## Testing

Run health checks:
```bash
# Run all tests
lxc-compose test

# Check internal health
lxc-compose test postgresql-server internal

# Test external connectivity
lxc-compose test postgresql-server external
```

## Backup and Restore

### Backup a Database

```bash
# Backup specific database
lxc exec postgresql-server -- su postgres -c "pg_dump development" > development_backup.sql

# Backup all databases
lxc exec postgresql-server -- su postgres -c "pg_dumpall" > all_databases_backup.sql
```

### Restore a Database

```bash
# Restore specific database
cat development_backup.sql | lxc exec postgresql-server -- su postgres -c "psql development"

# Restore all databases
cat all_databases_backup.sql | lxc exec postgresql-server -- su postgres -c "psql"
```

## Troubleshooting

### Cannot Connect

1. Check container is running:
```bash
lxc list postgresql-server
```

2. Verify PostgreSQL is listening:
```bash
lxc exec postgresql-server -- netstat -tln | grep 5432
```

3. Check PostgreSQL logs:
```bash
lxc-compose logs postgresql-server postgresql
```

### Permission Denied

Ensure the user has proper permissions:
```bash
lxc exec postgresql-server -- su postgres -c "psql -c \"GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;\""
```

### Slow Performance

1. Check current connections:
```bash
lxc exec postgresql-server -- su postgres -c "psql -c \"SELECT count(*) FROM pg_stat_activity;\""
```

2. View slow queries:
```bash
lxc-compose logs postgresql-server postgresql-slow
```

3. Increase resources in `.env` and rebuild

## Security Notes

- Default passwords are for development only
- Change all passwords for production use
- Consider restricting `pg_hba.conf` for production
- Use SSL/TLS for production connections
- Regularly backup your databases

## Integration with Other Samples

This PostgreSQL server can be used with:
- `django-minimal` - Point Django to this server
- `django-celery-app` - Use for Django and Celery backend
- `flask-app` - Use alongside Redis for Flask
- Any custom application needing PostgreSQL

Simply update the application's database configuration to point to this server's IP address.

## Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)