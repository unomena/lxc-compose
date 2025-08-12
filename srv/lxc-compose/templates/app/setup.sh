#!/bin/bash
# /srv/lxc-compose/templates/app/setup.sh

# This runs inside the container during creation

# Update and install base packages
apt-get update
apt-get install -y \
    python3.11 \
    python3-pip \
    python3-venv \
    postgresql-client \
    redis-tools \
    nginx \
    supervisor \
    curl \
    git \
    build-essential \
    python3.11-dev

# Create app user
useradd -m -s /bin/bash app

# Setup Python virtual environment
sudo -u app python3 -m venv /app/venv

# Install Python packages
sudo -u app /app/venv/bin/pip install --upgrade pip
sudo -u app /app/venv/bin/pip install \
    django \
    gunicorn \
    celery \
    redis \
    psycopg2-binary \
    python-decouple

# Setup directories
mkdir -p /app/{code,config,media,logs}
chown -R app:app /app

# Configure supervisor
cat > /etc/supervisor/supervisord.conf << 'EOF'
[supervisord]
nodaemon=false
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[unix_http_server]
file=/var/run/supervisor.sock

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[include]
files = /etc/supervisor/conf.d/*.conf
EOF

# Configure log rotation
cat > /etc/logrotate.d/app << 'EOF'
/var/log/app/*.log {
    daily
    rotate 6
    compress
    delaycompress
    missingok
    notifempty
    create 0640 app app
    sharedscripts
    postrotate
        supervisorctl reload
    endscript
}
EOF