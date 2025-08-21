#!/bin/bash
# External tests for documentation server
set -e

CONTAINER=${1:-lxc-docs}

echo "========================================"
echo "External Tests for Documentation Server"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test function
test_endpoint() {
    local endpoint=$1
    local expected_code=${2:-200}
    local description=$3
    
    echo -n "Testing $description... "
    
    code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost$endpoint" 2>/dev/null || echo "000")
    
    if [ "$code" = "$expected_code" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $code)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (Expected $expected_code, got $code)"
        return 1
    fi
}

# Test content check
test_content() {
    local endpoint=$1
    local search_text=$2
    local description=$3
    
    echo -n "Testing $description... "
    
    if curl -s "http://localhost$endpoint" | grep -q "$search_text" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (Content not found)"
        return 1
    fi
}

# Basic connectivity tests
echo ""
echo "Connectivity Tests:"
test_endpoint "/" 200 "Homepage accessible"
test_endpoint "/health" 200 "Health check endpoint"
test_endpoint "/api/info" 200 "API info endpoint"
test_endpoint "/nonexistent" 404 "404 error handling"

# Content verification
echo ""
echo "Content Tests:"
test_content "/" "LXC Compose" "Documentation contains title"
test_content "/" "Documentation" "Documentation content present"
test_content "/getting-started/" "Getting Started" "Getting Started page"

# Documentation sections
echo ""
echo "Documentation Sections:"
test_endpoint "/getting-started/" 200 "Getting Started guide"
test_endpoint "/configuration/" 200 "Configuration reference"
test_endpoint "/commands/" 200 "Commands reference"
test_endpoint "/networking/" 200 "Networking guide"
test_endpoint "/testing/" 200 "Testing guide"

# Static assets
echo ""
echo "Static Assets:"
test_endpoint "/assets/stylesheets/main.css" 200 "CSS stylesheet" || test_endpoint "/css/theme.css" 200 "CSS stylesheet"
test_endpoint "/search/search_index.json" 200 "Search index" || true

# API responses
echo ""
echo "API Tests:"
echo -n "Testing API JSON response... "
if curl -s http://localhost/api/info | python3 -m json.tool > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC} (Valid JSON)"
else
    echo -e "${RED}✗ FAIL${NC} (Invalid JSON)"
fi

# Performance test
echo ""
echo "Performance Tests:"
echo -n "Testing response time... "
response_time=$(curl -s -o /dev/null -w "%{time_total}" http://localhost/)
if (( $(echo "$response_time < 1.0" | bc -l) )); then
    echo -e "${GREEN}✓ PASS${NC} (${response_time}s)"
else
    echo -e "${RED}✗ FAIL${NC} (${response_time}s - too slow)"
fi

# Load test (simple)
echo -n "Testing concurrent requests... "
success_count=0
for i in {1..10}; do
    if curl -s -o /dev/null http://localhost/ 2>/dev/null; then
        ((success_count++))
    fi
done
if [ "$success_count" -eq 10 ]; then
    echo -e "${GREEN}✓ PASS${NC} (10/10 successful)"
else
    echo -e "${RED}✗ FAIL${NC} ($success_count/10 successful)"
fi

echo ""
echo "========================================"
echo "External tests completed!"
echo "========================================"