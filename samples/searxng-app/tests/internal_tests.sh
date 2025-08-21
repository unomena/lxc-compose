#!/bin/bash
# Health check for SearXNG application

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

echo "=== SearXNG Health Check ==="
echo

# Test Redis connection
run_test "Redis connection" "redis-cli ping | grep -q PONG"

# Test SearXNG is responding via uWSGI
run_test "SearXNG application" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8888 | grep -q '200'"

# Test Nginx is responding
run_test "Nginx proxy" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80 | grep -q '200'"

# Test Supervisor is running
run_test "Supervisor service" "supervisorctl status | grep -q RUNNING"

# Test SearXNG service in Supervisor
run_test "SearXNG process" "supervisorctl status searxng | grep -q RUNNING"

# Test search functionality
run_test "Search endpoint" "curl -s 'http://127.0.0.1:80/search?q=test' | grep -q 'SearXNG\|results\|search'"

# Test static files
run_test "Static files" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80/static/themes/simple/css/searxng.min.css | grep -q '200\|304'"

# Test preferences page
run_test "Preferences page" "curl -s http://127.0.0.1:80/preferences | grep -q 'Preferences'"

# Test uWSGI socket exists
run_test "uWSGI socket" "test -S /usr/local/searxng/searxng-src/searxng.sock"

# Test SearXNG config is loaded
run_test "SearXNG config" "test -f /etc/searxng/settings.yml"

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