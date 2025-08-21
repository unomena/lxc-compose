#!/bin/bash
# Port forwarding tests for documentation server
set -e

CONTAINER=${1:-lxc-docs}

echo "========================================"
echo "Port Forwarding Tests for Documentation Server"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list $CONTAINER -c 4 --format csv | cut -d' ' -f1)
if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗ FAIL${NC} - Cannot determine container IP"
    exit 1
fi
echo "Container IP: $CONTAINER_IP"

# Test function for iptables rules
test_iptables_rule() {
    local port=$1
    local description=$2
    local should_exist=$3
    
    echo -n "Testing $description... "
    
    if sudo iptables -t nat -L PREROUTING -n | grep -q "dpt:$port.*DNAT.*${CONTAINER_IP}:$port"; then
        if [ "$should_exist" = "true" ]; then
            echo -e "${GREEN}✓ PASS${NC} (Port $port forwarded)"
            return 0
        else
            echo -e "${RED}✗ FAIL${NC} (Port $port should NOT be forwarded)"
            return 1
        fi
    else
        if [ "$should_exist" = "false" ]; then
            echo -e "${GREEN}✓ PASS${NC} (Port $port correctly not forwarded)"
            return 0
        else
            echo -e "${RED}✗ FAIL${NC} (Port $port not forwarded)"
            return 1
        fi
    fi
}

# Test FORWARD chain rules
test_forward_rule() {
    local port=$1
    local description=$2
    
    echo -n "Testing FORWARD rule for $description... "
    
    if sudo iptables -L FORWARD -n | grep -q "${CONTAINER_IP}.*dpt:$port"; then
        echo -e "${GREEN}✓ PASS${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ WARNING${NC} (No explicit FORWARD rule)"
        return 0  # Warning, not failure
    fi
}

echo ""
echo "DNAT Rules (Port Forwarding):"
test_iptables_rule 80 "HTTP port (80)" true
test_iptables_rule 8000 "MkDocs dev port (8000)" true
test_iptables_rule 443 "HTTPS port (443)" false  # Should not be exposed
test_iptables_rule 22 "SSH port (22)" false       # Should not be exposed
test_iptables_rule 3306 "MySQL port (3306)" false # Should not be exposed

echo ""
echo "FORWARD Chain Rules:"
test_forward_rule 80 "HTTP port (80)"
test_forward_rule 8000 "MkDocs dev port (8000)"

echo ""
echo "Security Checks:"

# Check that only specified ports are exposed
echo -n "Checking for unexpected port forwarding... "
unexpected_ports=$(sudo iptables -t nat -L PREROUTING -n | grep "DNAT.*${CONTAINER_IP}" | grep -v "dpt:80\|dpt:8000" || true)
if [ -z "$unexpected_ports" ]; then
    echo -e "${GREEN}✓ PASS${NC} (No unexpected ports)"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Unexpected rules found:"
    echo "$unexpected_ports"
fi

# Check comment tags
echo -n "Checking iptables rule comments... "
if sudo iptables -t nat -L PREROUTING -n -v | grep -q "lxc-compose.*$CONTAINER"; then
    echo -e "${GREEN}✓ PASS${NC} (Rules properly tagged)"
else
    echo -e "${YELLOW}⚠ WARNING${NC} (Rules not tagged with lxc-compose)"
fi

# Verify actual connectivity through forwarded ports
echo ""
echo "Connectivity Through Forwarded Ports:"

echo -n "Testing port 80 connectivity... "
if timeout 2 nc -zv localhost 80 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -n "Testing direct container access (should work internally)... "
if timeout 2 nc -zv $CONTAINER_IP 80 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Summary
echo ""
echo "========================================"
echo "Summary:"
sudo iptables -t nat -L PREROUTING -n | grep "$CONTAINER_IP" | wc -l | xargs echo "Total DNAT rules for container:"
sudo iptables -L FORWARD -n | grep "$CONTAINER_IP" | wc -l | xargs echo "Total FORWARD rules for container:"
echo "========================================"
echo "Port forwarding tests completed!"
echo "========================================"