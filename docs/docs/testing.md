# LXC Compose Testing Guide

Comprehensive guide for testing LXC Compose containers and applications.

> **Important**: For information about test inheritance when using `includes:` with library services, see [TEST_INHERITANCE.md](TEST_INHERITANCE.md)

## Table of Contents

- [Testing Overview](#testing-overview)
- [Test Types](#test-types)
  - [Internal Tests](#internal-tests)
  - [External Tests](#external-tests)
  - [Port Forwarding Tests](#port-forwarding-tests)
- [Test Inheritance](#test-inheritance)
- [Writing Tests](#writing-tests)
  - [Test Script Structure](#test-script-structure)
  - [Common Test Patterns](#common-test-patterns)
  - [Test Best Practices](#test-best-practices)
- [Configuration](#configuration)
- [Running Tests](#running-tests)
- [Test Output](#test-output)
- [Debugging Failed Tests](#debugging-failed-tests)
- [CI/CD Integration](#cicd-integration)
- [Examples](#examples)

## Testing Overview

LXC Compose provides a three-tier testing framework to ensure containers and applications are functioning correctly:

1. **Internal Tests**: Run inside containers to verify services and internal state
2. **External Tests**: Run from host to verify connectivity and exposed services
3. **Port Forwarding Tests**: Verify iptables rules and network security

### Why Three Test Types?

- **Internal**: Ensures services start correctly and internal dependencies work
- **External**: Validates that exposed services are accessible from outside
- **Port Forwarding**: Confirms security rules and port exposure are correct

## Test Types

### Internal Tests

Internal tests run inside the container to verify:
- Services are running
- Ports are listening
- Configuration files exist
- Internal connectivity works
- Database connections succeed
- Log files are being written

#### Example Internal Test
```bash
#!/bin/bash
# File: tests/internal_test.sh

echo "Testing internal services..."

# Check if nginx is running
if ! pgrep nginx > /dev/null; then
    echo "ERROR: Nginx is not running"
    exit 1
fi

# Check if port 80 is listening
if ! netstat -tln | grep -q ":80 "; then
    echo "ERROR: Port 80 is not listening"
    exit 1
fi

# Check if Django is responding
if ! curl -f http://localhost:8000/health > /dev/null 2>&1; then
    echo "ERROR: Django is not responding"
    exit 1
fi

# Check database connectivity
if ! PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
    echo "ERROR: Cannot connect to database"
    exit 1
fi

echo "✓ All internal tests passed"
```

### External Tests

External tests run from the host to verify:
- Container is accessible
- Exposed ports are reachable
- HTTP/HTTPS endpoints respond
- API calls succeed
- Load balancing works
- SSL certificates are valid

#### Example External Test
```bash
#!/bin/bash
# File: tests/external_test.sh

CONTAINER=${1:-sample-app}
echo "Testing external connectivity for $CONTAINER..."

# Test HTTP connectivity
if ! curl -f http://localhost > /dev/null 2>&1; then
    echo "ERROR: Cannot reach HTTP service"
    exit 1
fi

# Test specific endpoint
if ! curl -f http://localhost/api/health > /dev/null 2>&1; then
    echo "ERROR: Health endpoint not responding"
    exit 1
fi

# Test response content
RESPONSE=$(curl -s http://localhost/api/status)
if [[ "$RESPONSE" != *"ok"* ]]; then
    echo "ERROR: Unexpected response: $RESPONSE"
    exit 1
fi

echo "✓ All external tests passed"
```

### Port Forwarding Tests

Port forwarding tests verify iptables configuration:
- Required ports are forwarded
- Unnecessary ports are NOT forwarded
- DNAT rules are correct
- Security rules are in place
- Container isolation is maintained

#### Example Port Forwarding Test
```bash
#!/bin/bash
# File: tests/port_forwarding_test.sh

echo "Testing port forwarding rules..."

# Check if port 80 is forwarded
if ! sudo iptables -t nat -L PREROUTING -n | grep -q "dpt:80.*DNAT"; then
    echo "ERROR: Port 80 is not forwarded"
    exit 1
fi

# Check that database port is NOT forwarded (security)
if sudo iptables -t nat -L PREROUTING -n | grep -q "dpt:5432.*DNAT"; then
    echo "ERROR: Database port 5432 should not be exposed!"
    exit 1
fi

# Verify container IP in DNAT rule
CONTAINER_IP=$(lxc list sample-app -c 4 --format csv | cut -d' ' -f1)
if ! sudo iptables -t nat -L PREROUTING -n | grep -q "to:$CONTAINER_IP:80"; then
    echo "ERROR: DNAT rule not pointing to correct container IP"
    exit 1
fi

echo "✓ All port forwarding tests passed"
```

## Writing Tests

### Test Script Structure

#### Basic Structure
```bash
#!/bin/bash
set -e  # Exit on first error

# Test identification
echo "========================================"
echo "Test: [Test Name]"
echo "Type: [internal|external|port_forwarding]"
echo "Container: ${1:-default-container}"
echo "========================================"

# Setup (if needed)
setup() {
    echo "Setting up test environment..."
    # Create test data, etc.
}

# Cleanup (if needed)
cleanup() {
    echo "Cleaning up..."
    # Remove test data, etc.
}

# Trap cleanup on exit
trap cleanup EXIT

# Run setup
setup

# Test 1: Description
echo -n "Testing feature 1... "
if [ condition ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL: Error message"
    exit 1
fi

# Test 2: Description
echo -n "Testing feature 2... "
# ... test logic ...

echo ""
echo "========================================"
echo "All tests passed!"
echo "========================================"
```

### Common Test Patterns

#### Service Health Check
```bash
# Check if service is running
check_service() {
    local service=$1
    if pgrep -x "$service" > /dev/null; then
        echo "✓ $service is running"
    else
        echo "✗ $service is not running"
        return 1
    fi
}

check_service nginx
check_service supervisor
```

#### Port Listening Check
```bash
# Check if port is listening
check_port() {
    local port=$1
    if netstat -tln | grep -q ":$port "; then
        echo "✓ Port $port is listening"
    else
        echo "✗ Port $port is not listening"
        return 1
    fi
}

check_port 80
check_port 443
```

#### HTTP Endpoint Check
```bash
# Check HTTP endpoint
check_endpoint() {
    local url=$1
    local expected_code=${2:-200}
    
    code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    if [ "$code" = "$expected_code" ]; then
        echo "✓ $url returned $code"
    else
        echo "✗ $url returned $code (expected $expected_code)"
        return 1
    fi
}

check_endpoint "http://localhost" 200
check_endpoint "http://localhost/api/health" 200
check_endpoint "http://localhost/admin" 302
```

#### Database Connectivity Check
```bash
# PostgreSQL
check_postgres() {
    if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
        echo "✓ PostgreSQL connection successful"
    else
        echo "✗ PostgreSQL connection failed"
        return 1
    fi
}

# Redis
check_redis() {
    if redis-cli -h $REDIS_HOST ping > /dev/null 2>&1; then
        echo "✓ Redis connection successful"
    else
        echo "✗ Redis connection failed"
        return 1
    fi
}

# MongoDB
check_mongodb() {
    if mongo --host $MONGO_HOST --eval "db.version()" > /dev/null 2>&1; then
        echo "✓ MongoDB connection successful"
    else
        echo "✗ MongoDB connection failed"
        return 1
    fi
}
```

#### Log File Check
```bash
# Check if logs are being written
check_logs() {
    local logfile=$1
    if [ -f "$logfile" ]; then
        if [ -s "$logfile" ]; then
            echo "✓ $logfile exists and has content"
        else
            echo "⚠ $logfile exists but is empty"
        fi
    else
        echo "✗ $logfile does not exist"
        return 1
    fi
}

check_logs "/var/log/nginx/access.log"
check_logs "/var/log/django/app.log"
```

### Test Best Practices

1. **Exit on First Failure**: Use `set -e` or check each command
2. **Clear Output**: Use descriptive messages and status indicators
3. **Idempotent**: Tests should be runnable multiple times
4. **Fast**: Keep tests quick to encourage frequent running
5. **Isolated**: Tests shouldn't depend on each other
6. **Cleanup**: Remove test data after completion
7. **Timeout**: Add timeouts for network operations
8. **Logging**: Log detailed information for debugging
9. **Environment**: Use environment variables for configuration
10. **Documentation**: Comment complex test logic

## Test Inheritance

When using `includes:` to pull in library services, tests are automatically inherited:

```yaml
containers:
  mydb:
    template: alpine-3.19
    includes:
      - postgresql  # Inherits all PostgreSQL tests
    tests:
      external:
        - custom:/tests/my_test.sh  # Add your own tests too
```

See [TEST_INHERITANCE.md](TEST_INHERITANCE.md) for complete details on test inheritance.

## Configuration

### Test Configuration in YAML

```yaml
containers:
  myapp:
    tests:
      internal:
        - health:/app/tests/health_check.sh
        - database:/app/tests/db_check.sh
        - services:/app/tests/service_check.sh
      
      external:
        - connectivity:/app/tests/connectivity.sh
        - api:/app/tests/api_test.sh
        - performance:/app/tests/load_test.sh
      
      port_forwarding:
        - iptables:/app/tests/iptables_check.sh
        - security:/app/tests/security_check.sh
```

### Test Types Format

```yaml
tests:
  test_category:
    - test_name:path/to/test/script.sh
```

- **test_category**: `internal`, `external`, or `port_forwarding`
- **test_name**: Descriptive name shown in output
- **path**: Path to test script inside container (internal) or on host (external)

### Mount Test Scripts

Ensure test scripts are available in containers:

```yaml
mounts:
  - ./tests:/app/tests  # Mount test directory
```

## Running Tests

### Command Line Usage

```bash
# Run all tests for all containers
lxc-compose test

# Run all tests for specific container
lxc-compose test myapp

# Run specific test type
lxc-compose test myapp internal
lxc-compose test myapp external
lxc-compose test myapp port_forwarding

# List available tests
lxc-compose test myapp list
```

### Running Tests Manually

```bash
# Run internal test manually
lxc exec myapp -- /app/tests/internal_test.sh

# Run external test manually
./tests/external_test.sh myapp

# Run port forwarding test manually
sudo ./tests/port_forwarding_test.sh myapp
```

### Test Execution Order

1. Internal tests (verify container is healthy)
2. External tests (verify accessibility)
3. Port forwarding tests (verify security)

## Test Output

### Successful Output
```
Running tests for sample-django-app...

[INTERNAL TESTS]
✓ health: All services running
✓ database: Database connections successful
✓ services: All required services active

[EXTERNAL TESTS]
✓ connectivity: Container accessible from host
✓ api: API endpoints responding correctly
✓ performance: Response times within limits

[PORT FORWARDING TESTS]
✓ iptables: Required ports forwarded
✓ security: Unnecessary ports blocked

========================================
All tests passed! (9/9)
========================================
```

### Failed Output
```
Running tests for sample-django-app...

[INTERNAL TESTS]
✓ health: All services running
✗ database: Cannot connect to PostgreSQL
  Error: FATAL: password authentication failed for user "app"
✓ services: All required services active

[EXTERNAL TESTS]
✓ connectivity: Container accessible from host
✗ api: API endpoint /api/users returned 500
  Expected: 200, Got: 500

[PORT FORWARDING TESTS]
✓ iptables: Required ports forwarded
⚠ security: Port 5432 is exposed (should be internal only)

========================================
Tests: 5 passed, 2 failed, 1 warning
========================================
```

### Status Indicators

- `✓` - Test passed
- `✗` - Test failed
- `⚠` - Warning (non-critical issue)
- `…` - Test in progress
- `⊘` - Test skipped

## Debugging Failed Tests

### Common Issues and Solutions

#### Internal Test Failures

1. **Service not running**
   ```bash
   # Check service status
   lxc exec container -- supervisorctl status
   
   # Check service logs
   lxc exec container -- tail -f /var/log/service.log
   
   # Restart service
   lxc exec container -- supervisorctl restart service
   ```

2. **Port not listening**
   ```bash
   # Check listening ports
   lxc exec container -- netstat -tln
   
   # Check firewall rules
   lxc exec container -- iptables -L -n
   ```

3. **Database connection failed**
   ```bash
   # Test connection manually
   lxc exec container -- psql -h localhost -U user -d database
   
   # Check database logs
   lxc exec container -- tail -f /var/log/postgresql/postgresql.log
   ```

#### External Test Failures

1. **Container not accessible**
   ```bash
   # Check container IP
   lxc list container -c 4
   
   # Ping container
   ping container-ip
   
   # Check iptables rules
   sudo iptables -t nat -L PREROUTING -n
   ```

2. **HTTP endpoint not responding**
   ```bash
   # Test with curl verbose
   curl -v http://localhost/endpoint
   
   # Check nginx logs
   lxc-compose logs container nginx
   ```

#### Port Forwarding Test Failures

1. **Port not forwarded**
   ```bash
   # List all DNAT rules
   sudo iptables -t nat -L PREROUTING -n | grep DNAT
   
   # Recreate port forwarding
   lxc-compose down && lxc-compose up
   ```

2. **Wrong container IP**
   ```bash
   # Check current container IP
   lxc list container -c 4 --format csv
   
   # Check tracked IP
   cat /etc/lxc-compose/container-ips.json
   ```

### Debug Mode

Run tests with debug output:

```bash
# Enable bash debug mode
lxc exec container -- bash -x /app/tests/test.sh

# Add debug output to tests
DEBUG=1 lxc-compose test myapp
```

## CI/CD Integration

### GitHub Actions

```yaml
name: LXC Compose Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Install LXC Compose
      run: |
        curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash
    
    - name: Start containers
      run: lxc-compose up
    
    - name: Wait for services
      run: sleep 30
    
    - name: Run tests
      run: |
        lxc-compose test
        if [ $? -ne 0 ]; then
          echo "Tests failed"
          lxc-compose logs
          exit 1
        fi
    
    - name: Cleanup
      if: always()
      run: lxc-compose destroy
```

### GitLab CI

```yaml
stages:
  - build
  - test
  - cleanup

variables:
  LXC_COMPOSE_FILE: "lxc-compose.yml"

test:
  stage: test
  script:
    - ./install.sh
    - lxc-compose up -f $LXC_COMPOSE_FILE
    - lxc-compose test
  after_script:
    - lxc-compose destroy -f $LXC_COMPOSE_FILE
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    stages {
        stage('Setup') {
            steps {
                sh 'curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash'
            }
        }
        
        stage('Deploy') {
            steps {
                sh 'lxc-compose up'
            }
        }
        
        stage('Test') {
            steps {
                sh 'lxc-compose test'
            }
        }
    }
    
    post {
        always {
            sh 'lxc-compose destroy'
        }
        failure {
            sh 'lxc-compose logs'
        }
    }
}
```

## Examples

### Complete Test Suite Example

#### Directory Structure
```
project/
├── lxc-compose.yml
├── tests/
│   ├── internal/
│   │   ├── health_check.sh
│   │   ├── service_check.sh
│   │   └── database_check.sh
│   ├── external/
│   │   ├── api_test.sh
│   │   ├── web_test.sh
│   │   └── load_test.sh
│   └── port_forwarding/
│       ├── iptables_check.sh
│       └── security_audit.sh
```

#### Health Check Test
```bash
#!/bin/bash
# tests/internal/health_check.sh

set -e

echo "Running health checks..."

# Function to check service
check_service() {
    local name=$1
    local check_cmd=$2
    
    echo -n "  Checking $name... "
    if eval $check_cmd > /dev/null 2>&1; then
        echo "✓"
    else
        echo "✗"
        exit 1
    fi
}

# Check web server
check_service "Nginx" "pgrep nginx"
check_service "Port 80" "netstat -tln | grep :80"

# Check application
check_service "Django" "curl -f http://localhost:8000/health"
check_service "Celery" "pgrep -f celery"

# Check database
check_service "PostgreSQL" "pg_isready -h $DB_HOST"
check_service "Redis" "redis-cli -h $REDIS_HOST ping"

echo "All health checks passed!"
```

#### API Test
```bash
#!/bin/bash
# tests/external/api_test.sh

set -e

BASE_URL="http://localhost"
echo "Testing API endpoints..."

# Function to test endpoint
test_endpoint() {
    local path=$1
    local expected=$2
    local method=${3:-GET}
    
    echo -n "  $method $path... "
    response=$(curl -s -X $method "$BASE_URL$path" -w "\n%{http_code}")
    code=$(echo "$response" | tail -n1)
    
    if [ "$code" = "$expected" ]; then
        echo "✓ ($code)"
    else
        echo "✗ (got $code, expected $expected)"
        exit 1
    fi
}

# Test endpoints
test_endpoint "/" "200"
test_endpoint "/api/health" "200"
test_endpoint "/api/users" "200"
test_endpoint "/api/login" "405" "GET"
test_endpoint "/api/login" "200" "POST"
test_endpoint "/admin/" "302"
test_endpoint "/nonexistent" "404"

echo "All API tests passed!"
```

#### Security Audit Test
```bash
#!/bin/bash
# tests/port_forwarding/security_audit.sh

set -e

echo "Running security audit..."

# Check exposed ports
echo "  Checking exposed ports..."
EXPOSED_PORTS="80 443"
FORBIDDEN_PORTS="5432 6379 8000"

for port in $EXPOSED_PORTS; do
    if sudo iptables -t nat -L PREROUTING -n | grep -q "dpt:$port.*DNAT"; then
        echo "    ✓ Port $port is properly exposed"
    else
        echo "    ✗ Port $port should be exposed but isn't"
        exit 1
    fi
done

for port in $FORBIDDEN_PORTS; do
    if sudo iptables -t nat -L PREROUTING -n | grep -q "dpt:$port.*DNAT"; then
        echo "    ✗ Port $port is exposed (security risk!)"
        exit 1
    else
        echo "    ✓ Port $port is properly blocked"
    fi
done

# Check container isolation
echo "  Checking container isolation..."
if sudo iptables -L FORWARD -n | grep -q "lxc-compose.*REJECT"; then
    echo "    ✓ Container isolation rules in place"
else
    echo "    ⚠ Container isolation rules missing"
fi

echo "Security audit passed!"
```

### Automated Test Runner

```bash
#!/bin/bash
# run_all_tests.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0

# Run test and track results
run_test() {
    local container=$1
    local type=$2
    local name=$3
    local script=$4
    
    TOTAL=$((TOTAL + 1))
    echo -n "  $name: "
    
    if [ "$type" = "internal" ]; then
        if lxc exec $container -- $script > /tmp/test_output.txt 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAILED=$((FAILED + 1))
            cat /tmp/test_output.txt | sed 's/^/    /'
        fi
    else
        if $script $container > /tmp/test_output.txt 2>&1; then
            echo -e "${GREEN}✓ PASS${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}✗ FAIL${NC}"
            FAILED=$((FAILED + 1))
            cat /tmp/test_output.txt | sed 's/^/    /'
        fi
    fi
}

# Main execution
echo "========================================"
echo "Running Complete Test Suite"
echo "========================================"

# Get containers from config
CONTAINERS=$(lxc-compose list -f lxc-compose.yml | grep RUNNING | awk '{print $1}')

for container in $CONTAINERS; do
    echo ""
    echo "Testing $container..."
    echo "----------------------------------------"
    
    # Run internal tests
    echo "[INTERNAL TESTS]"
    for test in tests/internal/*.sh; do
        if [ -f "$test" ]; then
            name=$(basename $test .sh)
            run_test $container "internal" $name "/app/$test"
        fi
    done
    
    # Run external tests
    echo "[EXTERNAL TESTS]"
    for test in tests/external/*.sh; do
        if [ -f "$test" ]; then
            name=$(basename $test .sh)
            run_test $container "external" $name "$test"
        fi
    done
    
    # Run port forwarding tests
    echo "[PORT FORWARDING TESTS]"
    for test in tests/port_forwarding/*.sh; do
        if [ -f "$test" ]; then
            name=$(basename $test .sh)
            run_test $container "port_forwarding" $name "$test"
        fi
    done
done

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Total:    $TOTAL"
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi
```

## Test Development Workflow

1. **Write Configuration**: Define tests in `lxc-compose.yml`
2. **Create Test Scripts**: Write test scripts in `tests/` directory
3. **Mount Scripts**: Ensure scripts are accessible in containers
4. **Test Locally**: Run tests during development
5. **Debug Failures**: Use debug mode and logs to fix issues
6. **Automate**: Add to CI/CD pipeline
7. **Monitor**: Regular test runs in production

## Best Practices Summary

1. **Test Early and Often**: Run tests frequently during development
2. **Automate Everything**: Include tests in CI/CD pipelines
3. **Keep Tests Fast**: Quick tests encourage frequent running
4. **Test Production Config**: Test with production-like configurations
5. **Monitor Test Trends**: Track test results over time
6. **Document Failures**: Keep notes on common failures and fixes
7. **Version Test Scripts**: Keep tests in version control
8. **Test Security**: Include security checks in test suite
9. **Load Test**: Include performance tests for production readiness
10. **Clean Test Data**: Always cleanup after tests complete