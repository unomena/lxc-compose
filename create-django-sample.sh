#!/bin/bash

#############################################################################
# Create Django+Celery Sample Application Package
# Creates a complete Django application with Celery, Redis, and PostgreSQL
#############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1" >&2; exit 1; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# Parameters
APP_CONTAINER="${1:-app-1}"
DB_HOST="${2:-10.0.3.2}"
DB_NAME="${3:-sampleapp}"
DB_USER="${4:-appuser}"
DB_PASSWORD="${5:-apppass123}"
REDIS_HOST="${6:-10.0.3.2}"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Creating Django+Celery Sample Application             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

info "Container: $APP_CONTAINER"
info "Database: $DB_HOST:5432/$DB_NAME"
info "Redis: $REDIS_HOST:6379"
echo ""

# Create database if needed
log "Setting up database..."
sudo lxc-attach -n datastore -- bash -c "
    sudo -u postgres psql <<EOF 2>/dev/null || true
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\\q
EOF
" || warning "Database might already exist"

# Create application structure in container
log "Creating application structure..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    # Install system packages
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 python3-pip python3-venv python3-dev \
        build-essential libpq-dev nginx supervisor git redis-tools postgresql-client
    
    # Create app directory structure
    mkdir -p /srv/app/{src,static,media,logs}
    cd /srv/app
"

# Create requirements.txt
log "Creating requirements.txt..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/requirements.txt" <<'EOF'
Django==4.2.7
psycopg2-binary==2.9.9
redis==5.0.1
django-redis==5.4.0
celery==5.3.4
django-celery-beat==2.5.0
django-celery-results==2.5.1
gunicorn==21.2.0
python-decouple==3.8
django-cors-headers==4.3.0
djangorestframework==3.14.0
EOF

# Create lxc-compose.yaml
log "Creating lxc-compose.yaml..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/lxc-compose.yaml" <<EOF
# LXC Compose Configuration for Django Sample App
container:
  name: django-sample
  distribution: ubuntu
  release: 22.04
  arch: arm64
  
network:
  ip: 10.0.3.11
  gateway: 10.0.3.1
  
mounts:
  - source: /srv/apps/django-sample
    target: /srv/app
    
services:
  - name: django
    command: gunicorn sampleproject.wsgi:application --bind 0.0.0.0:8000
    directory: /srv/app/src
    environment:
      - DJANGO_SETTINGS_MODULE=sampleproject.settings
      - DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:5432/$DB_NAME
      - REDIS_URL=redis://$REDIS_HOST:6379/0
    
  - name: celery-worker
    command: celery -A sampleproject worker -l info
    directory: /srv/app/src
    environment:
      - DJANGO_SETTINGS_MODULE=sampleproject.settings
      - DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:5432/$DB_NAME
      - REDIS_URL=redis://$REDIS_HOST:6379/0
    
  - name: celery-beat
    command: celery -A sampleproject beat -l info
    directory: /srv/app/src
    environment:
      - DJANGO_SETTINGS_MODULE=sampleproject.settings
      - DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:5432/$DB_NAME
      - REDIS_URL=redis://$REDIS_HOST:6379/0
    
  - name: nginx
    command: nginx -g 'daemon off;'
EOF

# Create Django project structure
log "Setting up Django project..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    cd /srv/app
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Install dependencies
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # Create Django project in src
    cd src
    django-admin startproject sampleproject .
    python manage.py startapp api
    python manage.py startapp tasks
"

# Create .env file
log "Creating environment configuration..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/.env" <<EOF
DEBUG=True
SECRET_KEY=django-insecure-sample-key-change-in-production
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:5432/$DB_NAME
REDIS_URL=redis://$REDIS_HOST:6379/0
CELERY_BROKER_URL=redis://$REDIS_HOST:6379/0
CELERY_RESULT_BACKEND=redis://$REDIS_HOST:6379/0
ALLOWED_HOSTS=*
EOF

