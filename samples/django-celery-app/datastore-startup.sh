#!/bin/sh
# Startup script for datastore container (PostgreSQL + Redis)
# This script is executed when the container starts

# Start supervisord which will manage PostgreSQL and Redis
exec /usr/bin/supervisord -n -c /etc/supervisord.conf