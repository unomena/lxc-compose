#!/bin/sh
# Startup script for Django minimal container
# This script is executed when the container starts

# Start supervisord which will manage PostgreSQL and Django
exec /usr/bin/supervisord -n -c /etc/supervisord.conf