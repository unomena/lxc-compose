#!/bin/bash
# Elasticsearch Test - Basic functionality from host

echo "=== Elasticsearch Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list elasticsearch-ubuntu-22-04 -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "Elasticsearch IP: $CONTAINER_IP"
echo ""

# Test 1: Check if Elasticsearch HTTP port is open
echo "1. Testing HTTP port 9200..."
if nc -zv $CONTAINER_IP 9200 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} HTTP port 9200 is open"
else
    echo -e "${RED}✗${NC} HTTP port 9200 is not accessible"
    exit 1
fi

# Test 2: Check cluster health
echo "2. Checking cluster health..."
HEALTH=$(curl -s http://$CONTAINER_IP:9200/_cluster/health | jq -r '.status')
if [ "$HEALTH" = "green" ] || [ "$HEALTH" = "yellow" ]; then
    echo -e "${GREEN}✓${NC} Cluster health: $HEALTH"
else
    echo -e "${RED}✗${NC} Cluster health is $HEALTH"
    exit 1
fi

# Test 3: Create and query index
echo "3. Testing index operations..."

# Create test index
echo "  Creating test index..."
curl -s -X PUT http://$CONTAINER_IP:9200/test-index > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Index created"
else
    echo -e "${RED}✗${NC} Failed to create index"
    exit 1
fi

# Index a document
echo "  Indexing test document..."
curl -s -X POST http://$CONTAINER_IP:9200/test-index/_doc -H 'Content-Type: application/json' -d '{"name":"test","value":123}' > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Document indexed"
else
    echo -e "${RED}✗${NC} Failed to index document"
    exit 1
fi

# Delete test index
echo "  Deleting test index..."
curl -s -X DELETE http://$CONTAINER_IP:9200/test-index > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Index deleted"
else
    echo -e "${RED}✗${NC} Failed to delete index"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Elasticsearch tests passed!${NC}"
exit 0