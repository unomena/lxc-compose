#!/bin/bash
# Internal tests for documentation server
set -e

echo "========================================"
echo "Internal Tests for Documentation Server"
echo "========================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test function
test_check() {
    local test_name=$1
    local test_cmd=$2
    
    echo -n "Testing $test_name... "
    if eval $test_cmd > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        return 1
    fi
}

# Check if services are running
echo ""
echo "Service Checks:"
test_check "Nginx running" "pgrep nginx"
test_check "Nginx config valid" "nginx -t"

# Check if repository was cloned
echo ""
echo "Repository Checks:"
test_check "Repository exists" "[ -d /opt/lxc-compose ]"
test_check "Docs directory exists" "[ -d /opt/lxc-compose/docs ]"
test_check "Git repository valid" "cd /opt/lxc-compose && git status"

# Check if documentation was built
echo ""
echo "Documentation Build:"
test_check "Site directory exists" "[ -d /opt/lxc-compose/docs/site ]"
test_check "Index.html exists" "[ -f /opt/lxc-compose/docs/site/index.html ]"
test_check "MkDocs config exists" "[ -f /opt/lxc-compose/docs/mkdocs.yml ]"

# Check Python environment
echo ""
echo "Python Environment:"
test_check "Virtual environment exists" "[ -d /opt/lxc-compose/docs/.venv ]"
test_check "MkDocs installed" "/opt/lxc-compose/docs/.venv/bin/mkdocs --version"
test_check "Python packages installed" "/opt/lxc-compose/docs/.venv/bin/pip list | grep -q mkdocs"

# Check helper scripts
echo ""
echo "Helper Scripts:"
test_check "Rebuild script exists" "[ -f /docs/scripts/rebuild-docs.sh ]"
test_check "Manual rebuild script exists" "[ -f /docs/scripts/manual-rebuild.sh ]"
test_check "Dev server script exists" "[ -f /docs/scripts/start-dev.sh ]"
test_check "Scripts are executable" "[ -x /docs/scripts/rebuild-docs.sh ]"

# Check Nginx is serving content
echo ""
echo "Web Server:"
test_check "Port 80 listening" "netstat -tln | grep -q ':80 '"
test_check "Nginx responds locally" "curl -f http://localhost/health"
test_check "Documentation accessible" "curl -f http://localhost/ | grep -q 'LXC Compose'"

# Check logs
echo ""
echo "Logging:"
test_check "Nginx log exists" "[ -f /var/log/nginx.log ]"
test_check "Build log exists" "[ -f /var/log/build.log ] || true"

echo ""
echo "========================================"
echo "Internal tests completed!"
echo "========================================"