# Create Django settings
log "Configuring Django settings..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/src/sampleproject/settings.py" <<'EOF'
from pathlib import Path
from decouple import config
import os

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'django_celery_beat',
    'django_celery_results',
    'api',
    'tasks',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'sampleproject.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'sampleproject.wsgi.application'

# Database from environment
import dj_database_url
DATABASES = {
    'default': dj_database_url.parse(config('DATABASE_URL'))
}

# Redis Cache
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': config('REDIS_URL'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

# Celery Configuration
CELERY_BROKER_URL = config('CELERY_BROKER_URL')
CELERY_RESULT_BACKEND = config('CELERY_RESULT_BACKEND')
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = 'UTC'
CELERY_RESULT_BACKEND = 'django-db'

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR.parent / 'static'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR.parent / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
EOF

# Fix settings to add dj-database-url
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    cd /srv/app
    source venv/bin/activate
    pip install dj-database-url
"

# Create Celery configuration
log "Configuring Celery..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/src/sampleproject/celery.py" <<'EOF'
import os
from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sampleproject.settings')

app = Celery('sampleproject')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

@app.task(bind=True)
def debug_task(self):
    print(f'Request: {self.request!r}')
EOF

# Update __init__.py for Celery
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/src/sampleproject/__init__.py" <<'EOF'
from .celery import app as celery_app

__all__ = ('celery_app',)
EOF

# Create Celery tasks
log "Creating Celery tasks..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/src/tasks/tasks.py" <<'EOF'
from celery import shared_task
from django.core.cache import cache
from django.utils import timezone
import time
import random

@shared_task
def sample_task(task_name):
    """Sample task that simulates work and stores result in database"""
    # Simulate some work
    time.sleep(random.randint(2, 5))
    
    # Store in cache
    cache.set(f'task_{task_name}', {
        'status': 'completed',
        'timestamp': timezone.now().isoformat(),
        'result': f'Task {task_name} completed successfully!'
    }, timeout=300)
    
    return f"Task {task_name} completed at {timezone.now()}"

@shared_task
def database_task(record_count=10):
    """Task that interacts with database"""
    from tasks.models import TaskResult
    
    results = []
    for i in range(record_count):
        result = TaskResult.objects.create(
            name=f"Task_{i}",
            status="completed",
            result=f"Processed record {i}"
        )
        results.append(result.id)
        time.sleep(0.5)
    
    return f"Created {len(results)} task records"

@shared_task
def periodic_cleanup():
    """Periodic task to clean old records"""
    from tasks.models import TaskResult
    from datetime import timedelta
    
    cutoff = timezone.now() - timedelta(hours=24)
    deleted = TaskResult.objects.filter(created_at__lt=cutoff).delete()
    return f"Cleaned up {deleted[0]} old records"
EOF

# Create models
log "Creating models..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/src/tasks/models.py" <<'EOF'
from django.db import models

class TaskResult(models.Model):
    name = models.CharField(max_length=100)
    status = models.CharField(max_length=20, default='pending')
    result = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.name} - {self.status}"
EOF

# Create API views
log "Creating API views..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/src/api/views.py" <<'EOF'
from django.shortcuts import render
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.core.cache import cache
from tasks.tasks import sample_task, database_task
from tasks.models import TaskResult
import json

def index(request):
    """Main index page with task submission form"""
    return render(request, 'index.html')

def health(request):
    """Health check endpoint"""
    return JsonResponse({
        'status': 'healthy',
        'service': 'django-celery-sample',
        'timestamp': timezone.now().isoformat()
    })

