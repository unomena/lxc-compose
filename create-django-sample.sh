#!/bin/bash

#############################################################################
# Deploy Django+Celery Sample Application - Production-like Setup
# Clones the Django application from GitHub and mounts it into the container
# This mimics production deployment where code is on host and mounted
#############################################################################

set -euo pipefail

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
DB_HOST="${2:-10.0.3.30}"  # Using sample-datastore IP
DB_NAME="${3:-djangosample}"
DB_USER="${4:-djangouser}"
DB_PASSWORD="${5:-djangopass123}"
REDIS_HOST="${6:-10.0.3.30}"  # Using sample-datastore IP

# Application settings
GITHUB_REPO="https://github.com/euan/Sample-Django-Celery-App.git"
APP_DIR="/srv/apps/sample-django-app"
CONTAINER_APP_DIR="/app"

# Generate a Django secret key once for the entire deployment
DJANGO_SECRET_KEY=$(openssl rand -hex 32)

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Deploying Django+Celery Sample Application            ║"
echo "║                  (Production-like Setup)                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

info "Container: $APP_CONTAINER"
info "Database: $DB_HOST:5432/$DB_NAME"
info "Redis: $REDIS_HOST:6379"
info "Host mount: $APP_DIR -> $CONTAINER_APP_DIR"
echo ""

# Check if both containers already exist and are running
DATASTORE_CONTAINER="sample-datastore"
if sudo lxc-info -n "$DATASTORE_CONTAINER" &>/dev/null && sudo lxc-info -n "$APP_CONTAINER" &>/dev/null; then
    log "Both containers exist"
    
    # Just ensure database exists
    log "Ensuring database exists..."
    sudo lxc-attach -n "$DATASTORE_CONTAINER" -- bash -c "
        sudo -u postgres psql <<EOF 2>/dev/null || true
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\\q
EOF
    " || true
    
    # Check if Django is already deployed
    if [ -d "$APP_DIR" ] && [ -d "$APP_DIR/src" ]; then
        log "Django application already deployed"
        info "Repository location: $APP_DIR"
        
        # Ask if user wants to update
        read -p "Update application from GitHub? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Updating application from GitHub..."
            cd "$APP_DIR"
            git pull origin main
        fi
    else
        info "Containers exist but Django not deployed. Continuing with deployment..."
    fi
fi

# Step 1: Clone or update the application repository on the host
if [ -d "$APP_DIR" ]; then
    info "Application directory exists at $APP_DIR"
    read -p "Pull latest changes from GitHub? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Updating application from GitHub..."
        cd "$APP_DIR"
        git pull origin main
    fi
else
    log "Cloning application from GitHub..."
    sudo mkdir -p "$(dirname "$APP_DIR")"
    sudo git clone "$GITHUB_REPO" "$APP_DIR"
    sudo chown -R $USER:$USER "$APP_DIR"
fi

# Step 2: Check if sample-datastore container exists
if ! sudo lxc-info -n "$DATASTORE_CONTAINER" &>/dev/null; then
    info "Sample datastore container not found. Creating it..."
    
    # Use lxc-create for classic LXC (will fail if already exists, but that's OK)
    if ! sudo lxc-create -n "$DATASTORE_CONTAINER" -t ubuntu -- -r jammy 2>/dev/null; then
        warning "Container creation failed (may already exist)"
        # Check again if it exists now
        if ! sudo lxc-info -n "$DATASTORE_CONTAINER" &>/dev/null; then
            error "Failed to create datastore container"
        fi
    fi
    
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
    if ! sudo lxc-info -n "$DATASTORE_CONTAINER" 2>/dev/null | grep -q "State.*RUNNING"; then
        log "Starting datastore container..."
        sudo lxc-start -n "$DATASTORE_CONTAINER"
        sleep 5
    fi
fi

# Step 3: Check if app container exists
if ! sudo lxc-info -n "$APP_CONTAINER" &>/dev/null; then
    warning "App container '$APP_CONTAINER' not found. Creating it..."
    
    # Use lxc-create for classic LXC (will fail if already exists, but that's OK)
    if ! sudo lxc-create -n "$APP_CONTAINER" -t ubuntu -- -r jammy 2>/dev/null; then
        warning "Container creation failed (may already exist)"
        # Check again if it exists now
        if ! sudo lxc-info -n "$APP_CONTAINER" &>/dev/null; then
            error "Failed to create app container"
        fi
    fi
    
    # Configure with static IP and mount point
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

