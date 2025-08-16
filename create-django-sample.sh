#!/bin/bash

#############################################################################
# Deploy Django+Celery Sample Application
# Copies the pre-built Django application from sample-apps directory
# Enhanced to handle missing containers and auto-create as needed
#############################################################################

set -euo pipefail

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SAMPLE_APP_DIR="${SCRIPT_DIR}/sample-apps/django-celery-app"

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

# Parameters with better defaults for dedicated containers
APP_CONTAINER="${1:-sample-django-app}"
DB_HOST="${2:-10.0.3.2}"
DB_NAME="${3:-djangosample}"
DB_USER="${4:-djangouser}"
DB_PASSWORD="${5:-djangopass123}"
REDIS_HOST="${6:-10.0.3.2}"

# Generate a Django secret key once for the entire deployment
DJANGO_SECRET_KEY=$(openssl rand -hex 32)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Deploying Django+Celery Sample Application            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if sample app directory exists
if [ ! -d "$SAMPLE_APP_DIR" ]; then
    error "Sample application directory not found at: $SAMPLE_APP_DIR"
fi

info "Container: $APP_CONTAINER"
info "Database: $DB_HOST:5432/$DB_NAME"
info "Redis: $REDIS_HOST:6379"
echo ""

# Check if sample-datastore container exists and is running
DATASTORE_CONTAINER="sample-datastore"
if ! sudo lxc-ls | grep -q "^${DATASTORE_CONTAINER}$"; then
    warning "Sample datastore container not found. Creating it..."
    
    # Use lxc-create for classic LXC
    sudo lxc-create -n "$DATASTORE_CONTAINER" -t ubuntu -- -r jammy
    
    # Configure with static IP
    sudo bash -c "cat > /var/lib/lxc/$DATASTORE_CONTAINER/config" <<EOF
# Container
lxc.include = /usr/share/lxc/config/ubuntu.common.conf
lxc.arch = linux64

# Network
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.ipv4.address = 10.0.3.30/24
lxc.net.0.ipv4.gateway = 10.0.3.1

# System
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1

# Root filesystem
lxc.rootfs.path = dir:/var/lib/lxc/$DATASTORE_CONTAINER/rootfs
EOF
    
    sudo lxc-start -n "$DATASTORE_CONTAINER"
    
    sleep 5
    
    # Install PostgreSQL and Redis
    log "Installing PostgreSQL and Redis..."
    sudo lxc-attach -n "$DATASTORE_CONTAINER" -- bash -c "
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql redis-server
            sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/g\" /etc/postgresql/14/main/postgresql.conf
            echo 'host    all             all             10.0.3.0/24            md5' >> /etc/postgresql/14/main/pg_hba.conf
        sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/g' /etc/redis/redis.conf
        sed -i 's/protected-mode yes/protected-mode no/g' /etc/redis/redis.conf
        systemctl restart postgresql redis-server
    "
else
    # Ensure datastore is running
    if ! sudo lxc-ls --running | grep -q "^${DATASTORE_CONTAINER}$"; then
        log "Starting datastore container..."
        sudo lxc-start -n "$DATASTORE_CONTAINER"
        sleep 5
    fi
fi

# Check if app container exists
if ! sudo lxc-ls | grep -q "^${APP_CONTAINER}$"; then
    warning "App container '$APP_CONTAINER' not found. Creating it..."
    
    # Use lxc-create for classic LXC
    sudo lxc-create -n "$APP_CONTAINER" -t ubuntu -- -r jammy
    
    # Configure with static IP
    sudo bash -c "cat > /var/lib/lxc/$APP_CONTAINER/config" <<EOF
# Container
lxc.include = /usr/share/lxc/config/ubuntu.common.conf
lxc.arch = linux64

# Network
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.ipv4.address = 10.0.3.31/24
lxc.net.0.ipv4.gateway = 10.0.3.1

# System
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1

# Root filesystem
lxc.rootfs.path = dir:/var/lib/lxc/$APP_CONTAINER/rootfs
EOF
    
    sudo lxc-start -n "$APP_CONTAINER"
    sleep 10
else
    # Ensure app container is running
    if ! sudo lxc-ls --running | grep -q "^${APP_CONTAINER}$"; then
        log "Starting app container..."
        sudo lxc-start -n "$APP_CONTAINER"
        sleep 5
    fi
fi

# Create database if needed
log "Setting up database..."
sudo lxc-attach -n "$DATASTORE_CONTAINER" -- bash -c "
    sudo -u postgres psql <<EOF 2>/dev/null || true
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\\q
EOF
" || warning "Database might already exist"

# Install system packages in container
log "Installing system packages..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 python3-pip python3-venv python3-dev \
        build-essential libpq-dev nginx supervisor git redis-tools postgresql-client
"
fi

# Create application directory
log "Creating application directory..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    rm -rf /app
    mkdir -p /app/{static,media,logs}
"

# Copy application files to container
log "Copying application files..."
# Copy requirements.txt
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /app/requirements.txt" < "$SAMPLE_APP_DIR/requirements.txt"

# Copy source code
log "Copying source code..."
# We need to copy directory structure piece by piece due to LXC limitations
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "mkdir -p /app/src/config"
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "mkdir -p /app/src/api"
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "mkdir -p /app/src/tasks"
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "mkdir -p /app/src/templates"

# Copy Django project files
for file in settings.py urls.py wsgi.py celery.py __init__.py; do
    if [ -f "$SAMPLE_APP_DIR/src/config/$file" ]; then
        log "  Copying config/$file..."
        sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /app/src/config/$file" < "$SAMPLE_APP_DIR/src/config/$file"
    fi
done

