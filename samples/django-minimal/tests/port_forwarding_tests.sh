#!/bin/bash
# =============================================================================
# Port Forwarding and Network Security Tests for Django Minimal
# =============================================================================
# This script verifies network configuration and security policies.
# It tests:
# - iptables DNAT rules for port forwarding
# - FORWARD chain policies for security
# - Container isolation and access control
# - Network performance and latency
# - Security boundaries between containers
#
# Usage: Automatically run by 'lxc-compose test sample-django-minimal-app port_forwarding'
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
WARNINGS=0

echo "=============================================="
echo "Port Forwarding & Network Security Tests"
echo "=============================================="
echo

# Get container IPs
APP_IP=$(lxc list sample-django-minimal-app -c 4 --format csv | cut -d' ' -f1)
DB_IP=$(lxc list sample-django-minimal-database -c 4 --format csv | cut -d' ' -f1)

if [ -z "$APP_IP" ]; then
    echo -e "${RED}✗${NC} Django app container IP not found!"
    exit 1
fi

if [ -z "$DB_IP" ]; then
    echo -e "${RED}✗${NC} Database container IP not found!"
    exit 1
fi

echo "Django App Container IP: ${APP_IP}"
echo "Database Container IP: ${DB_IP}"
echo

# Define expected port mappings
# Django app should have port 8000 exposed
# Database should NOT be exposed to host (only inter-container)
declare -A EXPECTED_APP_PORTS=(
    ["8000"]="django"
)

declare -A EXPECTED_DB_PORTS=(
    # PostgreSQL port 5432 should NOT be forwarded for security
)

# -----------------------------------------------------------------------------
# Function to check if port is forwarded in iptables
# -----------------------------------------------------------------------------
check_iptables_forward() {
    local container_ip=$1
    local port=$2
    local service=$3
    
    echo -n "  Checking port $port ($service)... "
    
    # Check PREROUTING chain for DNAT rules (port forwarding TO container)
    DNAT_RULE=$(sudo iptables -t nat -L PREROUTING -n -v | grep -E "dpt:$port.*to:$container_ip:$port")
    
    if [ -n "$DNAT_RULE" ]; then
        echo -e "${GREEN}✓${NC} DNAT rule exists"
        
        # Test if the port actually responds
        echo -n "    Testing port response... "
        if timeout 2 nc -zv localhost $port 2>&1 | grep -q "succeeded\|open"; then
            echo -e "${GREEN}✓${NC} Port is accessible"
            ((TESTS_PASSED++))
            return 0
        else
            echo -e "${RED}✗${NC} Port not responding (rule exists but not working)"
            ((TESTS_FAILED++))
            return 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} No DNAT rule found"
        
        # This might be expected (e.g., database should not be forwarded)
        if [ "$service" == "postgresql_security" ]; then
            echo "    (This is expected for security - database should not be exposed)"
            ((TESTS_PASSED++))
            return 0
        else
            ((WARNINGS++))
            return 1
        fi
    fi
}

# -----------------------------------------------------------------------------
# Function to check for security violations
# -----------------------------------------------------------------------------
check_security_violations() {
    local container_ip=$1
    local container_name=$2
    
    echo "  Checking $container_name security..."
    
    # Get all DNAT rules pointing to this container IP
    RULES=$(sudo iptables -t nat -L PREROUTING -n -v | grep "to:$container_ip" | grep -oE "dpt:[0-9]+" | cut -d: -f2 | sort -u)
    
    if [ -z "$RULES" ]; then
        echo -e "    No forwarding rules... ${GREEN}✓${NC}"
        return 0
    fi
    
    # For database container, ANY forwarding is a violation
    if [[ "$container_name" == *"database"* ]]; then
        echo -e "    ${RED}✗${NC} Database has forwarded ports: $(echo $RULES | tr '\n' ' ')"
        echo -e "    ${RED}SECURITY VIOLATION:${NC} Database should not be exposed to host!"
        ((TESTS_FAILED++))
        return 1
    fi
    
    echo -e "    Forwarded ports: $(echo $RULES | tr '\n' ' ') ${GREEN}✓${NC}"
    return 0
}

# -----------------------------------------------------------------------------
# Port Forwarding Tests
# -----------------------------------------------------------------------------
echo "Port Forwarding Configuration:"
echo "------------------------------"

# Test Django app port forwarding
echo "Django App Container ($APP_IP):"
for port in "${!EXPECTED_APP_PORTS[@]}"; do
    check_iptables_forward "$APP_IP" "$port" "${EXPECTED_APP_PORTS[$port]}"
