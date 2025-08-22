#!/bin/bash
# Nginx Test - Web server functionality

echo "=== Nginx Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container name
CONTAINER_NAME="nginx-minimal-22-04"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Nginx container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Nginx Container: $CONTAINER_NAME"
echo "Nginx IP: $CONTAINER_IP"

# Test Nginx is running
echo ""
echo "1. Checking Nginx process..."
lxc exec $CONTAINER_NAME -- pgrep nginx >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Nginx is running"
else
    echo -e "${RED}✗${NC} Nginx is not running"
    exit 1
fi

echo ""
echo "2. Testing HTTP connection..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$CONTAINER_IP/)
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "404" ]; then
    echo -e "${GREEN}✓${NC} HTTP server responding (Status: $RESPONSE)"
else
    echo -e "${RED}✗${NC} HTTP server not responding (Status: $RESPONSE)"
    exit 1
fi

echo ""
echo "3. Testing Nginx configuration..."
lxc exec $CONTAINER_NAME -- nginx -t 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Nginx configuration valid"
else
    echo -e "${RED}✗${NC} Nginx configuration invalid"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Nginx tests passed!${NC}"
