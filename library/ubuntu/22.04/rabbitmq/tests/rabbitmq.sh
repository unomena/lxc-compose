#!/bin/bash
# RabbitMQ Test - Basic functionality from host

echo "=== RabbitMQ Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list rabbitmq-ubuntu-22-04 -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "RabbitMQ IP: $CONTAINER_IP"
echo ""

# Test 1: Check if RabbitMQ AMQP port is open
echo "1. Testing AMQP port 5672..."
if nc -zv $CONTAINER_IP 5672 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} AMQP port 5672 is open"
else
    echo -e "${RED}✗${NC} AMQP port 5672 is not accessible"
    exit 1
fi

# Test 2: Check Management UI port
echo "2. Testing Management UI port 15672..."
if nc -zv $CONTAINER_IP 15672 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} Management UI port 15672 is open"
else
    echo -e "${RED}✗${NC} Management UI port 15672 is not accessible"
    exit 1
fi

# Test 3: Check Management API
echo "3. Testing Management API..."
USER=${RABBITMQ_DEFAULT_USER:-admin}
PASS=${RABBITMQ_DEFAULT_PASS:-admin}
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -u $USER:$PASS http://$CONTAINER_IP:15672/api/overview)
if [ "$RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓${NC} Management API accessible"
else
    echo -e "${RED}✗${NC} Management API returned HTTP $RESPONSE"
    exit 1
fi

# Test 4: Check RabbitMQ process
echo "4. Checking RabbitMQ process..."
if lxc exec rabbitmq-ubuntu-22-04 -- pgrep -f rabbitmq-ubuntu-22-04 > /dev/null; then
    echo -e "${GREEN}✓${NC} RabbitMQ process is running"
else
    echo -e "${RED}✗${NC} RabbitMQ process not found"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All RabbitMQ tests passed!${NC}"
exit 0