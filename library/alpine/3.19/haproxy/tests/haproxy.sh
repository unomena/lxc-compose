#!/bin/bash
# HAProxy Test - Basic functionality from host

echo "=== HAProxy Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list haproxy-alpine-3-19 -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "HAProxy IP: $CONTAINER_IP"
echo ""

# Test 1: Check if HAProxy responds on port 80
echo "1. Testing HTTP port 80..."
if nc -zv $CONTAINER_IP 80 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} HAProxy port 80 is open"
else
    echo -e "${RED}✗${NC} HAProxy port 80 is not accessible"
    exit 1
fi

# Test 2: Check stats page
echo "2. Testing stats page..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$CONTAINER_IP/stats)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓${NC} Stats page accessible"
else
    echo -e "${RED}✗${NC} Stats page returned HTTP $RESPONSE"
    exit 1
fi

# Test 3: Check HAProxy process
echo "3. Checking HAProxy process..."
if lxc exec haproxy-alpine-3-19 -- pgrep haproxy-alpine-3-19 > /dev/null; then
    echo -e "${GREEN}✓${NC} HAProxy process is running"
else
    echo -e "${RED}✗${NC} HAProxy process not found"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All HAProxy tests passed!${NC}"
exit 0