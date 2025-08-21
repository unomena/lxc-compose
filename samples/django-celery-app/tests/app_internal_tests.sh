#!/bin/bash
# Internal health checks for sample-django-app container
# Tests Django, Celery, Nginx, and connectivity to datastore

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

echo "=== Django App Container Internal Health Check ==="
echo

# Test Supervisor is running
run_test "Supervisor service" "ps aux | grep -v grep | grep supervisord"

# Test Supervisor socket exists
run_test "Supervisor socket" "test -S /run/supervisord.sock"

# Test Django service in Supervisor
run_test "Django process in supervisor" "supervisorctl status django | grep -q RUNNING"

# Test Celery worker in Supervisor
run_test "Celery worker in supervisor" "supervisorctl status celery | grep -q RUNNING"

# Test Celery beat in Supervisor
run_test "Celery beat in supervisor" "supervisorctl status celery-beat | grep -q RUNNING"

# Test Django is actually running
run_test "Django process" "ps aux | grep -v grep | grep 'python.*manage.py runserver'"

# Test Celery worker is actually running
run_test "Celery worker process" "ps aux | grep -v grep | grep 'celery.*worker'"

# Test Celery beat is actually running
run_test "Celery beat process" "ps aux | grep -v grep | grep 'celery.*beat'"

# Test Django is responding on port 8000
run_test "Django port 8000" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000 | grep -q '200\|301\|302'"

# Test Django admin is accessible
run_test "Django admin page" "curl -s http://127.0.0.1:8000/admin/ | grep -q 'Django administration'"

# Test Nginx is running
run_test "Nginx process" "ps aux | grep -v grep | grep nginx"

# Test Nginx is listening on port 80
run_test "Nginx port 80" "netstat -tln | grep :80 || ss -tln | grep :80"

# Test Nginx is proxying to Django
run_test "Nginx proxy to Django" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80 | grep -q '200\|301\|302'"

# Test static files are being served
run_test "Static files via Nginx" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:80/static/admin/css/base.css | grep -q '200\|304'"

# Test connectivity to PostgreSQL on datastore container
run_test "PostgreSQL connectivity to datastore" "PGPASSWORD=\${DB_PASSWORD} psql -h \${DB_HOST} -U \${DB_USER} -d \${DB_NAME} -c 'SELECT 1'"

# Test connectivity to Redis on datastore container
run_test "Redis connectivity to datastore" "redis-cli -h \${REDIS_HOST} ping | grep -q PONG"

# Test Django can query the database
run_test "Django database query" "cd /app/src && ../venv/bin/python -c \"from django.db import connection; cursor = connection.cursor(); cursor.execute('SELECT 1'); print(cursor.fetchone())\""

# Test Django migrations are applied
run_test "Django migrations applied" "cd /app/src && ../venv/bin/python manage.py showmigrations --plan | grep -q '\\[X\\]'"

# Test Celery can connect to Redis
run_test "Celery Redis connection" "cd /app/src && ../venv/bin/python -c \"from celery import Celery; app = Celery('test', broker='redis://\${REDIS_HOST}:6379/0'); print(app.control.inspect().stats())\" 2>&1 | grep -v 'Error'"

# Check log files exist
run_test "Django log exists" "test -f /var/log/django/django.log"
run_test "Celery log exists" "test -f /var/log/celery/celery.log"
run_test "Celery beat log exists" "test -f /var/log/celery/celery-beat.log"
run_test "Nginx access log exists" "test -f /var/log/nginx/access.log"
run_test "Supervisor log exists" "test -f /var/log/supervisord.log"

# Test virtual environment is set up correctly
run_test "Python virtual environment" "test -d /app/venv && test -f /app/venv/bin/python"

# Test Django settings are loaded
run_test "Django settings" "cd /app/src && ../venv/bin/python -c \"import os; os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings'); from django.conf import settings; print(settings.DEBUG)\""

echo
echo "=== Test Summary ==="
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All app tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some app tests failed!${NC}"
    exit 1
fi