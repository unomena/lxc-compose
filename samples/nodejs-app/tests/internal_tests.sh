#!/bin/bash
# Health check for Node.js application

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

echo "=== Node.js Application Health Check ==="
echo

# Test MongoDB connection
run_test "MongoDB connection" "curl -s \${MONGO_HOST}:27017 | grep -q 'It looks like you are trying to access MongoDB'"

# Test Node.js is responding
run_test "Node.js application" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000 | grep -q '200'"

# Test Nginx is responding
run_test "Nginx proxy" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80 | grep -q '200'"

# Test Supervisor is running
run_test "Supervisor service" "supervisorctl status | grep -q RUNNING"

# Test Node.js service in Supervisor
run_test "Node.js process" "supervisorctl status nodejs | grep -q RUNNING"

# Test Node.js API endpoint (if exists)
run_test "Node.js API" "curl -s http://127.0.0.1:80/api/health 2>/dev/null | grep -q 'ok\|healthy' || curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80 | grep -q '200'"

# Test Node and NPM are installed
run_test "Node.js installed" "node --version | grep -q 'v[0-9]'"
run_test "NPM installed" "npm --version | grep -q '[0-9]'"

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