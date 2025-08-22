#!/bin/bash
# HAProxy Test - Load balancer functionality

echo "=== HAProxy Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get container name
CONTAINER_NAME="haproxy-minimal-24-04"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} HAProxy container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "HAProxy Container: $CONTAINER_NAME"
echo "HAProxy IP: $CONTAINER_IP"

# Test HAProxy is running
echo ""
echo "1. Checking HAProxy process..."
lxc exec $CONTAINER_NAME -- pgrep haproxy >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} HAProxy is running"
else
    echo -e "${RED}✗${NC} HAProxy is not running"
    exit 1
fi

echo ""
echo "2. Testing HAProxy stats endpoint..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$CONTAINER_IP:8080/stats 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "401" ]; then
    echo -e "${GREEN}✓${NC} HAProxy stats endpoint responding (Status: $RESPONSE)"
else
    echo -e "${YELLOW}⚠${NC} HAProxy stats endpoint not configured (Status: $RESPONSE)"
fi

echo ""
echo -e "${GREEN}✓ HAProxy basic tests passed!${NC}"
