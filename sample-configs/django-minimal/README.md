# Django Minimal Sample - Alpine Single Container

An ultra-minimal Django application with PostgreSQL in a single Alpine Linux container.

## Features

- **Single Alpine container** (~150MB total)
- PostgreSQL database and Django in one container
- Django admin interface
- Environment-based configuration
- WhiteNoise for static files
- Auto-creates superuser (admin/admin123)

## Structure

```
django-minimal/
├── lxc-compose.yml     # Container configuration
├── requirements.txt    # Python dependencies
├── src/               # Django source code
│   ├── manage.py
│   └── config/
│       ├── __init__.py
│       ├── settings.py
│       ├── urls.py
│       └── wsgi.py
└── README.md
```

## Usage

1. Navigate to this directory:
   ```bash
   cd sample-configs/django-minimal
   ```

2. Start the container:
   ```bash
   lxc-compose up
   ```

3. Access the application:
   - Django app: http://localhost:8000
   - Admin: http://localhost:8000/admin (admin/admin123)
   - PostgreSQL: localhost:5432 (optional external access)

## Container Details

- **Base**: Alpine Linux 3.19 (~3MB base)
- **Services**:
  - PostgreSQL (running locally)
  - Django development server
- **Total size**: ~150MB (vs ~500MB+ for Ubuntu-based setup)

## Environment Variables

The application uses environment variables for configuration:
- `DB_NAME`: Database name (default: djangodb)
- `DB_USER`: Database user (default: djangouser)
- `DB_PASSWORD`: Database password (default: djangopass)
- `DB_HOST`: Database host (default: localhost)
- `DB_PORT`: Database port (default: 5432)
- `DEBUG`: Debug mode (default: True)
- `SECRET_KEY`: Django secret key

## Benefits of Single Container

- **Simpler deployment**: Only one container to manage
- **Lower resource usage**: Single Alpine container uses minimal RAM/disk
- **Faster startup**: No inter-container networking needed
- **Perfect for development**: Everything in one place

## Notes

- Alpine uses musl libc which may have compatibility issues with some Python packages
- PostgreSQL data is stored in `/var/lib/postgresql/data` inside the container
- Virtual environment is created at `/app/venv`
- Both PostgreSQL and Django run in the same container
- Database migrations run automatically during container setup

## Troubleshooting

If PostgreSQL doesn't start:
```bash
# Check PostgreSQL logs inside container
lxc exec django-minimal -- cat /var/lib/postgresql/logfile

# Manually start PostgreSQL
lxc exec django-minimal -- su postgres -c "pg_ctl -D /var/lib/postgresql/data start"
```

If Django doesn't connect to database:
```bash
# Check if PostgreSQL is running
lxc exec django-minimal -- su postgres -c "pg_ctl -D /var/lib/postgresql/data status"

# Test database connection
lxc exec django-minimal -- psql -h localhost -U djangouser -d djangodb -c '\l'
```