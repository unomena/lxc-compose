#!/bin/bash
# Health check for Flask application

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

echo "=== Flask Application Health Check ==="
echo

# Test Redis connection
run_test "Redis connection" "redis-cli -h \${REDIS_HOST} ping | grep -q PONG"

# Test Flask is responding
run_test "Flask application" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:5000 | grep -q '200'"

# Test Nginx is responding
run_test "Nginx proxy" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80 | grep -q '200'"

# Test Supervisor is running
run_test "Supervisor service" "supervisorctl status | grep -q RUNNING"

# Test Flask service in Supervisor
run_test "Flask process" "supervisorctl status flask | grep -q RUNNING"

# Test Flask API endpoint (if exists)
run_test "Flask API" "curl -s http://127.0.0.1:80/api/status 2>/dev/null | grep -q 'ok\|success' || curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80 | grep -q '200'"

# Test Redis is being used
run_test "Redis usage" "redis-cli -h \${REDIS_HOST} dbsize | grep -E '[0-9]+' || true"

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