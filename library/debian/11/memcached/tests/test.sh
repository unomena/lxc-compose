#!/bin/bash
# Memcached Test - Cache operations

echo "=== Memcached Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container name
CONTAINER_NAME="memcached-debian-11"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Memcached container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Memcached Container: $CONTAINER_NAME"
echo "Memcached IP: $CONTAINER_IP"

# Test Memcached is running
echo ""
echo "1. Checking Memcached process..."
lxc exec $CONTAINER_NAME -- pgrep memcached >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Memcached is running"
else
    echo -e "${RED}✗${NC} Memcached is not running"
    exit 1
fi

echo ""
echo "2. Testing Memcached connectivity..."
echo "stats" | nc $CONTAINER_IP 11211 | grep -q "STAT version" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Memcached responding"
else
    echo -e "${RED}✗${NC} Memcached not responding"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Memcached tests passed!${NC}"
