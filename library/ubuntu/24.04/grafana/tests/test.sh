#!/bin/bash
# Grafana Test - Monitoring dashboard

echo "=== Grafana Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container name
CONTAINER_NAME="grafana-ubuntu-24-04"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Grafana container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Grafana Container: $CONTAINER_NAME"
echo "Grafana IP: $CONTAINER_IP"

# Test Grafana is running
echo ""
echo "1. Checking Grafana process..."
lxc exec $CONTAINER_NAME -- pgrep grafana >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Grafana is running"
else
    echo -e "${RED}✗${NC} Grafana is not running"
    exit 1
fi

echo ""
echo "2. Testing Grafana web interface..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$CONTAINER_IP:3000 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "302" ]; then
    echo -e "${GREEN}✓${NC} Grafana web interface responding (Status: $RESPONSE)"
else
    echo -e "${RED}✗${NC} Grafana web interface not responding (Status: $RESPONSE)"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Grafana tests passed!${NC}"
