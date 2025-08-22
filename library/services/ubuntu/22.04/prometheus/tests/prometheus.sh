#!/bin/bash
# Prometheus Test - Basic functionality from host

echo "=== Prometheus Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list prometheus-ubuntu-22-04 -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "Prometheus IP: $CONTAINER_IP"
echo ""

# Test 1: Check if Prometheus port is open
echo "1. Testing Prometheus port 9090..."
if nc -zv $CONTAINER_IP 9090 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} Prometheus port 9090 is open"
else
    echo -e "${RED}✗${NC} Prometheus port 9090 is not accessible"
    exit 1
fi

# Test 2: Check Prometheus UI
echo "2. Testing Prometheus UI..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$CONTAINER_IP:9090/)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓${NC} Prometheus UI accessible"
else
    echo -e "${RED}✗${NC} Prometheus UI returned HTTP $RESPONSE"
    exit 1
fi

# Test 3: Check API health
echo "3. Testing API health..."
READY=$(curl -s http://$CONTAINER_IP:9090/-/ready)
if [ "$READY" = "Prometheus is Ready." ]; then
    echo -e "${GREEN}✓${NC} Prometheus is ready"
else
    echo -e "${RED}✗${NC} Prometheus not ready"
    exit 1
fi

# Test 4: Query metrics
echo "4. Testing metrics query..."
RESULT=$(curl -s "http://$CONTAINER_IP:9090/api/v1/query?query=up" | jq -r '.status')
if [ "$RESULT" = "success" ]; then
    echo -e "${GREEN}✓${NC} Metrics query successful"
else
    echo -e "${RED}✗${NC} Metrics query failed"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Prometheus tests passed!${NC}"
exit 0