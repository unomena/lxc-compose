#!/bin/sh
# Test supervisor installation and configuration

echo "Testing Supervisor installation..."

# Check if supervisor is installed
if ! command -v supervisord >/dev/null 2>&1; then
    echo "ERROR: supervisord not found"
    exit 1
fi

if ! command -v supervisorctl >/dev/null 2>&1; then
    echo "ERROR: supervisorctl not found"
    exit 1
fi

# Check configuration file
if [ ! -f /etc/supervisord.conf ]; then
    echo "ERROR: /etc/supervisord.conf not found"
    exit 1
fi

# Check directories
if [ ! -d /etc/supervisor.d ]; then
    echo "ERROR: /etc/supervisor.d directory not found"
    exit 1
fi

if [ ! -d /var/log/supervisor ]; then
    echo "ERROR: /var/log/supervisor directory not found"
    exit 1
fi

# Test starting supervisor
supervisord -v
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to get supervisor version"
    exit 1
fi

echo "✓ Supervisor is properly installed and configured"
exit 0