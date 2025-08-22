#!/bin/bash
# MongoDB Test - NoSQL database operations

echo "=== MongoDB Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container name
CONTAINER_NAME="mongodb-minimal-22-04"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} MongoDB container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "MongoDB Container: $CONTAINER_NAME"
echo "MongoDB IP: $CONTAINER_IP"

# Test MongoDB connectivity
echo ""
echo "1. Testing MongoDB connection..."
lxc exec $CONTAINER_NAME -- mongosh --eval "db.version()" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} MongoDB connection successful"
else
    echo -e "${RED}✗${NC} Failed to connect to MongoDB"
    exit 1
fi

echo ""
echo "2. Creating test document..."
lxc exec $CONTAINER_NAME -- mongosh --eval 'db.test.insertOne({name: "Test Record", value: 123})' >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Document inserted"
else
    echo -e "${RED}✗${NC} Failed to insert document"
    exit 1
fi

echo ""
echo "3. Querying test document..."
RESULT=$(lxc exec $CONTAINER_NAME -- mongosh --quiet --eval 'db.test.findOne({name: "Test Record"}).name' 2>/dev/null)
if [[ "$RESULT" == *"Test Record"* ]]; then
    echo -e "${GREEN}✓${NC} Document retrieved"
else
    echo -e "${RED}✗${NC} Failed to retrieve document"
    exit 1
fi

echo ""
echo "4. Cleaning up..."
lxc exec $CONTAINER_NAME -- mongosh --eval 'db.test.drop()' >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Collection dropped"
else
    echo -e "${RED}✗${NC} Failed to drop collection"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All MongoDB tests passed!${NC}"
