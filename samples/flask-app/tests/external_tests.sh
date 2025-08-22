#!/bin/bash
# =============================================================================
# External Tests for Flask Application
# =============================================================================
# This script runs ON THE HOST to verify the Flask app is accessible externally.
# It tests:
# - Port forwarding is working correctly
# - Application is responding to external requests
# - API endpoints are functional
# - Performance and response times
#
# Usage: Automatically run by 'lxc-compose test sample-flask-app external'
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Get container IPs
APP_IP=$(lxc list sample-flask-app -c 4 --format csv | cut -d' ' -f1)
DATASTORE_IP=$(lxc list sample-flask-datastore -c 4 --format csv | cut -d' ' -f1)

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------
run_test() {
    local test_name="$1"
    local command="$2"
    
    echo -n "  Testing $test_name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} PASSED"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} FAILED"
        echo -e "    Debug: $command"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "=============================================="
echo "Flask Application External Tests"
echo "=============================================="
echo "App Container IP: ${APP_IP:-Not found}"
echo "Redis Container IP: ${DATASTORE_IP:-Not found}"
echo

# -----------------------------------------------------------------------------
# Container Status Tests
# -----------------------------------------------------------------------------
echo "Container Status:"
run_test "Flask container running" "lxc list sample-flask-app --format csv | grep -q RUNNING"
run_test "Redis container running" "lxc list sample-flask-datastore --format csv | grep -q RUNNING"

echo

# -----------------------------------------------------------------------------
# Network Connectivity Tests
# -----------------------------------------------------------------------------
echo "Network Connectivity:"
if [ -n "$APP_IP" ]; then
    run_test "Flask container reachable" "ping -c 1 -W 2 $APP_IP"
    run_test "Port 5000 open on container" "nc -zv $APP_IP 5000 2>&1 | grep -q succeeded"
else
    echo -e "  ${RED}✗${NC} Flask container IP not found"
    ((TESTS_FAILED++))
fi

if [ -n "$DATASTORE_IP" ]; then
    run_test "Redis container reachable" "ping -c 1 -W 2 $DATASTORE_IP"
    run_test "Port 6379 open on Redis" "nc -zv $DATASTORE_IP 6379 2>&1 | grep -q succeeded"
else
    echo -e "  ${RED}✗${NC} Redis container IP not found"
    ((TESTS_FAILED++))
fi

echo

# -----------------------------------------------------------------------------
# Application Access Tests
# -----------------------------------------------------------------------------
echo "Application Access:"
# Test direct container access
if [ -n "$APP_IP" ]; then
    run_test "Direct Flask access (container)" "curl -s -o /dev/null -w '%{http_code}' http://$APP_IP:5000 | grep -q '200'"
    run_test "Flask content check" "curl -s http://$APP_IP:5000 | grep -q 'Flask'"
fi

# Test port forwarding via localhost
# Port 5000 should be auto-forwarded
run_test "Port forwarding (localhost:5000)" "curl -s -o /dev/null -w '%{http_code}' http://localhost:5000 | grep -q '200'"
run_test "Homepage via forwarded port" "curl -s http://localhost:5000 | grep -q 'Flask'"

echo

# -----------------------------------------------------------------------------
# API Functionality Tests
# -----------------------------------------------------------------------------
echo "API Functionality:"
# Test API endpoints via localhost (port forwarding)
run_test "API status endpoint" "curl -s http://localhost:5000/api/status | grep -q 'ok'"
run_test "API increment endpoint" "curl -s http://localhost:5000/api/increment | grep -q 'count'"

# Test Redis integration
VISIT_COUNT=$(curl -s http://localhost:5000/api/increment 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [ -n "$VISIT_COUNT" ] && [ "$VISIT_COUNT" -gt 0 ]; then
    echo -e "  Redis integration... ${GREEN}✓${NC} PASSED (count: $VISIT_COUNT)"
    ((TESTS_PASSED++))
else
    echo -e "  Redis integration... ${RED}✗${NC} FAILED"
    ((TESTS_FAILED++))
fi

echo

# -----------------------------------------------------------------------------
# Performance Tests
# -----------------------------------------------------------------------------
echo "Performance:"
# Measure response time
RESPONSE_TIME=$(curl -s -o /dev/null -w '%{time_total}' http://localhost:5000 2>/dev/null || echo "999")
if (( $(echo "$RESPONSE_TIME < 0.5" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "  Response time... ${GREEN}✓${NC} PASSED (${RESPONSE_TIME}s)"
    ((TESTS_PASSED++))
elif (( $(echo "$RESPONSE_TIME < 1.0" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "  Response time... ${YELLOW}⚠${NC} ACCEPTABLE (${RESPONSE_TIME}s)"
    ((TESTS_PASSED++))
else
    echo -e "  Response time... ${RED}✗${NC} SLOW (${RESPONSE_TIME}s)"
    ((TESTS_FAILED++))
fi

echo

# -----------------------------------------------------------------------------
# Security Tests
# -----------------------------------------------------------------------------
echo "Security:"
# Verify Redis is not exposed on localhost
if ! nc -zv localhost 6379 2>&1 | grep -q succeeded; then
    echo -e "  Redis not exposed externally... ${GREEN}✓${NC} PASSED"
    ((TESTS_PASSED++))
else
    echo -e "  Redis not exposed externally... ${RED}✗${NC} FAILED - Security risk!"
    ((TESTS_FAILED++))
fi

# Check if unnecessary ports are closed
run_test "SSH not exposed" "! nc -zv $APP_IP 22 2>&1 | grep -q succeeded"

echo
echo "=============================================="
echo "Test Summary"  
echo "=============================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All external tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed!${NC}"
    echo "Debug tips:"
    echo "  - Check port forwarding: sudo iptables -t nat -L PREROUTING -n | grep 5000"
    echo "  - Check container logs: lxc-compose logs sample-flask-app"
    exit 1
fi