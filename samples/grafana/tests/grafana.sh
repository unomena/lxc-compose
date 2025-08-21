#!/bin/bash
# Grafana Test - Basic functionality from host

echo "=== Grafana Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list grafana -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "Grafana IP: $CONTAINER_IP"
echo ""

# Test 1: Check if Grafana port is open
echo "1. Testing Grafana port 3000..."
if nc -zv $CONTAINER_IP 3000 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} Grafana port 3000 is open"
else
    echo -e "${RED}✗${NC} Grafana port 3000 is not accessible"
    exit 1
fi

# Test 2: Check login page
echo "2. Testing login page..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$CONTAINER_IP:3000/login)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓${NC} Login page accessible"
else
    echo -e "${RED}✗${NC} Login page returned HTTP $RESPONSE"
    exit 1
fi

# Test 3: Check API health
echo "3. Testing API health..."
HEALTH=$(curl -s http://$CONTAINER_IP:3000/api/health | jq -r '.database')
if [ "$HEALTH" = "ok" ]; then
    echo -e "${GREEN}✓${NC} API health check passed"
else
    echo -e "${RED}✗${NC} API health check failed"
    exit 1
fi

# Test 4: Check Grafana process
echo "4. Checking Grafana process..."
if lxc exec grafana -- pgrep grafana > /dev/null; then
    echo -e "${GREEN}✓${NC} Grafana process is running"
else
    echo -e "${RED}✗${NC} Grafana process not found"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Grafana tests passed!${NC}"
exit 0