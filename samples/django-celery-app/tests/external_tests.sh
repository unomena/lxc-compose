#!/bin/bash
# External health checks for Django + Celery application
# These tests run from the host machine against container IPs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Get container IPs from lxc list
APP_IP=$(lxc list sample-django-app -c 4 --format csv | cut -d' ' -f1)
DATASTORE_IP=$(lxc list sample-datastore -c 4 --format csv | cut -d' ' -f1)

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

echo "=== Django + Celery External Health Check ==="
echo "App Container IP: ${APP_IP}"
echo "Datastore Container IP: ${DATASTORE_IP}"
echo

# Test if containers are running
run_test "App container running" "lxc list sample-django-app --format csv | grep -q RUNNING"
run_test "Datastore container running" "lxc list sample-datastore --format csv | grep -q RUNNING"

# Test APP CONTAINER exposed ports (only Nginx should be exposed)
if [ -n "$APP_IP" ]; then
    echo -e "\n${YELLOW}Testing App Container (${APP_IP})${NC}"
    
    # Test Nginx on port 80 (the only exposed port for this container)
    run_test "Nginx accessible (port 80)" "curl -s -o /dev/null -w '%{http_code}' http://${APP_IP}:80 | grep -q '200\|301\|302'"
    
    # Test Django admin through Nginx
    run_test "Django admin page via Nginx" "curl -s http://${APP_IP}:80/admin/ | grep -q 'Django administration'"
    
    # Test static files served by Nginx
    run_test "Static files via Nginx" "curl -s -o /dev/null -w '%{http_code}' http://${APP_IP}:80/static/admin/css/base.css | grep -q '200\|304'"
    
    # Test that Django port 8000 is NOT accessible from host (internal only)
    echo -n "Testing Django port 8000 NOT exposed... "
    if ! nc -zv ${APP_IP} 8000 2>&1 | grep -q 'succeeded\|open'; then
        echo -e "${GREEN}✓${NC} PASSED (correctly not exposed)"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} FAILED (port 8000 should not be exposed)"
        ((TESTS_FAILED++))
    fi
    
    # Test application response time
    RESPONSE_TIME=$(curl -s -o /dev/null -w '%{time_total}' http://${APP_IP}:80)
    if (( $(echo "$RESPONSE_TIME < 2.0" | bc -l) )); then
        echo -e "Response time... ${GREEN}✓${NC} PASSED (${RESPONSE_TIME}s)"
        ((TESTS_PASSED++))
    else
        echo -e "Response time... ${YELLOW}⚠${NC} SLOW (${RESPONSE_TIME}s)"
    fi
else
    echo -e "${RED}App container IP not found!${NC}"
fi

# Test DATASTORE CONTAINER - PostgreSQL and Redis should be accessible from containers
# but in this setup they're exposed for development purposes
if [ -n "$DATASTORE_IP" ]; then
    echo -e "\n${YELLOW}Testing Datastore Container (${DATASTORE_IP})${NC}"
    
    # Test PostgreSQL port 5432 (exposed for development)
    run_test "PostgreSQL port open (5432)" "nc -zv ${DATASTORE_IP} 5432 2>&1 | grep -q 'succeeded\|open'"
    
    # Test Redis port 6379 (exposed for development)
    run_test "Redis port open (6379)" "nc -zv ${DATASTORE_IP} 6379 2>&1 | grep -q 'succeeded\|open'"
    
    # Test Redis PING command
    run_test "Redis responds to PING" "echo 'PING' | nc ${DATASTORE_IP} 6379 | grep -q '+PONG'"
    
    # Note about security
    echo -e "${YELLOW}Note: PostgreSQL and Redis ports are exposed for development.${NC}"
    echo -e "${YELLOW}      In production, these should only be accessible from app containers.${NC}"
else
    echo -e "${RED}Datastore container IP not found!${NC}"
fi

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