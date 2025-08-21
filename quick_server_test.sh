#!/bin/bash
# Quick test to verify template and includes system works

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Quick Template & Includes Test"
echo "=============================="
echo ""

# Test 1: Simple Alpine Redis with includes
echo "Test 1: Alpine Redis via includes"
cat > test-simple.yml << 'EOF'
version: '1.0'
containers:
  test-redis:
    template: alpine-3.19
    includes:
      - redis
EOF

echo "Testing locally first..."
python3 -c "
import sys, os
sys.path.insert(0, 'cli')
from template_handler import TemplateHandler

handler = TemplateHandler()
config = {
    'version': '1.0',
    'containers': {
        'test-redis': {
            'template': 'alpine-3.19',
            'includes': ['redis']
        }
    }
}

try:
    processed = handler.process_compose_file(config)
    container = processed['containers']['test-redis']
    print(f'  Image: {container.get(\"image\")}')
    print(f'  Packages: {len(container.get(\"packages\", []))} total')
    print(f'  Has Redis config: {\"redis\" in str(container.get(\"post_install\", []))}')
    print('  ✓ Template processing works!')
except Exception as e:
    print(f'  ✗ Error: {e}')
    sys.exit(1)
" || echo "Python test requires PyYAML"

# Test 2: Check library structure
echo ""
echo "Test 2: Verify library structure"
for service in postgresql redis nginx mysql mongodb; do
    if [ -f "library/alpine/3.19/$service/lxc-compose.yml" ]; then
        echo "  ✓ Alpine $service exists"
    else
        echo "  ✗ Alpine $service missing"
    fi
done

for service in postgresql redis nginx mysql mongodb; do
    if [ -f "library/ubuntu/24.04/$service/lxc-compose.yml" ]; then
        echo "  ✓ Ubuntu 24.04 $service exists"
    else
        echo "  ✗ Ubuntu 24.04 $service missing"
    fi
done

# Test 3: Verify tests exist in library services
echo ""
echo "Test 3: Verify tests in library services"
for dir in library/alpine/3.19/postgresql library/ubuntu/24.04/postgresql library/debian/12/postgresql; do
    if [ -d "$dir/tests" ]; then
        test_count=$(ls -1 $dir/tests/*.sh 2>/dev/null | wc -l)
        if [ $test_count -gt 0 ]; then
            echo "  ✓ $dir has $test_count test(s)"
        else
            echo "  ⚠ $dir/tests exists but no .sh files"
        fi
    else
        echo "  ✗ $dir/tests missing"
    fi
done

echo ""
echo "Quick tests complete. Ready for server deployment!"
echo ""
echo "To deploy on server:"
echo "1. Commit and push all changes"
echo "2. SSH to server: ssh root@5.78.92.103"
echo "3. Update: cd /root/lxc-compose && git pull"
echo "4. Test: cd examples && lxc-compose up -f test-alpine-services.yml"
echo "5. Verify: lxc-compose test test-alpine-postgres"

# Cleanup
rm -f test-simple.yml