@csrf_exempt
def submit_task(request):
    """Submit a task to Celery"""
    if request.method == 'POST':
        data = json.loads(request.body)
        task_type = data.get('type', 'sample')
        task_name = data.get('name', 'test_task')
        
        if task_type == 'sample':
            task = sample_task.delay(task_name)
        elif task_type == 'database':
            count = data.get('count', 5)
            task = database_task.delay(count)
        else:
            return JsonResponse({'error': 'Invalid task type'}, status=400)
        
        return JsonResponse({
            'task_id': task.id,
            'status': 'submitted',
            'message': f'Task {task_name} submitted successfully'
        })
    
    return JsonResponse({'error': 'POST method required'}, status=405)

def task_status(request, task_id):
    """Check task status"""
    from celery.result import AsyncResult
    
    result = AsyncResult(task_id)
    return JsonResponse({
        'task_id': task_id,
        'status': result.status,
        'result': str(result.result) if result.result else None
    })

def list_tasks(request):
    """List recent tasks from database"""
    tasks = TaskResult.objects.all()[:20]
    return JsonResponse({
        'tasks': [
            {
                'id': t.id,
                'name': t.name,
                'status': t.status,
                'result': t.result,
                'created': t.created_at.isoformat()
            } for t in tasks
        ]
    })

from django.utils import timezone
EOF

