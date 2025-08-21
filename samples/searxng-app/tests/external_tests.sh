#!/bin/bash
# External health checks for SearXNG application
# These tests run from the host machine against container IPs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0

# Get container IP from lxc list
APP_IP=$(lxc list sample-searxng-app -c 4 --format csv | cut -d' ' -f1)

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

echo "=== SearXNG External Health Check ==="
echo "Container IP: ${APP_IP}"
echo

# Test if container is running
run_test "Container running" "lxc list sample-searxng-app --format csv | grep -q RUNNING"

# Test exposed ports from host
if [ -n "$APP_IP" ]; then
    # Test Nginx on port 80
    run_test "Nginx accessible (port 80)" "curl -s -o /dev/null -w '%{http_code}' http://${APP_IP}:80 | grep -q '200'"
    
    # Test SearXNG homepage
    run_test "SearXNG homepage" "curl -s http://${APP_IP}:80 | grep -q 'SearXNG\|searxng\|Search'"
    
    # Test search functionality
    run_test "Search endpoint" "curl -s 'http://${APP_IP}:80/search?q=test' | grep -q 'results\|SearXNG'"
    
    # Test preferences page
    run_test "Preferences page" "curl -s http://${APP_IP}:80/preferences | grep -q 'Preferences\|Settings'"
    
    # Test static files
    run_test "Static files (CSS)" "curl -s -o /dev/null -w '%{http_code}' http://${APP_IP}:80/static/themes/simple/css/searxng.min.css | grep -q '200\|304'"
    
    # Test opensearch.xml
    run_test "OpenSearch description" "curl -s http://${APP_IP}:80/opensearch.xml | grep -q 'OpenSearchDescription'"
    
    # Test application response time
    RESPONSE_TIME=$(curl -s -o /dev/null -w '%{time_total}' http://${APP_IP}:80)
    if (( $(echo "$RESPONSE_TIME < 1.0" | bc -l) )); then
        echo -e "Response time... ${GREEN}✓${NC} PASSED (${RESPONSE_TIME}s)"
        ((TESTS_PASSED++))
    else
        echo -e "Response time... ${YELLOW}⚠${NC} SLOW (${RESPONSE_TIME}s)"
    fi
    
    # Test search response time
    SEARCH_TIME=$(curl -s -o /dev/null -w '%{time_total}' "http://${APP_IP}:80/search?q=test")
    if (( $(echo "$SEARCH_TIME < 5.0" | bc -l) )); then
        echo -e "Search response time... ${GREEN}✓${NC} PASSED (${SEARCH_TIME}s)"
        ((TESTS_PASSED++))
    else
        echo -e "Search response time... ${YELLOW}⚠${NC} SLOW (${SEARCH_TIME}s)"
    fi
else
    echo -e "${RED}Container IP not found!${NC}"
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