# Copy manage.py
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /app/src/manage.py" < "$SAMPLE_APP_DIR/src/manage.py"
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "chmod +x /app/src/manage.py"

# Copy API app files
for file in views.py __init__.py; do
    if [ -f "$SAMPLE_APP_DIR/src/api/$file" ]; then
        log "  Copying api/$file..."
        sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /app/src/api/$file" < "$SAMPLE_APP_DIR/src/api/$file"
    fi
done

# Copy tasks app files
for file in tasks.py models.py __init__.py; do
    if [ -f "$SAMPLE_APP_DIR/src/tasks/$file" ]; then
        log "  Copying tasks/$file..."
        sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /app/src/tasks/$file" < "$SAMPLE_APP_DIR/src/tasks/$file"
    fi
done

# Copy templates
log "  Copying templates..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /app/src/templates/index.html" < "$SAMPLE_APP_DIR/src/templates/index.html"

# Create .env file with deployment-specific configuration
log "Creating environment configuration..."
# Note: DJANGO_SECRET_KEY is generated when creating supervisor config
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /app/.env" <<EOF
DEBUG=True
DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_HOST=$DB_HOST
DB_PORT=5432
REDIS_HOST=$REDIS_HOST
REDIS_PORT=6379
CELERY_BROKER_URL=redis://$REDIS_HOST:6379/0
CELERY_RESULT_BACKEND=redis://$REDIS_HOST:6379/0
ALLOWED_HOSTS=*
EOF

# Generate supervisor configuration with environment variables
log "Generating supervisor configuration..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /etc/supervisor/conf.d/django-app.conf" <<EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:django]
command=/app/venv/bin/python /app/src/manage.py runserver 0.0.0.0:8000
directory=/app/src
autostart=true
autorestart=true
stdout_logfile=/app/logs/django.log
stderr_logfile=/app/logs/django_err.log
environment=PATH="/app/venv/bin:/usr/bin",PYTHONPATH="/app/src",DJANGO_SETTINGS_MODULE="config.settings",DEBUG="True",DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY",DB_NAME="$DB_NAME",DB_USER="$DB_USER",DB_PASSWORD="$DB_PASSWORD",DB_HOST="$DB_HOST",DB_PORT="5432",REDIS_HOST="$REDIS_HOST",REDIS_PORT="6379",ALLOWED_HOSTS="*"
user=www-data

[program:celery]
command=/app/venv/bin/celery -A config worker -l info
directory=/app/src
autostart=true
autorestart=true
stdout_logfile=/app/logs/celery.log
stderr_logfile=/app/logs/celery_err.log
environment=PATH="/app/venv/bin:/usr/bin",PYTHONPATH="/app/src",DJANGO_SETTINGS_MODULE="config.settings",DEBUG="True",DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY",DB_NAME="$DB_NAME",DB_USER="$DB_USER",DB_PASSWORD="$DB_PASSWORD",DB_HOST="$DB_HOST",DB_PORT="5432",REDIS_HOST="$REDIS_HOST",REDIS_PORT="6379",ALLOWED_HOSTS="*"
user=www-data

[program:celery-beat]
command=/app/venv/bin/celery -A config beat -l info
directory=/app/src
autostart=true
autorestart=true
stdout_logfile=/app/logs/celery-beat.log
stderr_logfile=/app/logs/celery-beat_err.log
environment=PATH="/app/venv/bin:/usr/bin",PYTHONPATH="/app/src",DJANGO_SETTINGS_MODULE="config.settings",DEBUG="True",DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY",DB_NAME="$DB_NAME",DB_USER="$DB_USER",DB_PASSWORD="$DB_PASSWORD",DB_HOST="$DB_HOST",DB_PORT="5432",REDIS_HOST="$REDIS_HOST",REDIS_PORT="6379",ALLOWED_HOSTS="*"
user=www-data

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/app/logs/nginx.log
stderr_logfile=/app/logs/nginx_err.log
EOF

# Copy nginx configuration
log "Copying nginx configuration..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /etc/nginx/sites-available/django-app" < "$SAMPLE_APP_DIR/config/nginx.conf"

# Enable nginx site
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    ln -sf /etc/nginx/sites-available/django-app /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
"

# Install Python dependencies
log "Installing Python dependencies..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    cd /app
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip setuptools wheel
    pip install -r requirements.txt
"

# Run migrations
log "Running database migrations..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    cd /app/src
    source ../venv/bin/activate
    export DJANGO_SETTINGS_MODULE=config.settings
    python manage.py makemigrations api tasks
    python manage.py migrate
    python manage.py collectstatic --noinput
"

# Create superuser
log "Creating admin user..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    cd /app/src
    source ../venv/bin/activate
    export DJANGO_SETTINGS_MODULE=config.settings
    echo \"from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123') if not User.objects.filter(username='admin').exists() else None\" | python manage.py shell
"

# Set permissions
log "Setting permissions..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    chown -R www-data:www-data /app
    chmod -R 755 /app
    chmod -R 775 /app/logs /app/media /app/static
"

# Restart services
log "Starting services..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    nginx -t && systemctl restart nginx
    supervisorctl reread
    supervisorctl update
    supervisorctl restart all
"

# Wait for services to start
sleep 3

# Check service status
log "Checking service status..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "supervisorctl status"

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
echo "  sudo lxc-attach -n $APP_CONTAINER -- supervisorctl status"
echo ""
info "View logs:"
echo "  sudo lxc-attach -n $APP_CONTAINER -- tail -f /app/logs/django.log"
echo "  sudo lxc-attach -n $APP_CONTAINER -- tail -f /app/logs/celery.log"
echo ""