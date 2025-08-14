#!/bin/bash

#############################################################################
# Deploy Django Sample Application
# Deploys a working Django app with PostgreSQL and Redis integration
#############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1" >&2; exit 1; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# Default values
DEFAULT_APP_CONTAINER="app-1"
DEFAULT_DB_HOST="10.0.3.2"
DEFAULT_DB_NAME="sampleapp"
DEFAULT_DB_USER="appuser"
DEFAULT_DB_PASSWORD="apppass123"
DEFAULT_REDIS_HOST="10.0.3.2"
DEFAULT_APP_PORT="8000"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Django Sample Application Deployment               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Get configuration
read -p "Application container name [$DEFAULT_APP_CONTAINER]: " APP_CONTAINER
APP_CONTAINER=${APP_CONTAINER:-$DEFAULT_APP_CONTAINER}

read -p "Database host IP [$DEFAULT_DB_HOST]: " DB_HOST
DB_HOST=${DB_HOST:-$DEFAULT_DB_HOST}

read -p "Database name [$DEFAULT_DB_NAME]: " DB_NAME
DB_NAME=${DB_NAME:-$DEFAULT_DB_NAME}

read -p "Database user [$DEFAULT_DB_USER]: " DB_USER
DB_USER=${DB_USER:-$DEFAULT_DB_USER}

read -p "Database password [$DEFAULT_DB_PASSWORD]: " DB_PASSWORD
DB_PASSWORD=${DB_PASSWORD:-$DEFAULT_DB_PASSWORD}

read -p "Redis host IP [$DEFAULT_REDIS_HOST]: " REDIS_HOST
REDIS_HOST=${REDIS_HOST:-$DEFAULT_REDIS_HOST}

read -p "Application port [$DEFAULT_APP_PORT]: " APP_PORT
APP_PORT=${APP_PORT:-$DEFAULT_APP_PORT}

# Check if container exists
if ! sudo lxc-info -n "$APP_CONTAINER" &>/dev/null; then
    error "Container '$APP_CONTAINER' not found. Run 'lxc-compose wizard' first."
fi

# Get container IP
APP_IP=$(sudo lxc-info -n "$APP_CONTAINER" -iH | head -1)
info "Application container IP: $APP_IP"

echo ""
log "Setting up database..."

# Create database and user in PostgreSQL
sudo lxc-attach -n datastore -- bash -c "
    sudo -u postgres psql <<EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
EOF
" || warning "Database might already exist, continuing..."

echo ""
log "Installing Python and Django in container '$APP_CONTAINER'..."

# Install dependencies in app container
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 python3-pip python3-venv python3-dev \
        build-essential libpq-dev nginx supervisor git
"

echo ""
log "Creating Django application..."

# Create the Django application
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    # Create app directory
    mkdir -p /srv/app
    cd /srv/app
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Install Django and dependencies
    pip install --upgrade pip
    pip install django psycopg2-binary redis django-redis gunicorn
    
    # Create Django project
    django-admin startproject sampleapp .
    
    # Create a sample Django app
    python manage.py startapp api
"

echo ""
log "Configuring Django settings..."

# Configure Django settings
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/sampleapp/settings_production.py" <<EOF
from .settings import *
import os

# Security settings
DEBUG = True  # Set to False in real production
ALLOWED_HOSTS = ['*']  # Configure properly in production

# Database configuration
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': '$DB_NAME',
        'USER': '$DB_USER',
        'PASSWORD': '$DB_PASSWORD',
        'HOST': '$DB_HOST',
        'PORT': '5432',
    }
}

# Redis cache configuration
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://$REDIS_HOST:6379/1',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

# Static files
STATIC_URL = '/static/'
STATIC_ROOT = '/srv/app/static/'

# Media files
MEDIA_URL = '/media/'
MEDIA_ROOT = '/srv/app/media/'

# Add api app
INSTALLED_APPS += ['api']
EOF

echo ""
log "Creating Django views and URLs..."

