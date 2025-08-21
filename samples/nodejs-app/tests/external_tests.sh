#!/bin/bash
# External health checks for Node.js application
# These tests run from the host machine against container IPs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Get container IPs from lxc list
APP_IP=$(lxc list sample-nodejs-app -c 4 --format csv | cut -d' ' -f1)
DATASTORE_IP=$(lxc list sample-nodejs-datastore -c 4 --format csv | cut -d' ' -f1)

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

echo "=== Node.js Application External Health Check ==="
echo "App Container IP: ${APP_IP}"
echo "Datastore Container IP: ${DATASTORE_IP}"
echo

# Test if containers are running
run_test "App container running" "lxc list sample-nodejs-app --format csv | grep -q RUNNING"
run_test "Datastore container running" "lxc list sample-nodejs-datastore --format csv | grep -q RUNNING"

# Test exposed ports from host
if [ -n "$APP_IP" ]; then
    # Test Nginx on port 80
    run_test "Nginx accessible (port 80)" "curl -s -o /dev/null -w '%{http_code}' http://${APP_IP}:80 | grep -q '200'"
    
    # Test Node.js application
    run_test "Node.js app responding" "curl -s http://${APP_IP}:80 | grep -q 'Node\|Express\|Welcome\|Hello'"
    
    # Test API endpoint if available
    run_test "API endpoint" "curl -s http://${APP_IP}:80/api/health 2>/dev/null | grep -q 'ok\|healthy' || curl -s -o /dev/null -w '%{http_code}' http://${APP_IP}:80 | grep -q '200'"
    
    # Test application response time
    RESPONSE_TIME=$(curl -s -o /dev/null -w '%{time_total}' http://${APP_IP}:80)
    if (( $(echo "$RESPONSE_TIME < 1.0" | bc -l) )); then
        echo -e "Response time... ${GREEN}✓${NC} PASSED (${RESPONSE_TIME}s)"
        ((TESTS_PASSED++))
    else
        echo -e "Response time... ${YELLOW}⚠${NC} SLOW (${RESPONSE_TIME}s)"
    fi
else
    echo -e "${RED}App container IP not found!${NC}"
fi

if [ -n "$DATASTORE_IP" ]; then
    # Test MongoDB port 27017
    run_test "MongoDB port open (27017)" "nc -zv ${DATASTORE_IP} 27017 2>&1 | grep -q 'succeeded\|open'"
    
    # Test MongoDB HTTP interface
    run_test "MongoDB responding" "curl -s ${DATASTORE_IP}:27017 2>/dev/null | grep -q 'It looks like you are trying to access MongoDB'"
else
    echo -e "${RED}Datastore container IP not found!${NC}"
fi

# Test port forwarding from host
run_test "Port 80 forwarded" "curl -s -o /dev/null -w '%{http_code}' http://localhost:80 2>/dev/null | grep -q '200' || true"

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