# Mount the application directory from host
lxc.mount.entry = $APP_DIR app none bind,create=dir 0 0

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
    if ! sudo lxc-info -n "$APP_CONTAINER" 2>/dev/null | grep -q "State.*RUNNING"; then
        log "Starting app container..."
        sudo lxc-start -n "$APP_CONTAINER"
        sleep 5
    fi
    
    # Check if mount is configured
    if ! grep -q "lxc.mount.entry = $APP_DIR" "/var/lib/lxc/$APP_CONTAINER/config"; then
        log "Adding mount configuration..."
        sudo bash -c "echo 'lxc.mount.entry = $APP_DIR app none bind,create=dir 0 0' >> /var/lib/lxc/$APP_CONTAINER/config"
        
        log "Restarting container to apply mount..."
        sudo lxc-stop -n "$APP_CONTAINER"
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

# Create directories in container
log "Setting up container directories..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    mkdir -p /var/log/django /var/log/celery /run/django
    mkdir -p /app/static /app/media
"

# Create .env file in the mounted directory
log "Creating environment configuration..."
cat > "$APP_DIR/.env" <<EOF
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

# Install Python dependencies in container
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

# Copy nginx configuration
log "Configuring nginx..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    cat > /etc/nginx/sites-available/django-app <<'NGINX_EOF'
server {
    listen 80;
    server_name _;

    location /static/ {
        alias /app/static/;
    }

    location /media/ {
        alias /app/media/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX_EOF
    
    ln -sf /etc/nginx/sites-available/django-app /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    nginx -t && systemctl restart nginx
"

# Generate supervisor configuration with environment variables
log "Configuring supervisor..."
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
stdout_logfile=/var/log/django/django.log
stderr_logfile=/var/log/django/django_err.log
environment=PATH="/app/venv/bin:/usr/bin",PYTHONPATH="/app/src",DJANGO_SETTINGS_MODULE="config.settings",DEBUG="True",DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY",DB_NAME="$DB_NAME",DB_USER="$DB_USER",DB_PASSWORD="$DB_PASSWORD",DB_HOST="$DB_HOST",DB_PORT="5432",REDIS_HOST="$REDIS_HOST",REDIS_PORT="6379",ALLOWED_HOSTS="*"
user=www-data

[program:celery]
command=/app/venv/bin/celery -A config worker -l info
directory=/app/src
autostart=true
autorestart=true
stdout_logfile=/var/log/celery/celery.log
stderr_logfile=/var/log/celery/celery_err.log
environment=PATH="/app/venv/bin:/usr/bin",PYTHONPATH="/app/src",DJANGO_SETTINGS_MODULE="config.settings",DEBUG="True",DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY",DB_NAME="$DB_NAME",DB_USER="$DB_USER",DB_PASSWORD="$DB_PASSWORD",DB_HOST="$DB_HOST",DB_PORT="5432",REDIS_HOST="$REDIS_HOST",REDIS_PORT="6379",ALLOWED_HOSTS="*"
user=www-data

[program:celery-beat]
command=/app/venv/bin/celery -A config beat -l info
directory=/app/src
autostart=true
autorestart=true
stdout_logfile=/var/log/celery/celery-beat.log
stderr_logfile=/var/log/celery/celery-beat_err.log
environment=PATH="/app/venv/bin:/usr/bin",PYTHONPATH="/app/src",DJANGO_SETTINGS_MODULE="config.settings",DEBUG="True",DJANGO_SECRET_KEY="$DJANGO_SECRET_KEY",DB_NAME="$DB_NAME",DB_USER="$DB_USER",DB_PASSWORD="$DB_PASSWORD",DB_HOST="$DB_HOST",DB_PORT="5432",REDIS_HOST="$REDIS_HOST",REDIS_PORT="6379",ALLOWED_HOSTS="*"
user=www-data
EOF

# Set permissions
log "Setting permissions..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    chown -R www-data:www-data /app
    chown -R www-data:www-data /var/log/django /var/log/celery
    chmod -R 755 /app
    chmod -R 775 /var/log/django /var/log/celery /app/media /app/static
"

# Restart services
log "Starting services..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
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
info "Host mount: $APP_DIR -> /app (in container)"
echo ""
info "Submit a task from the web interface or via API:"
echo '  curl -X POST http://'$APP_IP'/api/task/submit/ \'
echo '    -H "Content-Type: application/json" \'
echo '    -d '\''{"type":"sample","name":"test"}'\'''
echo ""
info "To make code changes:"
echo "  1. Edit files in: $APP_DIR"
echo "  2. Changes are immediately visible in container"
echo "  3. Restart Django: sudo lxc-attach -n $APP_CONTAINER -- supervisorctl restart django"
echo ""
info "Monitor services:"
echo "  sudo lxc-attach -n $APP_CONTAINER -- supervisorctl status"
echo ""
info "View logs:"
echo "  sudo lxc-attach -n $APP_CONTAINER -- tail -f /var/log/django/django.log"
echo "  sudo lxc-attach -n $APP_CONTAINER -- tail -f /var/log/celery/celery.log"
echo ""