#!/bin/bash
# =============================================================================
# Internal Health Check for Flask Application
# =============================================================================
# This script runs INSIDE the container to verify all services are operational.
# It checks:
# - Python environment and dependencies
# - Redis connectivity
# - Flask application responsiveness
# - Supervisor process management
# - Application functionality
#
# Usage: This is automatically run by 'lxc-compose test sample-flask-app'
# =============================================================================

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# -----------------------------------------------------------------------------
# Test execution function
# -----------------------------------------------------------------------------
# Runs a test command and reports success/failure
# Args: $1 = test description, $2 = command to execute
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
        echo -e "    Command: $command"  # Show failed command for debugging
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "=============================================="
echo "Flask Application Internal Health Check"
echo "=============================================="
echo

# -----------------------------------------------------------------------------
# Python Environment Tests
# -----------------------------------------------------------------------------
echo "Python Environment:"
run_test "Python installation" "python3 --version"
run_test "Virtual environment" "test -f /app/venv/bin/python"
run_test "Flask package" "/app/venv/bin/python -c 'import flask'"
run_test "Redis-py package" "/app/venv/bin/python -c 'import redis'"

echo

# -----------------------------------------------------------------------------
# Redis Connectivity Tests
# -----------------------------------------------------------------------------
echo "Redis Connectivity:"
# Use the REDIS_HOST environment variable or default to the datastore container
REDIS_HOST="${REDIS_HOST:-sample-flask-datastore}"
run_test "Redis ping" "redis-cli -h $REDIS_HOST ping | grep -q PONG"
run_test "Redis memory" "redis-cli -h $REDIS_HOST INFO memory | grep -q used_memory"
run_test "Redis persistence" "redis-cli -h $REDIS_HOST CONFIG GET save | grep -q save"

echo

# -----------------------------------------------------------------------------
# Process Management Tests
# -----------------------------------------------------------------------------
echo "Process Management:"
run_test "Supervisor running" "pgrep supervisord"
run_test "Flask service status" "supervisorctl status flask 2>/dev/null | grep -q RUNNING"
run_test "Flask process" "pgrep -f 'python /app/app.py'"

echo

# -----------------------------------------------------------------------------
# Application Tests
# -----------------------------------------------------------------------------
echo "Application Functionality:"
# Wait a moment for Flask to be fully ready
sleep 2

# Test Flask is responding on localhost
run_test "Flask HTTP response" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:5000 | grep -q '200'"
run_test "Flask homepage content" "curl -s http://127.0.0.1:5000 | grep -q 'Flask'"
run_test "Flask API status" "curl -s http://127.0.0.1:5000/api/status | grep -q 'ok'"

# Test Redis integration
run_test "Visit counter increments" "curl -s http://127.0.0.1:5000/api/increment > /dev/null && redis-cli -h $REDIS_HOST GET visits | grep -E '^[0-9]+$'"

echo

# -----------------------------------------------------------------------------
# Resource Usage Tests (optional but useful for production)
# -----------------------------------------------------------------------------
echo "Resource Usage:"
run_test "Memory usage reasonable" "free -m | awk '/^Mem:/{exit ($3/$2 < 0.9)}'  # Less than 90% memory used"
run_test "Disk space available" "df /app | awk 'NR==2{exit (int($5) < 90)}'  # Less than 90% disk used"

echo
echo "=============================================="
echo "Test Summary"
echo "=============================================="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

# Return appropriate exit code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All internal tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed!${NC}"
    echo "Run 'lxc-compose logs sample-flask-app' to investigate"
    exit 1
fi