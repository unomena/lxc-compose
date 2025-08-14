#!/bin/bash
# Generate supervisor configuration with environment variables

cat <<EOF
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
environment=PATH="/app/venv/bin:/usr/bin",PYTHONPATH="/app/src",DJANGO_SETTINGS_MODULE="config.settings",DEBUG="${DEBUG:-True}",DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY}",DB_NAME="${DB_NAME}",DB_USER="${DB_USER}",DB_PASSWORD="${DB_PASSWORD}",DB_HOST="${DB_HOST}",DB_PORT="${DB_PORT:-5432}",REDIS_HOST="${REDIS_HOST}",REDIS_PORT="${REDIS_PORT:-6379}",ALLOWED_HOSTS="${ALLOWED_HOSTS:-*}"
user=www-data

[program:celery]
command=/app/venv/bin/celery -A config worker -l info
directory=/app/src
autostart=true
autorestart=true
stdout_logfile=/app/logs/celery.log
stderr_logfile=/app/logs/celery_err.log
environment=PATH="/app/venv/bin:/usr/bin",PYTHONPATH="/app/src",DJANGO_SETTINGS_MODULE="config.settings",DEBUG="${DEBUG:-True}",DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY}",DB_NAME="${DB_NAME}",DB_USER="${DB_USER}",DB_PASSWORD="${DB_PASSWORD}",DB_HOST="${DB_HOST}",DB_PORT="${DB_PORT:-5432}",REDIS_HOST="${REDIS_HOST}",REDIS_PORT="${REDIS_PORT:-6379}",ALLOWED_HOSTS="${ALLOWED_HOSTS:-*}"
user=www-data

[program:celery-beat]
command=/app/venv/bin/celery -A config beat -l info
directory=/app/src
autostart=true
autorestart=true
stdout_logfile=/app/logs/celery-beat.log
stderr_logfile=/app/logs/celery-beat_err.log
environment=PATH="/app/venv/bin:/usr/bin",PYTHONPATH="/app/src",DJANGO_SETTINGS_MODULE="config.settings",DEBUG="${DEBUG:-True}",DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY}",DB_NAME="${DB_NAME}",DB_USER="${DB_USER}",DB_PASSWORD="${DB_PASSWORD}",DB_HOST="${DB_HOST}",DB_PORT="${DB_PORT:-5432}",REDIS_HOST="${REDIS_HOST}",REDIS_PORT="${REDIS_PORT:-6379}",ALLOWED_HOSTS="${ALLOWED_HOSTS:-*}"
user=www-data

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/app/logs/nginx.log
stderr_logfile=/app/logs/nginx_err.log
EOF