done

echo
echo "Database Container ($DB_IP):"
# Database should NOT have port forwarding for security
check_iptables_forward "$DB_IP" "5432" "postgresql_security"

echo

# -----------------------------------------------------------------------------
# Security Tests
# -----------------------------------------------------------------------------
echo "Security Configuration:"
echo "----------------------"
check_security_violations "$APP_IP" "django-app"
check_security_violations "$DB_IP" "database"

echo

# -----------------------------------------------------------------------------
# FORWARD Chain Policy Tests
# -----------------------------------------------------------------------------
echo "FORWARD Chain Security:"
echo "----------------------"

# Check if FORWARD chain has proper rules
echo -n "  Checking FORWARD chain policy... "
FORWARD_POLICY=$(sudo iptables -L FORWARD -n | head -1 | grep -oE "policy [A-Z]+" | cut -d' ' -f2)
if [ "$FORWARD_POLICY" == "DROP" ] || [ "$FORWARD_POLICY" == "REJECT" ]; then
    echo -e "${GREEN}✓${NC} Secure (policy: $FORWARD_POLICY)"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Permissive (policy: $FORWARD_POLICY)"
    ((WARNINGS++))
fi

# Check for specific ACCEPT rules for our containers
echo -n "  Checking Django app FORWARD rules... "
APP_FORWARD=$(sudo iptables -L FORWARD -n -v | grep "$APP_IP" | grep "8000.*ACCEPT")
if [ -n "$APP_FORWARD" ]; then
    echo -e "${GREEN}✓${NC} Found ACCEPT rule for port 8000"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} No specific ACCEPT rule found"
    ((WARNINGS++))
fi

echo

# -----------------------------------------------------------------------------
# Inter-container Communication Tests
# -----------------------------------------------------------------------------
echo "Inter-container Communication:"
echo "-----------------------------"

# Test if Django app can reach database
echo -n "  Django -> Database connectivity... "
if lxc exec sample-django-minimal-app -- nc -zv $DB_IP 5432 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} Connected"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗${NC} Cannot connect"
    ((TESTS_FAILED++))
fi

# Test if database cannot reach Django (one-way communication)
echo -n "  Database -> Django isolation... "
if ! lxc exec sample-django-minimal-database -- nc -zv $APP_IP 8000 2>&1 | grep -q succeeded; then
    echo -e "${GREEN}✓${NC} Properly isolated"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Can connect (may be intentional)"
    ((WARNINGS++))
fi

echo

# -----------------------------------------------------------------------------
# Network Performance Tests
# -----------------------------------------------------------------------------
echo "Network Performance:"
echo "-------------------"

# Test latency to Django app
echo -n "  Latency to Django app... "
PING_TIME=$(ping -c 3 -q $APP_IP 2>/dev/null | grep "avg" | cut -d'/' -f5)
if [ -n "$PING_TIME" ]; then
    if (( $(echo "$PING_TIME < 1.0" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${GREEN}✓${NC} Excellent (${PING_TIME}ms)"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} High (${PING_TIME}ms)"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} Cannot measure"
    ((TESTS_FAILED++))
fi

echo

# -----------------------------------------------------------------------------
# Check for lxc-compose managed rules
# -----------------------------------------------------------------------------
echo "LXC-Compose Integration:"
echo "-----------------------"
LXC_COMPOSE_NAT=$(sudo iptables -t nat -L -n -v | grep -c "lxc-compose\|lxc_compose" 2>/dev/null || echo "0")
LXC_COMPOSE_FILTER=$(sudo iptables -L -n -v | grep -c "lxc-compose\|lxc_compose" 2>/dev/null || echo "0")
echo "  NAT table rules: $LXC_COMPOSE_NAT"
echo "  Filter table rules: $LXC_COMPOSE_FILTER"

echo
echo "=============================================="
echo "Port Forwarding Test Summary"
echo "=============================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

if [ $TESTS_FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All port forwarding and security tests passed!${NC}"
    echo "Network configuration is secure and properly configured."
    exit 0
elif [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${YELLOW}⚠ Tests passed with warnings${NC}"
    echo "Review warnings above for potential improvements."
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed!${NC}"
    echo "Debug commands:"
    echo "  sudo iptables -t nat -L PREROUTING -n -v | grep $APP_IP"
    echo "  sudo iptables -L FORWARD -n -v | grep $APP_IP"
    exit 1
fi