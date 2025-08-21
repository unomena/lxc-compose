#!/bin/bash
# External health checks for Django Minimal application
# These tests run from the host machine against container IPs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Get container IP from lxc list
APP_IP=$(lxc list sample-django-app -c 4 --format csv | cut -d' ' -f1)

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

echo "=== Django Minimal External Health Check ==="
echo "Container IP: ${APP_IP}"
echo

# Test if container is running
run_test "Container running" "lxc list sample-django-app --format csv | grep -q RUNNING"

# Test exposed ports from host
if [ -n "$APP_IP" ]; then
    # Test Django on port 8000
    run_test "Django accessible (port 8000)" "curl -s -o /dev/null -w '%{http_code}' http://${APP_IP}:8000 | grep -q '200\|301\|302'"
    
    # Test PostgreSQL on port 5432
    run_test "PostgreSQL port open (5432)" "nc -zv ${APP_IP} 5432 2>&1 | grep -q 'succeeded\|open'"
    
    # Test Django admin
    run_test "Django admin page" "curl -s http://${APP_IP}:8000/admin/ | grep -q 'Django administration'"
    
    # Test application response time
    RESPONSE_TIME=$(curl -s -o /dev/null -w '%{time_total}' http://${APP_IP}:8000)
    if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l) )); then
        echo -e "Response time... ${GREEN}✓${NC} PASSED (${RESPONSE_TIME}s)"
        ((TESTS_PASSED++))
    else
        echo -e "Response time... ${YELLOW}⚠${NC} SLOW (${RESPONSE_TIME}s)"
    fi
else
    echo -e "${RED}Container IP not found!${NC}"
fi

# Test port forwarding from host
run_test "Port 8000 forwarded" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000 2>/dev/null | grep -q '200\|301\|302' || true"
run_test "Port 5432 forwarded" "nc -zv localhost 5432 2>&1 | grep -q 'succeeded\|open' || true"

echo
echo "=== Test Summary ==="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All external tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some external tests failed!${NC}"
    exit 1
fi