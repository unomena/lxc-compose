#!/bin/bash
# Port forwarding tests for SearXNG application
# Checks iptables rules and tests actual port forwarding

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

echo "=== Port Forwarding Tests for SearXNG ==="
echo

# Get container IP
APP_IP=$(lxc list sample-searxng-app -c 4 --format csv | cut -d' ' -f1)

if [ -z "$APP_IP" ]; then
    echo -e "${RED}✗${NC} Container IP not found!"
    exit 1
fi

echo "Container IP: ${APP_IP}"
echo

# Define expected port mappings
declare -A EXPECTED_PORTS=(
    ["80"]="nginx"
)

# Function to check if port is forwarded in iptables
check_iptables_forward() {
    local container_ip=$1
    local port=$2
    local service=$3
    
    echo -e "\n${BLUE}Checking port $port ($service) for IP $container_ip${NC}"
    
    # Check PREROUTING chain for DNAT rules (port forwarding TO container)
    DNAT_RULE=$(sudo iptables -t nat -L PREROUTING -n -v | grep -E "dpt:$port.*to:$container_ip:$port")
    
    if [ -n "$DNAT_RULE" ]; then
        echo -e "  DNAT rule found: ${GREEN}✓${NC}"
        echo "    $DNAT_RULE"
        
        # Test if the port actually responds
        echo -n "  Testing port response... "
        if timeout 2 nc -zv localhost $port 2>&1 | grep -q "succeeded\|open"; then
            echo -e "${GREEN}✓${NC} Port is accessible"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "${RED}✗${NC} Port is not responding (but rule exists)"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} No DNAT rule found for port $port -> $container_ip:$port"
        
        # Check if port is exposed but not forwarded
        if lxc config show sample-searxng-app 2>/dev/null | grep -q "proxy.*$port" || \
           lxc config device show sample-searxng-app 2>/dev/null | grep -q "$port"; then
            echo -e "  ${YELLOW}⚠${NC} Port $port is exposed by container but not forwarded in iptables!"
            ((WARNINGS++))
        else
            echo -e "  ${BLUE}ℹ${NC} Port $port is not configured for forwarding"
        fi
        return 1
    fi
}

# Function to check for orphaned iptables rules
check_orphaned_rules() {
    local container_ip=$1
    
    echo -e "\n${BLUE}Checking for orphaned rules for $container_ip${NC}"
    
    # Get all DNAT rules pointing to this container IP
    RULES=$(sudo iptables -t nat -L PREROUTING -n -v | grep "to:$container_ip" | grep -oE "dpt:[0-9]+" | cut -d: -f2 | sort -u)
    
    if [ -z "$RULES" ]; then
        echo "  No forwarding rules found for this container"
        return
    fi
    
    echo "  Found forwarded ports: $(echo $RULES | tr '\n' ' ')"
    
    # Check each rule against expected ports
    for port in $RULES; do
        local found=0
        
        for expected_port in "${!EXPECTED_PORTS[@]}"; do
            if [ "$port" == "$expected_port" ]; then
                found=1
                break
            fi
        done
        
        if [ $found -eq 0 ]; then
            echo -e "  ${YELLOW}⚠${NC} Unexpected forwarding rule for port $port"
            ((WARNINGS++))
        fi
    done
}

# Test all expected ports
echo -e "\n${BLUE}=== Testing Container Port Forwarding ===${NC}"
for port in "${!EXPECTED_PORTS[@]}"; do
    check_iptables_forward "$APP_IP" "$port" "${EXPECTED_PORTS[$port]}"
done
check_orphaned_rules "$APP_IP"

# Check for any lxc-compose managed rules
echo -e "\n${BLUE}=== Checking lxc-compose iptables management ===${NC}"
LXC_COMPOSE_RULES=$(sudo iptables -L -n -v | grep -c "lxc-compose" 2>/dev/null || echo "0")
echo "Found $LXC_COMPOSE_RULES lxc-compose related rules in iptables"

# Summary
echo -e "\n${BLUE}==================================================${NC}"
echo -e "${BLUE}Port Forwarding Test Summary${NC}"
echo -e "${BLUE}==================================================${NC}"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

if [ $TESTS_FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All port forwarding tests passed!${NC}"
    exit 0
elif [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${YELLOW}⚠ Tests passed with warnings${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some port forwarding tests failed!${NC}"
    exit 1
fi