#!/bin/bash
# Prometheus Test - Metrics collection

echo "=== Prometheus Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container name
CONTAINER_NAME="prometheus-minimal-22-04"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Prometheus container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Prometheus Container: $CONTAINER_NAME"
echo "Prometheus IP: $CONTAINER_IP"

# Test Prometheus is running
echo ""
echo "1. Checking Prometheus process..."
lxc exec $CONTAINER_NAME -- pgrep prometheus >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Prometheus is running"
else
    echo -e "${RED}✗${NC} Prometheus is not running"
    exit 1
fi

echo ""
echo "2. Testing Prometheus API..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$CONTAINER_IP:9090/-/healthy 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓${NC} Prometheus API healthy"
else
    echo -e "${RED}✗${NC} Prometheus API not responding (Status: $RESPONSE)"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Prometheus tests passed!${NC}"
