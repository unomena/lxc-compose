#!/bin/bash
# Health check for Django + Celery application

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

echo "=== Django + Celery Health Check ==="
echo

# Test PostgreSQL connection
run_test "PostgreSQL connection" "PGPASSWORD=\${DB_PASSWORD} psql -h \${DB_HOST} -U \${DB_USER} -d \${DB_NAME} -c 'SELECT 1'"

# Test Redis connection
run_test "Redis connection" "redis-cli -h \${REDIS_HOST} ping | grep -q PONG"

# Test Django is responding
run_test "Django application" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000 | grep -q '200\|301\|302'"

# Test Nginx is responding
run_test "Nginx proxy" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80 | grep -q '200\|301\|302'"

# Test Supervisor is running
run_test "Supervisor service" "supervisorctl status | grep -q RUNNING"

# Test Django service in Supervisor
run_test "Django process" "supervisorctl status django | grep -q RUNNING"

# Test Celery worker
run_test "Celery worker" "supervisorctl status celery | grep -q RUNNING"

# Test Celery beat
run_test "Celery beat" "supervisorctl status celery-beat | grep -q RUNNING"

# Test Django admin accessible
run_test "Django admin" "curl -s http://127.0.0.1:80/admin/ | grep -q 'Django administration'"

# Test static files
run_test "Static files" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80/static/admin/css/base.css | grep -q '200'"

echo
echo "=== Test Summary ==="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi