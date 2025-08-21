#!/bin/bash
# Nginx Test - Basic functionality from host

echo "=== Nginx Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list nginx -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "Nginx IP: $CONTAINER_IP"
echo ""

# Test 1: Check if Nginx responds on port 80
echo "1. Testing HTTP response..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$CONTAINER_IP)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓${NC} Nginx responding with 200 OK"
else
    echo -e "${RED}✗${NC} Nginx returned HTTP $RESPONSE"
    exit 1
fi

# Test 2: Check if default page contains expected content
echo "2. Checking default page content..."
if curl -s http://$CONTAINER_IP | grep -q "Welcome to nginx"; then
    echo -e "${GREEN}✓${NC} Default page content found"
else
    echo -e "${RED}✗${NC} Default page content not found"
    exit 1
fi

# Test 3: Check response headers
echo "3. Checking response headers..."
if curl -sI http://$CONTAINER_IP | grep -q "Server: nginx"; then
    echo -e "${GREEN}✓${NC} Nginx server header present"
else
    echo -e "${RED}✗${NC} Nginx server header missing"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Nginx tests passed!${NC}"
exit 0