#!/bin/sh
# Startup script for Flask app container
# This script is executed when the container starts

# Start supervisord which will manage Redis and Flask
exec /usr/bin/supervisord -n -c /etc/supervisord.conf