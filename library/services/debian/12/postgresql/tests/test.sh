#!/bin/bash
# PostgreSQL Test - Basic CRUD operations from host
# Tests database creation, table operations, and cleanup

echo "=== PostgreSQL Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container name - check which one exists
CONTAINER_NAME=""
for name in postgresql-debian-12 postgresql-debian-12ql-server; do
    if lxc info $name >/dev/null 2>&1; then
        CONTAINER_NAME=$name
        break
    fi
done

if [ -z "$CONTAINER_NAME" ]; then
    echo -e "${RED}✗${NC} PostgreSQL container not found (tried: postgresql-debian-12, postgresql-debian-12ql-server)"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "PostgreSQL Container: $CONTAINER_NAME"
echo "PostgreSQL IP: $CONTAINER_IP"

# Test using lxc exec to run psql commands
echo ""
echo "1. Creating test database..."
lxc exec $CONTAINER_NAME -- su postgres -c "createdb testdb"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Database created"
else
    echo -e "${RED}✗${NC} Failed to create database"
    exit 1
fi

echo ""
echo "2. Creating test table..."
lxc exec $CONTAINER_NAME -- su postgres -c "psql -d testdb -c 'CREATE TABLE test_table (id SERIAL PRIMARY KEY, name VARCHAR(50), created_at TIMESTAMP DEFAULT NOW());'"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Table created"
else
    echo -e "${RED}✗${NC} Failed to create table"
    exit 1
fi

echo ""
echo "3. Inserting test record..."
lxc exec $CONTAINER_NAME -- su postgres -c "psql -d testdb -c \"INSERT INTO test_table (name) VALUES ('Test Record');\""
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Record inserted"
else
    echo -e "${RED}✗${NC} Failed to insert record"
    exit 1
fi

echo ""
echo "4. Querying test record..."
RESULT=$(lxc exec $CONTAINER_NAME -- su postgres -c "psql -d testdb -t -c \"SELECT name FROM test_table WHERE name='Test Record';\"" | tr -d ' ')
if [ "$RESULT" = "TestRecord" ]; then
    echo -e "${GREEN}✓${NC} Record found: $RESULT"
else
    echo -e "${RED}✗${NC} Failed to query record"
    exit 1
fi

echo ""
echo "5. Deleting test record..."
lxc exec $CONTAINER_NAME -- su postgres -c "psql -d testdb -c \"DELETE FROM test_table WHERE name='Test Record';\""
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Record deleted"
else
    echo -e "${RED}✗${NC} Failed to delete record"
    exit 1
fi

echo ""
echo "6. Dropping test table..."
lxc exec $CONTAINER_NAME -- su postgres -c "psql -d testdb -c 'DROP TABLE test_table;'"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Table dropped"
else
    echo -e "${RED}✗${NC} Failed to drop table"
    exit 1
fi

echo ""
echo "7. Dropping test database..."
lxc exec $CONTAINER_NAME -- su postgres -c "dropdb testdb"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Database dropped"
else
    echo -e "${RED}✗${NC} Failed to drop database"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All PostgreSQL tests passed!${NC}"
exit 0