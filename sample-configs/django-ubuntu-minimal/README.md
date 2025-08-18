# Django Ubuntu Minimal Sample

A lightweight Django setup using Ubuntu Minimal containers.

## Quick Start

```bash
# Start the containers
lxc-compose up

# Access the application
http://localhost:8000  # Django dev server
http://localhost:8080  # Nginx
```

## Architecture

- **django-datastore**: PostgreSQL + Redis (~200MB)
- **django-app**: Django application server (~250MB)

## Services

- PostgreSQL 14
- Redis 7
- Django 4.2
- Nginx
- Python 3.10

## Default Credentials

- PostgreSQL: `djangouser` / `djangopass`
- Django Admin: Created on first run

## Directory Structure

```
django-ubuntu-minimal/
├── lxc-compose.yml     # Container configuration
├── requirements.txt    # Python dependencies
├── manage.py          # Django management script
└── README.md          # This file
```

The Django project will be created automatically on first run if it doesn't exist.