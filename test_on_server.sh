#!/bin/bash
# Test script for server at 192.168.64.47

set -e

SERVER="192.168.64.47"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "LXC Compose Template & Includes Testing"
echo "Server: $SERVER"
echo "========================================"
echo ""

# Try to connect to server
echo "Testing connection to $SERVER..."
if ping -c 1 $SERVER >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Server is reachable${NC}"
else
    echo -e "${RED}✗ Cannot reach server at $SERVER${NC}"
    echo ""
    echo "Please verify:"
    echo "1. Server IP is correct (192.168.64.47)"
    echo "2. You're on the same network"
    echo "3. Server is running"
    exit 1
fi

echo ""
echo "Manual testing steps for server $SERVER:"
echo "========================================="
echo ""
echo "1. SSH to server:"
echo "   ssh root@$SERVER"
echo "   # or"
echo "   ssh user@$SERVER"
echo ""
echo "2. Navigate to project:"
echo "   cd /path/to/lxc-compose"
echo "   # Update from git"
echo "   git pull origin main"
echo ""
echo "3. Test Alpine services with includes:"
echo "   cd examples"
echo "   sudo lxc-compose up -f test-alpine-services.yml"
echo "   sudo lxc-compose list"
echo "   sudo lxc-compose test test-alpine-postgres"
echo "   sudo lxc-compose test test-alpine-redis"
echo "   sudo lxc-compose destroy -f test-alpine-services.yml"
echo ""
echo "4. Test Ubuntu services:"
echo "   sudo lxc-compose up -f test-ubuntu-services.yml"
echo "   sudo lxc-compose test test-ubuntu-postgres"
echo "   sudo lxc-compose destroy -f test-ubuntu-services.yml"
echo ""
echo "5. Test includes inheritance:"
echo "   sudo lxc-compose up -f includes-example.yml"
echo "   sudo lxc-compose test database   # Should run PostgreSQL tests"
echo "   sudo lxc-compose test cache      # Should run Redis tests"
echo "   sudo lxc-compose test webserver  # Should run Nginx tests"
echo "   sudo lxc-compose destroy -f includes-example.yml"
echo ""
echo "Expected results:"
echo "=================="
echo ""
echo "For PostgreSQL containers:"
echo "  ✓ Connection test"
echo "  ✓ Database creation"
echo "  ✓ Table operations"
echo "  ✓ CRUD operations"
echo ""
echo "For Redis containers:"
echo "  ✓ Connection test"
echo "  ✓ SET/GET operations"
echo "  ✓ List operations"
echo "  ✓ Hash operations"
echo ""
echo "For Nginx containers:"
echo "  ✓ Configuration test"
echo "  ✓ HTTP response test"
echo "  ✓ Port availability"
echo ""

# Create a simple test file to copy to server
cat > simple_test.yml << 'EOF'
# Simple test to verify includes work
version: '1.0'

containers:
  # Test 1: Alpine PostgreSQL via includes
  test-pg:
    template: alpine-3.19
    includes:
      - postgresql
    environment:
      POSTGRES_PASSWORD: testpass123
  
  # Test 2: Ubuntu Redis via includes  
  test-cache:
    template: ubuntu-lts
    includes:
      - redis
  
  # Test 3: Debian Nginx via includes
  test-web:
    template: debian-bookworm
    includes:
      - nginx
EOF

echo "Created simple_test.yml for testing"
echo ""
echo "To copy and test this file:"
echo "  scp simple_test.yml root@$SERVER:/tmp/"
echo "  ssh root@$SERVER"
echo "  cd /path/to/lxc-compose"
echo "  sudo lxc-compose up -f /tmp/simple_test.yml"
echo "  sudo lxc-compose test test-pg    # Should have PostgreSQL tests"
echo "  sudo lxc-compose test test-cache # Should have Redis tests"
echo "  sudo lxc-compose test test-web   # Should have Nginx tests"
echo "  sudo lxc-compose destroy -f /tmp/simple_test.yml"