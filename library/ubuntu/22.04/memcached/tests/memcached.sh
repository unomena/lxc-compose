#!/bin/bash
# Memcached Test - Basic operations from host

echo "=== Memcached Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list memcached-ubuntu-22-04 -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "Memcached IP: $CONTAINER_IP"
echo ""

# Test 1: Check if Memcached port is open
echo "1. Testing Memcached port 11211..."
if nc -zv $CONTAINER_IP 11211 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} Memcached port 11211 is open"
else
    echo -e "${RED}✗${NC} Memcached port 11211 is not accessible"
    exit 1
fi

# Test 2: Test Memcached operations using telnet-style commands
echo "2. Testing Memcached operations..."

# Set a value
echo "  Setting test value..."
echo -e "set testkey 0 60 5\r\nhello\r" | nc $CONTAINER_IP 11211 | grep -q STORED
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Value stored"
else
    echo -e "${RED}✗${NC} Failed to store value"
    exit 1
fi

# Get the value
echo "  Getting test value..."
RESULT=$(echo -e "get testkey\r" | nc $CONTAINER_IP 11211 | grep -A1 "VALUE testkey" | tail -1)
if [ "$RESULT" = "hello" ]; then
    echo -e "${GREEN}✓${NC} Value retrieved: $RESULT"
else
    echo -e "${RED}✗${NC} Failed to retrieve correct value (got: $RESULT)"
    exit 1
fi

# Delete the value
echo "  Deleting test value..."
echo -e "delete testkey\r" | nc $CONTAINER_IP 11211 | grep -q DELETED
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Value deleted"
else
    echo -e "${RED}✗${NC} Failed to delete value"
    exit 1
fi

# Check stats
echo "3. Checking Memcached stats..."
STATS=$(echo -e "stats\r" | nc $CONTAINER_IP 11211 | grep "STAT version")
if [ -n "$STATS" ]; then
    echo -e "${GREEN}✓${NC} Stats retrieved: $STATS"
else
    echo -e "${RED}✗${NC} Failed to retrieve stats"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Memcached tests passed!${NC}"
exit 0