#!/bin/bash

#############################################################################
# Fix Flask Manager Installation
# Ensures the Flask app is properly installed with all dependencies
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

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Fixing LXC Compose Manager Installation              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Stop the service if running
log "Stopping Flask manager service..."
sudo supervisorctl stop lxc-compose-manager 2>/dev/null || true

# Ensure directory exists
if [ ! -d "/srv/lxc-compose-manager" ]; then
    error "Flask manager directory not found. Run: lxc-compose update"
fi

cd /srv/lxc-compose-manager

# Remove old venv if it exists
if [ -d "venv" ]; then
    log "Removing old virtual environment..."
    sudo rm -rf venv
fi

# Create new virtual environment
log "Creating virtual environment..."
sudo python3 -m venv venv

# Activate and install dependencies
log "Installing Python dependencies..."
sudo ./venv/bin/pip install --upgrade pip setuptools wheel

# Install requirements
if [ -f "requirements.txt" ]; then
    sudo ./venv/bin/pip install -r requirements.txt
else
    # Install dependencies directly if requirements.txt is missing
    sudo ./venv/bin/pip install \
        Flask==3.0.0 \
        Flask-SocketIO==5.3.5 \
        python-socketio==5.10.0 \
        python-engineio==4.8.0 \
        Werkzeug==3.0.1 \
        Jinja2==3.1.2 \
        MarkupSafe==2.1.3 \
        itsdangerous==2.1.2 \
        click==8.1.7 \
        bidict==0.22.1 \
        simple-websocket==1.0.0 \
        wsproto==1.2.0
fi

# Update supervisor configuration
log "Updating supervisor configuration..."
sudo tee /etc/supervisor/conf.d/lxc-compose-manager.conf > /dev/null <<EOF
[program:lxc-compose-manager]
command=/srv/lxc-compose-manager/venv/bin/python /srv/lxc-compose-manager/app.py
directory=/srv/lxc-compose-manager
autostart=true
autorestart=true
startretries=3
user=root
environment=PATH="/srv/lxc-compose-manager/venv/bin:/usr/bin:/usr/local/bin",FLASK_SECRET_KEY="$(openssl rand -hex 32)"
stdout_logfile=/var/log/lxc-compose-manager.log
stderr_logfile=/var/log/lxc-compose-manager-error.log
stdout_logfile_maxbytes=10MB
stderr_logfile_maxbytes=10MB
stdout_logfile_backups=3
stderr_logfile_backups=3
EOF

# Create required directories
log "Creating required directories..."
sudo mkdir -p /etc/lxc-compose
sudo mkdir -p /var/log

# Test the Flask app
log "Testing Flask app..."
if sudo timeout 5 /srv/lxc-compose-manager/venv/bin/python /srv/lxc-compose-manager/app.py > /tmp/flask-test.log 2>&1 & then
    sleep 2
    if curl -s http://localhost:5000 > /dev/null 2>&1; then
        log "Flask app test successful!"
        sudo pkill -f "python /srv/lxc-compose-manager/app.py" || true
    else
        warning "Flask app started but not responding on port 5000"
        cat /tmp/flask-test.log
        sudo pkill -f "python /srv/lxc-compose-manager/app.py" || true
    fi
else
    error "Flask app failed to start. Check logs:"
    cat /tmp/flask-test.log
fi

# Reload supervisor
log "Reloading supervisor..."
sudo supervisorctl reread
sudo supervisorctl update

# Start the service
log "Starting Flask manager service..."
sudo supervisorctl start lxc-compose-manager

# Wait for startup
sleep 3

# Check status
if sudo supervisorctl status lxc-compose-manager | grep -q RUNNING; then
    log "Flask manager is running!"
    
    # Get the IP address
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           LXC Compose Manager Fixed! ✓                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    info "Access the web interface at:"
    echo "  http://$HOST_IP:5000"
    echo ""
    info "From your Mac:"
    echo "  http://$(ip -4 addr show | grep -v "127.0.0.1" | grep -v "10.0.3." | grep "inet " | head -1 | awk '{print $2}' | cut -d/ -f1):5000"
    echo ""
else
    error "Flask manager failed to start. Check logs:"
    sudo tail -20 /var/log/lxc-compose-manager-error.log
fi