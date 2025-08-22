#!/bin/bash
# MySQL Test - Basic CRUD operations from host

echo "=== MySQL Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container name
CONTAINER_NAME="mysql-debian-12"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} MySQL container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "MySQL Container: $CONTAINER_NAME"
echo "MySQL IP: $CONTAINER_IP"

# Test MySQL connectivity
echo ""
echo "1. Testing MySQL connection..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot -e "SELECT VERSION();" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} MySQL connection successful"
else
    echo -e "${RED}✗${NC} Failed to connect to MySQL"
    exit 1
fi

echo ""
echo "2. Creating test database..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot -e "CREATE DATABASE testdb;"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Database created"
else
    echo -e "${RED}✗${NC} Failed to create database"
    exit 1
fi

echo ""
echo "3. Creating test table..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot testdb -e "CREATE TABLE test_table (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(50));"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Table created"
else
    echo -e "${RED}✗${NC} Failed to create table"
    exit 1
fi

echo ""
echo "4. Inserting test data..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot testdb -e "INSERT INTO test_table (name) VALUES ('Test Record');"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Data inserted"
else
    echo -e "${RED}✗${NC} Failed to insert data"
    exit 1
fi

echo ""
echo "5. Querying test data..."
RESULT=$(lxc exec $CONTAINER_NAME -- mysql -uroot -proot testdb -se "SELECT name FROM test_table WHERE name='Test Record';")
if [ "$RESULT" = "Test Record" ]; then
    echo -e "${GREEN}✓${NC} Data retrieved: $RESULT"
else
    echo -e "${RED}✗${NC} Failed to retrieve data"
    exit 1
fi

echo ""
echo "6. Cleaning up..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot -e "DROP DATABASE testdb;"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Database dropped"
else
    echo -e "${RED}✗${NC} Failed to drop database"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All MySQL tests passed!${NC}"
