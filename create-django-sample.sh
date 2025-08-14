#!/bin/bash

#############################################################################
# Deploy Django+Celery Sample Application
# Copies the pre-built Django application from sample-apps directory
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

# Parameters
APP_CONTAINER="${1:-app-1}"
DB_HOST="${2:-10.0.3.2}"
DB_NAME="${3:-sampleapp}"
DB_USER="${4:-appuser}"
DB_PASSWORD="${5:-apppass123}"
REDIS_HOST="${6:-10.0.3.2}"

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

# Install system packages in container
log "Installing system packages..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 python3-pip python3-venv python3-dev \
        build-essential libpq-dev nginx supervisor git redis-tools postgresql-client
"

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
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "mkdir -p /app/src/sample_project"
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "mkdir -p /app/src/api"
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "mkdir -p /app/src/tasks"
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "mkdir -p /app/src/templates"

# Copy Django project files
for file in settings.py urls.py wsgi.py celery.py __init__.py; do
    if [ -f "$SAMPLE_APP_DIR/src/sample_project/$file" ]; then
        log "  Copying sample_project/$file..."
        sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /app/src/sample_project/$file" < "$SAMPLE_APP_DIR/src/sample_project/$file"
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
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /app/.env" <<EOF
DEBUG=True
DJANGO_SECRET_KEY=django-insecure-$(openssl rand -hex 32)
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

# Copy configuration files
log "Copying configuration files..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "cat > /etc/supervisor/conf.d/django-app.conf" < "$SAMPLE_APP_DIR/config/supervisor.conf"
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
    export DJANGO_SETTINGS_MODULE=sample_project.settings
    python manage.py makemigrations api tasks
    python manage.py migrate
    python manage.py collectstatic --noinput
"

# Create superuser
log "Creating admin user..."
sudo lxc-attach -n "$APP_CONTAINER" -- bash -c "
    cd /app/src
    source ../venv/bin/activate
    export DJANGO_SETTINGS_MODULE=sample_project.settings
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