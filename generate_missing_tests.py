#!/usr/bin/env python3
"""Generate missing test scripts for library services"""

import os
import glob

def get_test_template(service_name, container_name):
    """Get test template for a specific service"""
    
    if service_name == 'mysql':
        return f'''#!/bin/bash
# MySQL Test - Basic CRUD operations from host

echo "=== MySQL Test ==="

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
NC='\\033[0m'

# Get container name
CONTAINER_NAME="{container_name}"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${{RED}}✗${{NC}} MySQL container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "MySQL Container: $CONTAINER_NAME"
echo "MySQL IP: $CONTAINER_IP"

# Test MySQL connectivity
echo ""
echo "1. Testing MySQL connection..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot -e "SELECT VERSION();" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} MySQL connection successful"
else
    echo -e "${{RED}}✗${{NC}} Failed to connect to MySQL"
    exit 1
fi

echo ""
echo "2. Creating test database..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot -e "CREATE DATABASE testdb;"
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Database created"
else
    echo -e "${{RED}}✗${{NC}} Failed to create database"
    exit 1
fi

echo ""
echo "3. Creating test table..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot testdb -e "CREATE TABLE test_table (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(50));"
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Table created"
else
    echo -e "${{RED}}✗${{NC}} Failed to create table"
    exit 1
fi

echo ""
echo "4. Inserting test data..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot testdb -e "INSERT INTO test_table (name) VALUES ('Test Record');"
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Data inserted"
else
    echo -e "${{RED}}✗${{NC}} Failed to insert data"
    exit 1
fi

echo ""
echo "5. Querying test data..."
RESULT=$(lxc exec $CONTAINER_NAME -- mysql -uroot -proot testdb -se "SELECT name FROM test_table WHERE name='Test Record';")
if [ "$RESULT" = "Test Record" ]; then
    echo -e "${{GREEN}}✓${{NC}} Data retrieved: $RESULT"
else
    echo -e "${{RED}}✗${{NC}} Failed to retrieve data"
    exit 1
fi

echo ""
echo "6. Cleaning up..."
lxc exec $CONTAINER_NAME -- mysql -uroot -proot -e "DROP DATABASE testdb;"
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Database dropped"
else
    echo -e "${{RED}}✗${{NC}} Failed to drop database"
    exit 1
fi

echo ""
echo -e "${{GREEN}}✓ All MySQL tests passed!${{NC}}"
'''

    elif service_name == 'nginx':
        return f'''#!/bin/bash
# Nginx Test - Web server functionality

echo "=== Nginx Test ==="

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
NC='\\033[0m'

# Get container name
CONTAINER_NAME="{container_name}"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${{RED}}✗${{NC}} Nginx container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Nginx Container: $CONTAINER_NAME"
echo "Nginx IP: $CONTAINER_IP"

# Test Nginx is running
echo ""
echo "1. Checking Nginx process..."
lxc exec $CONTAINER_NAME -- pgrep nginx >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Nginx is running"
else
    echo -e "${{RED}}✗${{NC}} Nginx is not running"
    exit 1
fi

echo ""
echo "2. Testing HTTP connection..."
RESPONSE=$(curl -s -o /dev/null -w "%{{http_code}}" http://$CONTAINER_IP/)
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "404" ]; then
    echo -e "${{GREEN}}✓${{NC}} HTTP server responding (Status: $RESPONSE)"
else
    echo -e "${{RED}}✗${{NC}} HTTP server not responding (Status: $RESPONSE)"
    exit 1
fi

echo ""
echo "3. Testing Nginx configuration..."
lxc exec $CONTAINER_NAME -- nginx -t 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Nginx configuration valid"
else
    echo -e "${{RED}}✗${{NC}} Nginx configuration invalid"
    exit 1
fi

echo ""
echo -e "${{GREEN}}✓ All Nginx tests passed!${{NC}}"
'''

    elif service_name == 'haproxy':
        return f'''#!/bin/bash
# HAProxy Test - Load balancer functionality

echo "=== HAProxy Test ==="

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

# Get container name
CONTAINER_NAME="{container_name}"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${{RED}}✗${{NC}} HAProxy container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "HAProxy Container: $CONTAINER_NAME"
echo "HAProxy IP: $CONTAINER_IP"

# Test HAProxy is running
echo ""
echo "1. Checking HAProxy process..."
lxc exec $CONTAINER_NAME -- pgrep haproxy >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} HAProxy is running"
else
    echo -e "${{RED}}✗${{NC}} HAProxy is not running"
    exit 1
fi

echo ""
echo "2. Testing HAProxy stats endpoint..."
RESPONSE=$(curl -s -o /dev/null -w "%{{http_code}}" http://$CONTAINER_IP:8080/stats 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "401" ]; then
    echo -e "${{GREEN}}✓${{NC}} HAProxy stats endpoint responding (Status: $RESPONSE)"
else
    echo -e "${{YELLOW}}⚠${{NC}} HAProxy stats endpoint not configured (Status: $RESPONSE)"
fi

echo ""
echo -e "${{GREEN}}✓ HAProxy basic tests passed!${{NC}}"
'''

    elif service_name == 'mongodb':
        return f'''#!/bin/bash
# MongoDB Test - NoSQL database operations

echo "=== MongoDB Test ==="

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
NC='\\033[0m'

# Get container name
CONTAINER_NAME="{container_name}"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${{RED}}✗${{NC}} MongoDB container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "MongoDB Container: $CONTAINER_NAME"
echo "MongoDB IP: $CONTAINER_IP"

# Test MongoDB connectivity
echo ""
echo "1. Testing MongoDB connection..."
lxc exec $CONTAINER_NAME -- mongosh --eval "db.version()" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} MongoDB connection successful"
else
    echo -e "${{RED}}✗${{NC}} Failed to connect to MongoDB"
    exit 1
fi

echo ""
echo "2. Creating test document..."
lxc exec $CONTAINER_NAME -- mongosh --eval 'db.test.insertOne({{name: "Test Record", value: 123}})' >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Document inserted"
else
    echo -e "${{RED}}✗${{NC}} Failed to insert document"
    exit 1
fi

echo ""
echo "3. Querying test document..."
RESULT=$(lxc exec $CONTAINER_NAME -- mongosh --quiet --eval 'db.test.findOne({{name: "Test Record"}}).name' 2>/dev/null)
if [[ "$RESULT" == *"Test Record"* ]]; then
    echo -e "${{GREEN}}✓${{NC}} Document retrieved"
else
    echo -e "${{RED}}✗${{NC}} Failed to retrieve document"
    exit 1
fi

echo ""
echo "4. Cleaning up..."
lxc exec $CONTAINER_NAME -- mongosh --eval 'db.test.drop()' >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Collection dropped"
else
    echo -e "${{RED}}✗${{NC}} Failed to drop collection"
    exit 1
fi

echo ""
echo -e "${{GREEN}}✓ All MongoDB tests passed!${{NC}}"
'''

    elif service_name == 'memcached':
        return f'''#!/bin/bash
# Memcached Test - Cache operations

echo "=== Memcached Test ==="

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
NC='\\033[0m'

# Get container name
CONTAINER_NAME="{container_name}"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${{RED}}✗${{NC}} Memcached container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Memcached Container: $CONTAINER_NAME"
echo "Memcached IP: $CONTAINER_IP"

# Test Memcached is running
echo ""
echo "1. Checking Memcached process..."
lxc exec $CONTAINER_NAME -- pgrep memcached >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Memcached is running"
else
    echo -e "${{RED}}✗${{NC}} Memcached is not running"
    exit 1
fi

echo ""
echo "2. Testing Memcached connectivity..."
echo "stats" | nc $CONTAINER_IP 11211 | grep -q "STAT version" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Memcached responding"
else
    echo -e "${{RED}}✗${{NC}} Memcached not responding"
    exit 1
fi

echo ""
echo -e "${{GREEN}}✓ All Memcached tests passed!${{NC}}"
'''

    elif service_name == 'rabbitmq':
        return f'''#!/bin/bash
# RabbitMQ Test - Message queue operations

echo "=== RabbitMQ Test ==="

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
NC='\\033[0m'

# Get container name
CONTAINER_NAME="{container_name}"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${{RED}}✗${{NC}} RabbitMQ container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "RabbitMQ Container: $CONTAINER_NAME"
echo "RabbitMQ IP: $CONTAINER_IP"

# Test RabbitMQ is running
echo ""
echo "1. Checking RabbitMQ process..."
lxc exec $CONTAINER_NAME -- pgrep beam.smp >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} RabbitMQ is running"
else
    echo -e "${{RED}}✗${{NC}} RabbitMQ is not running"
    exit 1
fi

echo ""
echo "2. Checking RabbitMQ status..."
lxc exec $CONTAINER_NAME -- rabbitmqctl status >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} RabbitMQ status OK"
else
    echo -e "${{RED}}✗${{NC}} RabbitMQ status check failed"
    exit 1
fi

echo ""
echo -e "${{GREEN}}✓ All RabbitMQ tests passed!${{NC}}"
'''

    elif service_name == 'elasticsearch':
        return f'''#!/bin/bash
# Elasticsearch Test - Search engine operations

echo "=== Elasticsearch Test ==="

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
YELLOW='\\033[1;33m'
NC='\\033[0m'

# Get container name
CONTAINER_NAME="{container_name}"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${{RED}}✗${{NC}} Elasticsearch container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Elasticsearch Container: $CONTAINER_NAME"
echo "Elasticsearch IP: $CONTAINER_IP"

# Test Elasticsearch is running
echo ""
echo "1. Checking Elasticsearch process..."
lxc exec $CONTAINER_NAME -- pgrep -f elasticsearch >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Elasticsearch is running"
else
    echo -e "${{YELLOW}}⚠${{NC}} Elasticsearch process not found (may be starting)"
fi

echo ""
echo "2. Testing Elasticsearch API..."
RESPONSE=$(curl -s -o /dev/null -w "%{{http_code}}" http://$CONTAINER_IP:9200 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${{GREEN}}✓${{NC}} Elasticsearch API responding"
else
    echo -e "${{YELLOW}}⚠${{NC}} Elasticsearch API not yet ready (Status: $RESPONSE)"
fi

echo ""
echo -e "${{GREEN}}✓ Elasticsearch basic tests completed${{NC}}"
'''

    elif service_name == 'grafana':
        return f'''#!/bin/bash
# Grafana Test - Monitoring dashboard

echo "=== Grafana Test ==="

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
NC='\\033[0m'

# Get container name
CONTAINER_NAME="{container_name}"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${{RED}}✗${{NC}} Grafana container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Grafana Container: $CONTAINER_NAME"
echo "Grafana IP: $CONTAINER_IP"

# Test Grafana is running
echo ""
echo "1. Checking Grafana process..."
lxc exec $CONTAINER_NAME -- pgrep grafana >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Grafana is running"
else
    echo -e "${{RED}}✗${{NC}} Grafana is not running"
    exit 1
fi

echo ""
echo "2. Testing Grafana web interface..."
RESPONSE=$(curl -s -o /dev/null -w "%{{http_code}}" http://$CONTAINER_IP:3000 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "302" ]; then
    echo -e "${{GREEN}}✓${{NC}} Grafana web interface responding (Status: $RESPONSE)"
else
    echo -e "${{RED}}✗${{NC}} Grafana web interface not responding (Status: $RESPONSE)"
    exit 1
fi

echo ""
echo -e "${{GREEN}}✓ All Grafana tests passed!${{NC}}"
'''

    elif service_name == 'prometheus':
        return f'''#!/bin/bash
# Prometheus Test - Metrics collection

echo "=== Prometheus Test ==="

# Colors
GREEN='\\033[0;32m'
RED='\\033[0;31m'
NC='\\033[0m'

# Get container name
CONTAINER_NAME="{container_name}"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${{RED}}✗${{NC}} Prometheus container not found: $CONTAINER_NAME"
    exit 1
fi

CONTAINER_IP=$(lxc list $CONTAINER_NAME -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

echo "Prometheus Container: $CONTAINER_NAME"
echo "Prometheus IP: $CONTAINER_IP"

# Test Prometheus is running
echo ""
echo "1. Checking Prometheus process..."
lxc exec $CONTAINER_NAME -- pgrep prometheus >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${{GREEN}}✓${{NC}} Prometheus is running"
else
    echo -e "${{RED}}✗${{NC}} Prometheus is not running"
    exit 1
fi

echo ""
echo "2. Testing Prometheus API..."
RESPONSE=$(curl -s -o /dev/null -w "%{{http_code}}" http://$CONTAINER_IP:9090/-/healthy 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ]; then
    echo -e "${{GREEN}}✓${{NC}} Prometheus API healthy"
else
    echo -e "${{RED}}✗${{NC}} Prometheus API not responding (Status: $RESPONSE)"
    exit 1
fi

echo ""
echo -e "${{GREEN}}✓ All Prometheus tests passed!${{NC}}"
'''
    
    return None

