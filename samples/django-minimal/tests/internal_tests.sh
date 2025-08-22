#!/bin/bash
# =============================================================================
# Internal Health Check for Django Minimal Application
# =============================================================================
# This script runs INSIDE the container to verify all services are operational.
# It checks:
# - Python environment and Django dependencies
# - PostgreSQL database connectivity
# - Django application configuration
# - Supervisor process management
# - Static file collection
# - Admin interface availability
#
# Usage: This is automatically run by 'lxc-compose test sample-django-minimal-app'
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
echo "Django Minimal Application Internal Health Check"
echo "=============================================="
echo

# -----------------------------------------------------------------------------
# Python Environment Tests
# -----------------------------------------------------------------------------
echo "Python Environment:"
run_test "Python installation" "python3 --version"
run_test "Virtual environment" "test -f /app/venv/bin/python"
run_test "Django package" "/app/venv/bin/python -c 'import django; print(django.__version__)'"
run_test "Psycopg2 package" "/app/venv/bin/python -c 'import psycopg2'"
run_test "Django settings module" "/app/venv/bin/python -c 'import os; os.environ[\"DJANGO_SETTINGS_MODULE\"]=\"config.settings\"; from django.conf import settings; print(settings.DATABASES)'"

echo

# -----------------------------------------------------------------------------
# PostgreSQL Database Tests
# -----------------------------------------------------------------------------
echo "PostgreSQL Database:"
# Use environment variables from container
DB_HOST="${DB_HOST:-sample-django-minimal-database}"
DB_NAME="${DB_NAME:-djangodb}"
DB_USER="${DB_USER:-djangouser}"
DB_PASSWORD="${DB_PASSWORD:-djangopass}"

# Test database connectivity
run_test "Database host reachable" "ping -c 1 -W 2 $DB_HOST"
run_test "PostgreSQL port open" "nc -zv $DB_HOST 5432 2>&1 | grep -q succeeded"
run_test "Database connection" "PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -U '$DB_USER' -d '$DB_NAME' -c 'SELECT 1' 2>&1 | grep -q '1 row'"
run_test "Database tables exist" "PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -U '$DB_USER' -d '$DB_NAME' -c '\\dt' 2>&1 | grep -q 'django_migrations'"

echo

# -----------------------------------------------------------------------------
# Django Configuration Tests
# -----------------------------------------------------------------------------
echo "Django Configuration:"
cd /app/src

# Test Django management commands
run_test "Django check command" "../venv/bin/python manage.py check --database default"
run_test "Django migrations applied" "../venv/bin/python manage.py showmigrations --list 2>&1 | grep -q '\\[X\\]'"
run_test "Static files collected" "test -d /app/static/admin"
run_test "Media directory exists" "test -d /app/media"

# Test Django admin user
run_test "Superuser exists" "../venv/bin/python manage.py shell -c \"from django.contrib.auth import get_user_model; User = get_user_model(); exit(0 if User.objects.filter(is_superuser=True).exists() else 1)\""

echo

# -----------------------------------------------------------------------------
# Process Management Tests
# -----------------------------------------------------------------------------
echo "Process Management:"
run_test "Supervisor running" "pgrep supervisord"
run_test "Django service configured" "supervisorctl status django 2>/dev/null | grep -q RUNNING"
run_test "Django process active" "pgrep -f 'python.*manage.py runserver'"
run_test "Log directory exists" "test -d /var/log/django"
run_test "Django log file exists" "test -f /var/log/django/django.log"

echo

# -----------------------------------------------------------------------------
# Application Tests
# -----------------------------------------------------------------------------
echo "Application Functionality:"
# Wait a moment for Django to be fully ready
sleep 2

# Test Django is responding on localhost
run_test "Django HTTP response" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000 | grep -q '200'"
run_test "Django homepage content" "curl -s http://127.0.0.1:8000 | grep -q 'Django'"
run_test "Admin interface available" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/admin/ | grep -q '302\\|200'"
run_test "Static files serving" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/static/admin/css/base.css | grep -q '200\\|304'"

# Test database operations
run_test "Database write operation" "../venv/bin/python manage.py shell -c \"from django.contrib.auth import get_user_model; User = get_user_model(); u = User.objects.first(); u.last_login = None; u.save(); print('OK')\""
run_test "Database read operation" "../venv/bin/python manage.py shell -c \"from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.count())\""

echo

# -----------------------------------------------------------------------------
# Resource Usage Tests (optional but useful for production)
# -----------------------------------------------------------------------------
echo "Resource Usage:"
run_test "Memory usage reasonable" "free -m | awk '/^Mem:/{exit ($3/$2 < 0.9)}'  # Less than 90% memory used"
run_test "Disk space available" "df /app | awk 'NR==2{exit (int($5) < 90)}'  # Less than 90% disk used"
run_test "Database size reasonable" "PGPASSWORD='$DB_PASSWORD' psql -h '$DB_HOST' -U '$DB_USER' -d '$DB_NAME' -t -c \"SELECT pg_size_pretty(pg_database_size('$DB_NAME'))\" | grep -E '(bytes|kB|MB)'"

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
    echo "Run 'lxc-compose logs sample-django-minimal-app' to investigate"
    exit 1
fi