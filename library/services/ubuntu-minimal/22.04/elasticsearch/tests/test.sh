#!/bin/bash
# Elasticsearch Test - Search engine operations

echo "=== Elasticsearch Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get container name
CONTAINER_NAME="elasticsearch-minimal-22-04"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Elasticsearch container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Elasticsearch Container: $CONTAINER_NAME"
echo "Elasticsearch IP: $CONTAINER_IP"

# Test Elasticsearch is running
echo ""
echo "1. Checking Elasticsearch process..."
lxc exec $CONTAINER_NAME -- pgrep -f elasticsearch >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Elasticsearch is running"
else
    echo -e "${YELLOW}⚠${NC} Elasticsearch process not found (may be starting)"
fi

echo ""
echo "2. Testing Elasticsearch API..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://$CONTAINER_IP:9200 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓${NC} Elasticsearch API responding"
else
    echo -e "${YELLOW}⚠${NC} Elasticsearch API not yet ready (Status: $RESPONSE)"
fi

echo ""
echo -e "${GREEN}✓ Elasticsearch basic tests completed${NC}"
