#!/bin/bash
# MongoDB Test - Basic operations from host

echo "=== MongoDB Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list mongodb -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "MongoDB IP: $CONTAINER_IP"
echo ""

# Test 1: Check if MongoDB port is open
echo "1. Testing MongoDB port 27017..."
if nc -zv $CONTAINER_IP 27017 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} MongoDB port 27017 is open"
else
    echo -e "${RED}✗${NC} MongoDB port 27017 is not accessible"
    exit 1
fi

# Test 2: Test MongoDB operations
echo "2. Testing MongoDB operations..."

# Insert test document
echo "  Inserting test document..."
lxc exec mongodb -- mongosh --eval "db.test.insertOne({name: 'test', value: 123})" testdb > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Document inserted"
else
    echo -e "${RED}✗${NC} Failed to insert document"
    exit 1
fi

# Query test document
echo "  Querying test document..."
RESULT=$(lxc exec mongodb -- mongosh --quiet --eval "db.test.findOne({name: 'test'}).value" testdb 2>/dev/null)
if [ "$RESULT" = "123" ]; then
    echo -e "${GREEN}✓${NC} Document retrieved: value=$RESULT"
else
    echo -e "${RED}✗${NC} Failed to retrieve correct document"
    exit 1
fi

# Count documents
echo "  Counting documents..."
COUNT=$(lxc exec mongodb -- mongosh --quiet --eval "db.test.countDocuments()" testdb 2>/dev/null)
if [ "$COUNT" -ge "1" ]; then
    echo -e "${GREEN}✓${NC} Document count: $COUNT"
else
    echo -e "${RED}✗${NC} Document count incorrect"
    exit 1
fi

# Cleanup
echo "  Cleaning up..."
lxc exec mongodb -- mongosh --eval "db.dropDatabase()" testdb > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Test database dropped"
else
    echo -e "${RED}✗${NC} Failed to drop database"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All MongoDB tests passed!${NC}"
exit 0