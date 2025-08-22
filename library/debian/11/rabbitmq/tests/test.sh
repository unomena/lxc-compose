#!/bin/bash
# RabbitMQ Test - Message queue operations

echo "=== RabbitMQ Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container name
CONTAINER_NAME="rabbitmq-debian-11"
if ! lxc info $CONTAINER_NAME >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} RabbitMQ container not found: $CONTAINER_NAME"
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
    echo -e "${GREEN}✓${NC} RabbitMQ is running"
else
    echo -e "${RED}✗${NC} RabbitMQ is not running"
    exit 1
fi

echo ""
echo "2. Checking RabbitMQ status..."
lxc exec $CONTAINER_NAME -- rabbitmqctl status >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} RabbitMQ status OK"
else
    echo -e "${RED}✗${NC} RabbitMQ status check failed"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All RabbitMQ tests passed!${NC}"
