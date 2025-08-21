#!/bin/bash
# Port Forwarding Tests for PostgreSQL Server
# Verify iptables rules and port accessibility

echo "=== Port Forwarding Tests for PostgreSQL Server ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Get container IP
CONTAINER_IP=$(lxc list postgresql-server -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "PostgreSQL Server IP: $CONTAINER_IP"
echo ""

# Function to check test result
check_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $2"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo -e "${BLUE}=== Checking PostgreSQL Port Configuration ===${NC}"

# Check if port 5432 is in exposed_ports
echo -e "${BLUE}Checking port 5432 configuration${NC}"
grep -q "5432" ~/lxc-samples/postgresql-server/lxc-compose.yml
check_result $? "Port 5432 is configured in lxc-compose.yml"

# Check for iptables DNAT rules (if port forwarding is enabled)
echo -e "${BLUE}Checking for port forwarding rules${NC}"
DNAT_RULE=$(sudo iptables -t nat -L PREROUTING -n | grep "dpt:5432.*${CONTAINER_IP}:5432")
if [ -n "$DNAT_RULE" ]; then
    echo -e "  ${YELLOW}⚠${NC} Port forwarding rule found for 5432 -> ${CONTAINER_IP}:5432"
    echo -e "  ${BLUE}ℹ${NC} This allows external access to PostgreSQL"
else
    echo -e "  ${BLUE}ℹ${NC} No port forwarding configured (container-only access)"
fi

# Check if PostgreSQL port is accessible from host
echo -e "${BLUE}Testing PostgreSQL port accessibility from host${NC}"
timeout 2 nc -zv $CONTAINER_IP 5432 > /dev/null 2>&1
check_result $? "PostgreSQL port 5432 is accessible from host"

# Security check - ensure other ports are not exposed
echo -e "${BLUE}=== Security Verification ===${NC}"
echo "Checking that only PostgreSQL port is exposed..."

# Check for unexpected open ports
OPEN_PORTS=$(lxc exec postgresql-server -- netstat -tln | grep LISTEN | grep -v "127.0.0.1" | awk '{print $4}' | sed 's/.*://' | sort -u)
EXPECTED_PORTS="5432"

for port in $OPEN_PORTS; do
    if [ "$port" = "5432" ]; then
        check_result 0 "Port $port is correctly exposed (PostgreSQL)"
    else
        check_result 1 "Unexpected port $port is exposed"
    fi
done

# Check container firewall rules
echo -e "${BLUE}Checking container network isolation${NC}"
# PostgreSQL should only be accessible on port 5432
OTHER_PORTS="22 80 443 3306 6379 8080"
for port in $OTHER_PORTS; do
    timeout 1 nc -zv $CONTAINER_IP $port > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        check_result 0 "Port $port is correctly blocked"
    else
        check_result 1 "Port $port should not be accessible"
    fi
done

echo ""
echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}Port Forwarding Test Summary${NC}"
echo -e "${BLUE}===================================================${NC}"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All port forwarding tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some port forwarding tests failed!${NC}"
    exit 1
fi