# Create API views
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/api/views.py" <<'EOF'
from django.http import JsonResponse, HttpResponse
from django.views.decorators.cache import cache_page
from django.core.cache import cache
from django.db import connection
import redis
import json

def index(request):
    """Simple HTML index page"""
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Django Sample App</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            h1 { color: #2e7d32; }
            .endpoint { background: #f5f5f5; padding: 10px; margin: 10px 0; border-left: 4px solid #2e7d32; }
            code { background: #e8f5e9; padding: 2px 6px; border-radius: 3px; }
        </style>
    </head>
    <body>
        <h1>🎉 Django Sample Application</h1>
        <p>Your Django app is running successfully with PostgreSQL and Redis!</p>
        
        <h2>Available API Endpoints:</h2>
        <div class="endpoint">
            <strong>GET /</strong> - This page
        </div>
        <div class="endpoint">
            <strong>GET /api/health/</strong> - Health check endpoint
        </div>
        <div class="endpoint">
            <strong>GET /api/db-test/</strong> - Test database connection
        </div>
        <div class="endpoint">
            <strong>GET /api/redis-test/</strong> - Test Redis connection
        </div>
        <div class="endpoint">
            <strong>GET /api/cached/</strong> - Cached endpoint (60 seconds)
        </div>
        <div class="endpoint">
            <strong>POST /api/data/</strong> - Store data in Redis
        </div>
        <div class="endpoint">
            <strong>GET /api/data/&lt;key&gt;/</strong> - Retrieve data from Redis
        </div>
        
        <h2>System Info:</h2>
        <p>Database: PostgreSQL on {DB_HOST}</p>
        <p>Cache: Redis on {REDIS_HOST}</p>
    </body>
    </html>
    """.replace('{DB_HOST}', 'DB_HOST_PLACEHOLDER').replace('{REDIS_HOST}', 'REDIS_HOST_PLACEHOLDER')
    return HttpResponse(html)

def health(request):
    """Health check endpoint"""
    return JsonResponse({
        'status': 'healthy',
        'service': 'django-sample-app',
        'version': '1.0.0'
    })

def db_test(request):
    """Test database connection"""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT version();")
            version = cursor.fetchone()[0]
            cursor.execute("SELECT current_database();")
            db_name = cursor.fetchone()[0]
            
        return JsonResponse({
            'status': 'success',
            'database': db_name,
            'version': version,
            'message': 'Database connection successful'
        })
    except Exception as e:
        return JsonResponse({
            'status': 'error',
            'message': str(e)
        }, status=500)

def redis_test(request):
    """Test Redis connection"""
    try:
        r = redis.Redis(host='REDIS_HOST_PLACEHOLDER', port=6379, db=0)
        r.set('test_key', 'test_value', ex=10)
        value = r.get('test_key').decode('utf-8')
        
        return JsonResponse({
            'status': 'success',
            'message': 'Redis connection successful',
            'test_value': value
        })
    except Exception as e:
        return JsonResponse({
            'status': 'error',
            'message': str(e)
        }, status=500)

@cache_page(60)  # Cache for 60 seconds
def cached_endpoint(request):
    """Cached endpoint using Redis"""
    import time
    timestamp = time.time()
    
    return JsonResponse({
        'message': 'This response is cached for 60 seconds',
        'timestamp': timestamp,
        'cache_backend': 'Redis'
    })

def store_data(request):
    """Store data in Redis"""
    if request.method != 'POST':
        return JsonResponse({'error': 'POST method required'}, status=405)
    
    try:
        data = json.loads(request.body)
        key = data.get('key')
        value = data.get('value')
        
        if not key or not value:
            return JsonResponse({'error': 'key and value required'}, status=400)
        
        cache.set(key, value, timeout=300)  # 5 minutes
        
        return JsonResponse({
            'status': 'success',
            'message': f'Data stored with key: {key}'
        })
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

def get_data(request, key):
    """Retrieve data from Redis"""
    value = cache.get(key)
    
    if value is None:
        return JsonResponse({'error': 'Key not found'}, status=404)
    
    return JsonResponse({
        'key': key,
        'value': value
    })
EOF

# Replace placeholders with actual values
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    sed -i 's/DB_HOST_PLACEHOLDER/$DB_HOST/g' /srv/app/api/views.py
    sed -i 's/REDIS_HOST_PLACEHOLDER/$REDIS_HOST/g' /srv/app/api/views.py
"

# Create API URLs
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/api/urls.py" <<'EOF'
from django.urls import path
from . import views

urlpatterns = [
    path('health/', views.health, name='health'),
    path('db-test/', views.db_test, name='db_test'),
    path('redis-test/', views.redis_test, name='redis_test'),
    path('cached/', views.cached_endpoint, name='cached'),
    path('data/', views.store_data, name='store_data'),
    path('data/<str:key>/', views.get_data, name='get_data'),
]
EOF

# Update main URLs
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/sampleapp/urls.py" <<'EOF'
from django.contrib import admin
from django.urls import path, include
from api import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', views.index, name='index'),
    path('api/', include('api.urls')),
]
EOF

echo ""
log "Running Django migrations..."

# Run migrations
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    cd /srv/app
    source venv/bin/activate
    export DJANGO_SETTINGS_MODULE=sampleapp.settings_production
    python manage.py migrate
    python manage.py collectstatic --noinput
    
    # Create superuser
    echo \"from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123') if not User.objects.filter(username='admin').exists() else None\" | python manage.py shell
"

echo ""
log "Configuring Gunicorn..."

# Create Gunicorn configuration
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /srv/app/gunicorn_config.py" <<EOF
bind = "0.0.0.0:$APP_PORT"
workers = 2
worker_class = "sync"
worker_connections = 1000
max_requests = 1000
timeout = 30
keepalive = 2
EOF

echo ""
log "Configuring Supervisor..."

# Configure Supervisor
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /etc/supervisor/conf.d/django.conf" <<EOF
[program:django]
command=/srv/app/venv/bin/gunicorn sampleapp.wsgi:application -c /srv/app/gunicorn_config.py
directory=/srv/app
user=root
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/app/django.log
environment=DJANGO_SETTINGS_MODULE="sampleapp.settings_production"
EOF

echo ""
log "Configuring Nginx..."

# Configure Nginx
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /etc/nginx/sites-available/django" <<EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \\\$host;
        proxy_set_header X-Real-IP \\\$remote_addr;
        proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \\\$scheme;
    }
    
    location /static/ {
        alias /srv/app/static/;
    }
    
    location /media/ {
        alias /srv/app/media/;
    }
}
EOF

# Enable the site
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    ln -sf /etc/nginx/sites-available/django /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl restart nginx
"

echo ""
log "Starting Django application..."

# Start the application
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    supervisorctl reread
    supervisorctl update
    supervisorctl start django
"

# Wait for application to start
sleep 5

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         🎉 Django Sample App Deployed Successfully! 🎉        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
info "Application URL: http://$APP_IP/"
info "Admin URL: http://$APP_IP/admin/"
info "Admin credentials: admin / admin123"
echo ""
info "API Endpoints:"
echo "  http://$APP_IP/api/health/      - Health check"
echo "  http://$APP_IP/api/db-test/     - Database test"
echo "  http://$APP_IP/api/redis-test/  - Redis test"
echo "  http://$APP_IP/api/cached/      - Cached endpoint"
echo ""
info "Test from host:"
echo "  curl http://$APP_IP/api/health/"
echo "  curl http://$APP_IP/api/db-test/"
echo "  curl http://$APP_IP/api/redis-test/"
echo ""
info "Test data storage:"
echo "  # Store data:"
echo "  curl -X POST http://$APP_IP/api/data/ \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"key\":\"test\",\"value\":\"Hello World\"}'"
echo ""
echo "  # Retrieve data:"
echo "  curl http://$APP_IP/api/data/test/"
echo ""
info "View logs:"
echo "  lxc-compose exec $APP_CONTAINER tail -f /var/log/app/django.log"
echo ""