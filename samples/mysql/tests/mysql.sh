#!/bin/bash
# MySQL Test - Basic CRUD operations from host

echo "=== MySQL Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list mysql -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "MySQL IP: $CONTAINER_IP"
echo ""

# Test 1: Check if MySQL port is open
echo "1. Testing MySQL port 3306..."
if nc -zv $CONTAINER_IP 3306 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} MySQL port 3306 is open"
else
    echo -e "${RED}✗${NC} MySQL port 3306 is not accessible"
    exit 1
fi

# Test 2: Test MySQL connection and operations
echo "2. Testing MySQL operations..."
PASSWORD=${MYSQL_ROOT_PASSWORD:-mysql}

# Create test database
echo "  Creating test database..."
lxc exec mysql -- mysql -u root -p$PASSWORD -e "CREATE DATABASE IF NOT EXISTS testdb;"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Database created"
else
    echo -e "${RED}✗${NC} Failed to create database"
    exit 1
fi

# Create test table
echo "  Creating test table..."
lxc exec mysql -- mysql -u root -p$PASSWORD testdb -e "CREATE TABLE IF NOT EXISTS test_table (id INT PRIMARY KEY, name VARCHAR(50));"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Table created"
else
    echo -e "${RED}✗${NC} Failed to create table"
    exit 1
fi

# Insert test data
echo "  Inserting test data..."
lxc exec mysql -- mysql -u root -p$PASSWORD testdb -e "INSERT INTO test_table VALUES (1, 'test');"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Data inserted"
else
    echo -e "${RED}✗${NC} Failed to insert data"
    exit 1
fi

# Query test data
echo "  Querying test data..."
RESULT=$(lxc exec mysql -- mysql -u root -p$PASSWORD testdb -sN -e "SELECT name FROM test_table WHERE id=1;")
if [ "$RESULT" = "test" ]; then
    echo -e "${GREEN}✓${NC} Data retrieved: $RESULT"
else
    echo -e "${RED}✗${NC} Failed to retrieve correct data"
    exit 1
fi

# Cleanup
echo "  Cleaning up..."
lxc exec mysql -- mysql -u root -p$PASSWORD -e "DROP DATABASE testdb;"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Test database dropped"
else
    echo -e "${RED}✗${NC} Failed to drop database"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All MySQL tests passed!${NC}"
exit 0