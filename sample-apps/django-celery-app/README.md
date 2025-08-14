# Django + Celery Sample Application

This is a complete Django application with Celery for asynchronous task processing, using PostgreSQL as the database and Redis as the message broker.

## Features

- Django web application with API endpoints
- Celery for asynchronous task processing
- PostgreSQL database integration
- Redis as message broker and cache
- Supervisor for process management
- Nginx reverse proxy
- Sample tasks demonstrating database and cache operations

## Structure

```
sample-apps/django-celery-app/
├── src/                          # Django application source code
│   ├── sample_project/          # Main Django project
│   │   ├── settings.py         # Django settings
│   │   ├── urls.py             # URL routing
│   │   ├── wsgi.py             # WSGI application
│   │   └── celery.py           # Celery configuration
│   ├── api/                     # API application
│   │   ├── views.py            # API views
│   │   └── __init__.py
│   ├── tasks/                   # Celery tasks application
│   │   ├── tasks.py            # Celery task definitions
│   │   ├── models.py           # Database models
│   │   └── __init__.py
│   ├── templates/               # HTML templates
│   │   └── index.html          # Main UI
│   └── manage.py               # Django management script
├── config/                      # Configuration files
│   ├── supervisor.conf         # Supervisor configuration
│   └── nginx.conf              # Nginx configuration
├── requirements.txt            # Python dependencies
└── .env.example               # Environment variables template
```

## Deployment

This application is deployed automatically by the LXC Compose wizard. The deployment script:

1. Copies all files to the container at `/app/`
2. Installs Python dependencies
3. Configures database connections
4. Runs migrations
5. Sets up Supervisor to manage processes
6. Configures Nginx as a reverse proxy

## API Endpoints

- `GET /` - Main web interface
- `GET /api/health/` - Health check
- `POST /api/task/submit/` - Submit a Celery task
- `GET /api/task/status/{id}/` - Check task status
- `GET /api/tasks/` - List recent tasks

## Environment Variables

The application uses the following environment variables (configured automatically during deployment):

- `DJANGO_SECRET_KEY` - Django secret key
- `DB_NAME` - PostgreSQL database name
- `DB_USER` - PostgreSQL username
- `DB_PASSWORD` - PostgreSQL password
- `DB_HOST` - PostgreSQL host
- `DB_PORT` - PostgreSQL port
- `REDIS_HOST` - Redis host
- `REDIS_PORT` - Redis port
- `CELERY_BROKER_URL` - Celery broker URL
- `CELERY_RESULT_BACKEND` - Celery result backend