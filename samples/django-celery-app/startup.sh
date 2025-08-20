#!/bin/sh
# Startup script for Django Celery app container
# This script is executed when the container starts

# Start supervisord which will manage Django, Celery, and Celery Beat
exec /usr/bin/supervisord -n -c /etc/supervisord.conf