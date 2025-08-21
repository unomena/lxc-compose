#!/bin/sh
# Internal PostgreSQL Health Checks
# Run inside the PostgreSQL container

echo "=== PostgreSQL Internal Health Check ==="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Function to check test result
check_result() {
    if [ $1 -eq 0 ]; then
        echo "${GREEN}✓${NC} $2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "${RED}✗${NC} $2"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Check if PostgreSQL is running
echo "Checking PostgreSQL process..."
if pgrep postgres > /dev/null; then
    check_result 0 "PostgreSQL process is running"
else
    check_result 1 "PostgreSQL process is not running"
fi

# Check if PostgreSQL is ready
echo "Checking PostgreSQL readiness..."
su postgres -c "pg_isready" > /dev/null 2>&1
check_result $? "PostgreSQL is ready to accept connections"

# Check PostgreSQL version
echo "Checking PostgreSQL version..."
VERSION=$(su postgres -c "psql -t -c 'SELECT version();'" 2>/dev/null | head -1)
if [ -n "$VERSION" ]; then
    echo "PostgreSQL version: $(echo $VERSION | cut -d' ' -f2)"
    check_result 0 "PostgreSQL version check"
else
    check_result 1 "Could not determine PostgreSQL version"
fi

# Check data directory
echo "Checking data directory..."
if [ -d /var/lib/postgresql/data ] && [ "$(ls -A /var/lib/postgresql/data)" ]; then
    check_result 0 "Data directory exists and is initialized"
else
    check_result 1 "Data directory not properly initialized"
fi

# Check if we can connect as postgres user
echo "Testing local connection..."
su postgres -c "psql -c 'SELECT 1;'" > /dev/null 2>&1
check_result $? "Can connect locally as postgres user"

# Check default databases exist
echo "Checking default databases..."
for db in development testing production; do
    su postgres -c "psql -lqt | cut -d \| -f 1 | grep -qw $db" 2>/dev/null
    check_result $? "Database '$db' exists"
done

# Check users exist
echo "Checking users..."
su postgres -c "psql -c '\du' | grep -q appuser" 2>/dev/null
check_result $? "Default application user exists"

# Check PostgreSQL is listening on correct port
echo "Checking network binding..."
netstat -tln | grep -q ":5432"
check_result $? "PostgreSQL listening on port 5432"

# Check log file exists
echo "Checking logging..."
if [ -f /var/lib/postgresql/logfile ]; then
    check_result 0 "Log file exists"
else
    check_result 1 "Log file not found"
fi

# Check available connections
echo "Checking connection limits..."
MAX_CONN=$(su postgres -c "psql -t -c 'SHOW max_connections;'" 2>/dev/null | tr -d ' ')
CURRENT_CONN=$(su postgres -c "psql -t -c 'SELECT count(*) FROM pg_stat_activity;'" 2>/dev/null | tr -d ' ')
if [ -n "$MAX_CONN" ] && [ -n "$CURRENT_CONN" ]; then
    echo "  Connections: $CURRENT_CONN / $MAX_CONN"
    check_result 0 "Connection status retrieved"
else
    check_result 1 "Could not retrieve connection status"
fi

# Check disk usage
echo "Checking disk usage..."
DB_SIZE=$(su postgres -c "psql -t -c \"SELECT pg_size_pretty(pg_database_size('postgres'));\"" 2>/dev/null | tr -d ' ')
if [ -n "$DB_SIZE" ]; then
    echo "  Database size: $DB_SIZE"
    check_result 0 "Database size check"
else
    check_result 1 "Could not determine database size"
fi

echo ""
echo "=== Test Summary ==="
echo "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo "${GREEN}✓ All internal tests passed!${NC}"
    exit 0
else
    echo "${RED}✗ Some internal tests failed!${NC}"
    exit 1
fi