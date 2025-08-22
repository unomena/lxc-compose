#!/bin/bash
# =============================================================================
# External Tests for Django Minimal Application
# =============================================================================
# This script runs ON THE HOST to verify the Django app is accessible externally.
# It tests:
# - Port forwarding is working correctly
# - Application is responding to external requests
# - Admin interface is accessible
# - Database connectivity from application
# - Performance and response times
#
# Usage: Automatically run by 'lxc-compose test sample-django-minimal-app external'
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
APP_IP=$(lxc list sample-django-minimal-app -c 4 --format csv | cut -d' ' -f1)
DB_IP=$(lxc list sample-django-minimal-database -c 4 --format csv | cut -d' ' -f1)

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
echo "Django Minimal Application External Tests"
echo "=============================================="
echo "App Container IP: ${APP_IP:-Not found}"
echo "Database Container IP: ${DB_IP:-Not found}"
echo

# -----------------------------------------------------------------------------
# Container Status Tests
# -----------------------------------------------------------------------------
echo "Container Status:"
run_test "Django app container running" "lxc list sample-django-minimal-app --format csv | grep -q RUNNING"
run_test "PostgreSQL container running" "lxc list sample-django-minimal-database --format csv | grep -q RUNNING"

echo

# -----------------------------------------------------------------------------
# Network Connectivity Tests
# -----------------------------------------------------------------------------
echo "Network Connectivity:"
if [ -n "$APP_IP" ]; then
    run_test "Django container reachable" "ping -c 1 -W 2 $APP_IP"
    run_test "Port 8000 open on container" "nc -zv $APP_IP 8000 2>&1 | grep -q succeeded"
else
    echo -e "  ${RED}✗${NC} Django container IP not found"
    ((TESTS_FAILED++))
fi

if [ -n "$DB_IP" ]; then
    run_test "Database container reachable" "ping -c 1 -W 2 $DB_IP"
    run_test "Port 5432 open on database" "nc -zv $DB_IP 5432 2>&1 | grep -q succeeded"
else
    echo -e "  ${RED}✗${NC} Database container IP not found"
    ((TESTS_FAILED++))
fi

echo

# -----------------------------------------------------------------------------
# Application Access Tests
# -----------------------------------------------------------------------------
echo "Application Access:"
# Test direct container access
if [ -n "$APP_IP" ]; then
    run_test "Direct Django access (container)" "curl -s -o /dev/null -w '%{http_code}' http://$APP_IP:8000 | grep -q '200'"
    run_test "Django welcome page check" "curl -s http://$APP_IP:8000 | grep -q 'Django'"
    run_test "Admin interface accessible" "curl -s -o /dev/null -w '%{http_code}' http://$APP_IP:8000/admin/ | grep -q '302\\|200'"
    run_test "Admin login page content" "curl -s -L http://$APP_IP:8000/admin/ | grep -q 'Django administration\\|Log in'"
fi

# Test port forwarding via localhost
# Port 8000 should be auto-forwarded
run_test "Port forwarding (localhost:8000)" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000 | grep -q '200'"
run_test "Django via forwarded port" "curl -s http://localhost:8000 | grep -q 'Django'"
run_test "Admin via forwarded port" "curl -s -L http://localhost:8000/admin/ | grep -q 'Django administration\\|Log in'"

echo

# -----------------------------------------------------------------------------
# Static Files Tests
# -----------------------------------------------------------------------------
echo "Static Files:"
# Test static file serving via localhost
run_test "Admin CSS accessible" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/static/admin/css/base.css | grep -q '200\\|304'"
run_test "Admin fonts accessible" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/static/admin/fonts/Roboto-Regular-webfont.woff | grep -q '200\\|304'"
run_test "Admin JavaScript accessible" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/static/admin/js/admin/RelatedObjectLookups.js | grep -q '200\\|304'"

echo

# -----------------------------------------------------------------------------
# Database Integration Tests
# -----------------------------------------------------------------------------
echo "Database Integration:"
# Test that Django can connect to PostgreSQL
# This is implicit if admin interface works, but we can check the database directly
if [ -n "$DB_IP" ]; then
    # Test if database is accessible from host (should NOT be forwarded for security)
    if ! nc -zv localhost 5432 2>&1 | grep -q succeeded; then
        echo -e "  PostgreSQL not exposed on localhost... ${GREEN}✓${NC} PASSED (secure)"
        ((TESTS_PASSED++))
    else
        echo -e "  PostgreSQL not exposed on localhost... ${RED}✗${NC} FAILED - Security risk!"
        ((TESTS_FAILED++))
    fi
fi

echo

# -----------------------------------------------------------------------------
# Performance Tests
# -----------------------------------------------------------------------------
echo "Performance:"
# Measure response time
RESPONSE_TIME=$(curl -s -o /dev/null -w '%{time_total}' http://localhost:8000 2>/dev/null || echo "999")
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

# Test static file performance
STATIC_TIME=$(curl -s -o /dev/null -w '%{time_total}' http://localhost:8000/static/admin/css/base.css 2>/dev/null || echo "999")
if (( $(echo "$STATIC_TIME < 0.1" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "  Static file serving... ${GREEN}✓${NC} PASSED (${STATIC_TIME}s)"
    ((TESTS_PASSED++))
elif (( $(echo "$STATIC_TIME < 0.3" | bc -l 2>/dev/null || echo 0) )); then
    echo -e "  Static file serving... ${YELLOW}⚠${NC} ACCEPTABLE (${STATIC_TIME}s)"
    ((TESTS_PASSED++))
else
    echo -e "  Static file serving... ${RED}✗${NC} SLOW (${STATIC_TIME}s)"
    ((TESTS_FAILED++))
fi

echo

# -----------------------------------------------------------------------------
# Security Tests
# -----------------------------------------------------------------------------
echo "Security:"
# Check if unnecessary ports are closed
run_test "SSH not exposed" "! nc -zv $APP_IP 22 2>&1 | grep -q succeeded"
run_test "PostgreSQL not on app container" "! nc -zv $APP_IP 5432 2>&1 | grep -q succeeded"

# Check Django debug mode (should be off in production)
if curl -s http://localhost:8000/nonexistent 2>/dev/null | grep -q "DEBUG = True"; then
    echo -e "  Django debug mode... ${YELLOW}⚠${NC} WARNING - Debug mode enabled!"
else
    echo -e "  Django debug mode... ${GREEN}✓${NC} PASSED - Debug mode disabled"
    ((TESTS_PASSED++))
fi

echo
echo "=============================================="
echo "Test Summary"
echo "=============================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All external tests passed!${NC}"
    echo "Django application is accessible at:"
    echo "  - http://localhost:8000 (via port forwarding)"
    echo "  - http://$APP_IP:8000 (direct container access)"
    echo "  - Admin: http://localhost:8000/admin/"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed!${NC}"
    echo "Debug tips:"
    echo "  - Check port forwarding: sudo iptables -t nat -L PREROUTING -n | grep 8000"
    echo "  - Check container logs: lxc-compose logs sample-django-minimal-app"
    echo "  - Check database logs: lxc-compose logs sample-django-minimal-database"
    exit 1
fi