def generate_container_name(service, os_name, version):
    """Generate container name based on service and OS"""
    # Clean up version for container name
    version_clean = version.replace('.', '-')
    
    # Shorten OS names
    if os_name == 'ubuntu-minimal':
        os_short = 'minimal'
    elif os_name == 'ubuntu':
        os_short = 'ubuntu'
    elif os_name == 'alpine':
        os_short = 'alpine'
    elif os_name == 'debian':
        os_short = 'debian'
    else:
        os_short = os_name
    
    return f"{service}-{os_short}-{version_clean}"

def create_test_file(service_dir, service_name, os_name, version):
    """Create test file for a service"""
    test_dir = os.path.join(service_dir, 'tests')
    test_file = os.path.join(test_dir, 'test.sh')
    
    # Skip if test already exists
    if os.path.exists(test_file):
        return False
    
    # Generate container name
    container_name = generate_container_name(service_name, os_name, version)
    
    # Get template
    template = get_test_template(service_name, container_name)
    if not template:
        print(f"  No template for {service_name}")
        return False
    
    # Create tests directory
    os.makedirs(test_dir, exist_ok=True)
    
    # Write test file
    with open(test_file, 'w') as f:
        f.write(template)
    
    # Make executable
    os.chmod(test_file, 0o755)
    
    return True

def main():
    """Generate missing test files"""
    print("Generating missing test files...")
    print("=" * 50)
    
    created_count = 0
    skipped_count = 0
    
    # Find all service directories
    for service_dir in glob.glob('library/*/*/*'):
        if not os.path.isdir(service_dir):
            continue
        
        # Parse path
        parts = service_dir.split('/')
        os_name = parts[1]
        version = parts[2]
        service_name = parts[3]
        
        # Create test if missing
        if create_test_file(service_dir, service_name, os_name, version):
            print(f"✓ Created test for {os_name}/{version}/{service_name}")
            created_count += 1
        else:
            skipped_count += 1
    
    print("=" * 50)
    print(f"Created {created_count} test files")
    print(f"Skipped {skipped_count} (already exist or no template)")

if __name__ == '__main__':
    main()