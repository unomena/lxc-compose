#!/bin/bash
# Internal health checks for sample-datastore container
# Tests PostgreSQL and Redis services running inside the container

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Testing $test_name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "=== Datastore Container Internal Health Check ==="
echo

# Test PostgreSQL is running
run_test "PostgreSQL process" "ps aux | grep -v grep | grep postgres"

# Test PostgreSQL is listening on port 5432
run_test "PostgreSQL port 5432" "netstat -tln | grep :5432 || ss -tln | grep :5432"

# Test PostgreSQL can be connected to locally
run_test "PostgreSQL local connection" "su postgres -c 'psql -c \"SELECT 1\"'"

# Test database exists
run_test "Database exists" "su postgres -c \"psql -lqt | cut -d '|' -f 1 | grep -qw \${DB_NAME}\""

# Test database user exists
run_test "Database user exists" "su postgres -c \"psql -c \\\"SELECT 1 FROM pg_user WHERE usename='\${DB_USER}'\\\" | grep -q 1\""

# Test database user can connect
run_test "Database user connection" "PGPASSWORD=\${DB_PASSWORD} psql -h localhost -U \${DB_USER} -d \${DB_NAME} -c 'SELECT 1'"

# Test Redis is running
run_test "Redis process" "ps aux | grep -v grep | grep redis-server"

# Test Redis is listening on port 6379
run_test "Redis port 6379" "netstat -tln | grep :6379 || ss -tln | grep :6379"

# Test Redis can be connected to
run_test "Redis connection" "redis-cli ping | grep -q PONG"

# Test Redis is accepting commands
run_test "Redis SET command" "redis-cli SET test_key test_value | grep -q OK"
run_test "Redis GET command" "redis-cli GET test_key | grep -q test_value"
run_test "Redis DEL command" "redis-cli DEL test_key | grep -q 1"

# Check PostgreSQL log file exists
run_test "PostgreSQL log exists" "test -f /var/lib/postgresql/logfile"

# Check Redis log file exists
run_test "Redis log exists" "test -f /var/log/redis/redis.log"

# Test PostgreSQL accepts connections from network
run_test "PostgreSQL network binding" "grep -q \"listen_addresses = '\\*'\" /var/lib/postgresql/data/postgresql.conf"

# Test Redis accepts connections from network
run_test "Redis network binding" "grep -q \"bind 0.0.0.0\" /etc/redis.conf"

echo
echo "=== Test Summary ==="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All datastore tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some datastore tests failed!${NC}"
    exit 1
fi