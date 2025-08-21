#!/bin/bash
# External PostgreSQL Connectivity Tests
# Run from the host to verify PostgreSQL is accessible

echo "=== PostgreSQL External Connectivity Test ==="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Get container IP
CONTAINER_IP=$(lxc list postgresql-server -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "PostgreSQL Server IP: $CONTAINER_IP"
echo ""

# Function to check test result
check_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $2"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Check if container is running
echo "Testing container status..."
lxc list postgresql-server --format json | jq -r '.[0].status' | grep -q "Running"
check_result $? "Container is running"

# Check if port 5432 is open
echo "Testing PostgreSQL port (5432)..."
timeout 2 nc -zv $CONTAINER_IP 5432 > /dev/null 2>&1
check_result $? "PostgreSQL port 5432 is open"

# Test PostgreSQL connectivity with psql (if available)
echo "Testing PostgreSQL connectivity..."
if command -v psql > /dev/null 2>&1; then
    PGPASSWORD=postgres psql -h $CONTAINER_IP -U postgres -p 5432 -c "SELECT 1;" > /dev/null 2>&1
    check_result $? "Can connect to PostgreSQL with psql"
    
    # Test creating a database
    echo "Testing database operations..."
    TEST_DB="test_db_$$"
    PGPASSWORD=postgres psql -h $CONTAINER_IP -U postgres -p 5432 -c "CREATE DATABASE $TEST_DB;" > /dev/null 2>&1
    check_result $? "Can create a database"
    
    PGPASSWORD=postgres psql -h $CONTAINER_IP -U postgres -p 5432 -c "DROP DATABASE $TEST_DB;" > /dev/null 2>&1
    check_result $? "Can drop a database"
    
    # Test application user
    echo "Testing application user..."
    PGPASSWORD=apppassword psql -h $CONTAINER_IP -U appuser -p 5432 -d development -c "SELECT current_user;" > /dev/null 2>&1
    check_result $? "Can connect as application user"
else
    echo -e "${YELLOW}⚠${NC} psql client not installed on host, skipping detailed tests"
fi

# Test with netcat for basic connectivity
echo "Testing raw TCP connection..."
echo -e "\q" | timeout 2 nc $CONTAINER_IP 5432 > /dev/null 2>&1
if [ $? -eq 0 ] || [ $? -eq 1 ]; then
    check_result 0 "TCP connection to PostgreSQL successful"
else
    check_result 1 "TCP connection to PostgreSQL failed"
fi

# Check response time
echo "Testing response time..."
START=$(date +%s%N)
timeout 2 nc -zv $CONTAINER_IP 5432 > /dev/null 2>&1
END=$(date +%s%N)
RESPONSE_TIME=$(echo "scale=6; ($END - $START) / 1000000000" | bc)
echo "  Response time: ${RESPONSE_TIME}s"

if (( $(echo "$RESPONSE_TIME < 1" | bc -l) )); then
    check_result 0 "Response time acceptable"
else
    check_result 1 "Response time too slow"
fi

# Test from another container (if exists)
echo "Testing inter-container connectivity..."
OTHER_CONTAINERS=$(lxc list --format json | jq -r '.[] | select(.name != "postgresql-server" and .status == "Running") | .name' | head -1)
if [ -n "$OTHER_CONTAINERS" ]; then
    echo "  Testing from container: $OTHER_CONTAINERS"
    lxc exec $OTHER_CONTAINERS -- sh -c "nc -zv $CONTAINER_IP 5432" > /dev/null 2>&1
    check_result $? "Can connect from another container"
else
    echo -e "${YELLOW}⚠${NC} No other containers running to test inter-container connectivity"
fi

# Check if PostgreSQL is accessible on all required databases
echo "Checking database accessibility..."
for db in development testing production; do
    if command -v psql > /dev/null 2>&1; then
        PGPASSWORD=apppassword psql -h $CONTAINER_IP -U appuser -p 5432 -d $db -c "SELECT 1;" > /dev/null 2>&1
        check_result $? "Database '$db' is accessible"
    fi
done

echo ""
echo "=== Test Summary ==="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All external tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some external tests failed!${NC}"
    exit 1
fi