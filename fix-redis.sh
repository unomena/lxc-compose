#!/bin/bash

#############################################################################
# Fix Redis in existing container
# Usage: ./fix-redis.sh [container_name]
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

# Get container name (default: datastore)
CONTAINER="${1:-datastore}"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   Fix Redis Service                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if container exists
if ! sudo lxc-info -n "$CONTAINER" &>/dev/null; then
    error "Container '$CONTAINER' not found"
fi

# Check if container is running
if ! sudo lxc-info -n "$CONTAINER" | grep -q "RUNNING"; then
    warning "Container '$CONTAINER' is not running, starting it..."
    sudo lxc-start -n "$CONTAINER"
    sleep 5
fi

log "Fixing Redis in container '$CONTAINER'..."

# Fix Redis configuration and start it
sudo lxc-attach -n "$CONTAINER" -- bash -c "
    # Stop any existing Redis processes
    systemctl stop redis-server 2>/dev/null || true
    pkill -f redis-server 2>/dev/null || true
    
    # Fix configuration
    echo 'Fixing Redis configuration...'
    
    # Remove all bind lines and add proper one
    sed -i '/^bind/d' /etc/redis/redis.conf
    echo 'bind 0.0.0.0' >> /etc/redis/redis.conf
    
    # Disable protected mode
    sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
    
    # Comment out supervised directive (causes issues in containers)
    sed -i 's/^supervised/#supervised/' /etc/redis/redis.conf
    
    # Fix permissions
    mkdir -p /var/lib/redis /var/log/redis /var/run/redis
    chown -R redis:redis /var/lib/redis /var/log/redis /var/run/redis
    chmod 750 /var/lib/redis /var/log/redis /var/run/redis
    
    # Try systemctl first
    echo 'Starting Redis service...'
    systemctl enable redis-server 2>/dev/null || true
    
    if systemctl restart redis-server 2>/dev/null; then
        echo 'Redis started via systemctl'
    else
        # Fallback to manual start
        echo 'Starting Redis manually...'
        sudo -u redis redis-server /etc/redis/redis.conf --daemonize yes --pidfile /var/run/redis/redis-server.pid
    fi
    
    # Wait and verify
    sleep 3
    
    # Test Redis
    if redis-cli ping 2>/dev/null | grep -q PONG; then
        echo '✓ Redis is now running!'
        redis-cli info server | grep redis_version
    else
        echo '✗ Redis failed to start'
        exit 1
    fi
"

if [ $? -eq 0 ]; then
    echo ""
    log "Redis fixed successfully!"
    echo ""
    info "Test with: lxc-compose test redis"
    info "Or manually: lxc-compose exec $CONTAINER redis-cli ping"
else
    echo ""
    error "Failed to fix Redis. Check logs with:"
    echo "  lxc-compose exec $CONTAINER journalctl -u redis-server -n 50"
fi