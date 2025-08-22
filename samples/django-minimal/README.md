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
├── startup.sh          # Container startup script
├── config/             # Configuration files
│   ├── supervisord.conf        # Main supervisor config
│   └── supervisor.d/           # Service configs
│       ├── postgresql.ini      # PostgreSQL service
│       └── django.ini          # Django service
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
- **Services** (managed by Supervisor):
  - PostgreSQL (running locally)
  - Django development server
- **Process management**: Supervisor for automatic restarts
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
- Python packages are installed system-wide (no virtual environment needed in containers)
- Both PostgreSQL and Django run in the same container managed by Supervisor
- Database migrations run automatically during container setup

## Troubleshooting

Check Supervisor status:
```bash
# View all managed processes
lxc exec sample-django-minimal -- supervisorctl status

# Restart a specific service
lxc exec sample-django-minimal -- supervisorctl restart django
lxc exec sample-django-minimal -- supervisorctl restart postgresql
```

If PostgreSQL doesn't start:
```bash
# Check PostgreSQL logs
lxc exec sample-django-minimal -- tail -f /var/log/postgresql.log

# Check Supervisor logs
lxc exec sample-django-minimal -- tail -f /var/log/supervisord.log
```

If Django doesn't connect to database:
```bash
# Check Django logs
lxc exec sample-django-minimal -- tail -f /var/log/django.log

# Test database connection
lxc exec sample-django-minimal -- psql -h localhost -U djangouser -d djangodb -c '\l'
```