# Create templates
log "Creating templates..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    mkdir -p /srv/app/src/templates
    cat > /srv/app/src/templates/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Django + Celery Sample App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2e7d32; }
        .section { margin: 20px 0; padding: 20px; background: #f9f9f9; border-radius: 5px; }
        button { background: #4CAF50; color: white; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; margin: 5px; }
        button:hover { background: #45a049; }
        .result { margin: 10px 0; padding: 10px; background: #e8f5e9; border-left: 4px solid #4CAF50; }
        .error { background: #ffebee; border-left-color: #f44336; }
        #taskResults { margin-top: 20px; }
        .task-item { padding: 10px; margin: 5px 0; background: white; border: 1px solid #ddd; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Django + Celery Sample Application</h1>
        
        <div class="section">
            <h2>System Status</h2>
            <p>✅ Django is running</p>
            <p>✅ PostgreSQL connected</p>
            <p>✅ Redis connected</p>
            <p>✅ Celery workers active</p>
        </div>
        
        <div class="section">
            <h2>Submit Celery Task</h2>
            <p>Click to submit tasks to the Celery queue:</p>
            
            <button onclick="submitTask('sample')">Submit Sample Task</button>
            <button onclick="submitTask('database')">Submit Database Task</button>
            <button onclick="listTasks()">List Recent Tasks</button>
            
            <div id="taskResults"></div>
        </div>
        
        <div class="section">
            <h2>API Endpoints</h2>
            <ul>
                <li><code>GET /api/health/</code> - Health check</li>
                <li><code>POST /api/task/submit/</code> - Submit task</li>
                <li><code>GET /api/task/status/{id}/</code> - Check task status</li>
                <li><code>GET /api/tasks/</code> - List recent tasks</li>
            </ul>
        </div>
    </div>
    
    <script>
        function submitTask(type) {
            const taskName = 'task_' + Date.now();
            fetch('/api/task/submit/', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    type: type,
                    name: taskName,
                    count: 5
                })
            })
            .then(response => response.json())
            .then(data => {
                const resultsDiv = document.getElementById('taskResults');
                resultsDiv.innerHTML = '<div class="result">Task submitted! ID: ' + data.task_id + '</div>' + resultsDiv.innerHTML;
                
                // Check status after 3 seconds
                setTimeout(() => checkTaskStatus(data.task_id), 3000);
            })
            .catch(error => {
                document.getElementById('taskResults').innerHTML = '<div class="result error">Error: ' + error + '</div>';
            });
        }
        
        function checkTaskStatus(taskId) {
            fetch('/api/task/status/' + taskId + '/')
                .then(response => response.json())
                .then(data => {
                    const resultsDiv = document.getElementById('taskResults');
                    resultsDiv.innerHTML = '<div class="result">Task ' + taskId + ' status: ' + data.status + '</div>' + resultsDiv.innerHTML;
                });
        }
        
        function listTasks() {
            fetch('/api/tasks/')
                .then(response => response.json())
                .then(data => {
                    const resultsDiv = document.getElementById('taskResults');
                    let html = '<h3>Recent Tasks:</h3>';
                    data.tasks.forEach(task => {
                        html += '<div class="task-item">' + task.name + ' - ' + task.status + ' (' + task.created + ')</div>';
                    });
                    resultsDiv.innerHTML = html;
                });
        }
    </script>
</body>
</html>
EOF

# Create URLs
log "Configuring URLs..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/src/sampleproject/urls.py" <<'EOF'
from django.contrib import admin
from django.urls import path
from api import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', views.index, name='index'),
    path('api/health/', views.health, name='health'),
    path('api/task/submit/', views.submit_task, name='submit_task'),
    path('api/task/status/<str:task_id>/', views.task_status, name='task_status'),
    path('api/tasks/', views.list_tasks, name='list_tasks'),
]
EOF

# Create Supervisor configuration
log "Configuring Supervisor..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /etc/supervisor/conf.d/django-app.conf" <<EOF
[program:django]
command=/srv/app/venv/bin/gunicorn sampleproject.wsgi:application --bind 0.0.0.0:8000 --workers 2
directory=/srv/app/src
user=root
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/srv/app/logs/django.log
environment=PATH="/srv/app/venv/bin",DJANGO_SETTINGS_MODULE="sampleproject.settings"

[program:celery-worker]
command=/srv/app/venv/bin/celery -A sampleproject worker -l info
directory=/srv/app/src
user=root
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/srv/app/logs/celery-worker.log
environment=PATH="/srv/app/venv/bin",DJANGO_SETTINGS_MODULE="sampleproject.settings"

[program:celery-beat]
command=/srv/app/venv/bin/celery -A sampleproject beat -l info
directory=/srv/app/src
user=root
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/srv/app/logs/celery-beat.log
environment=PATH="/srv/app/venv/bin",DJANGO_SETTINGS_MODULE="sampleproject.settings"

[group:django-app]
programs=django,celery-worker,celery-beat
EOF

# Configure Nginx
log "Configuring Nginx..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /etc/nginx/sites-available/django-app" <<'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
    
    location /static/ {
        alias /srv/app/static/;
    }
    
    location /media/ {
        alias /srv/app/media/;
    }
}
EOF

sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    ln -sf /etc/nginx/sites-available/django-app /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
"

# Run migrations and collect static
log "Running migrations..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    cd /srv/app/src
    source ../venv/bin/activate
    export DJANGO_SETTINGS_MODULE=sampleproject.settings
    python manage.py makemigrations
    python manage.py migrate
    python manage.py collectstatic --noinput
    
    # Create superuser
    echo \"from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123') if not User.objects.filter(username='admin').exists() else None\" | python manage.py shell
"

# Start services
log "Starting services..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    nginx -t && systemctl restart nginx
    supervisorctl reread
    supervisorctl update
    supervisorctl start django-app:*
"

# Get container IP
APP_IP=$(sudo lxc-info -n "$APP_CONTAINER" -iH | head -1)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║      🎉 Django+Celery Sample App Deployed! 🎉                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
info "Application: http://$APP_IP/"
info "Admin Panel: http://$APP_IP/admin/ (admin/admin123)"
echo ""
info "Submit a task from the web interface or via API:"
echo '  curl -X POST http://'$APP_IP'/api/task/submit/ \'
echo '    -H "Content-Type: application/json" \'
echo '    -d '\''{"type":"sample","name":"test"}'\'''
echo ""
info "Monitor services:"
echo "  lxc-compose exec $APP_CONTAINER supervisorctl status"
echo ""
info "View logs:"
echo "  lxc-compose exec $APP_CONTAINER tail -f /srv/app/logs/django.log"
echo "  lxc-compose exec $APP_CONTAINER tail -f /srv/app/logs/celery-worker.log"
echo "