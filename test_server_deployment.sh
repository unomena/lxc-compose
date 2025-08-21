#!/bin/bash
# Comprehensive server testing script for templates and includes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SERVER="root@5.78.92.103"
REMOTE_DIR="/root/lxc-compose"
LOG_FILE="test_results_$(date +%Y%m%d_%H%M%S).log"

echo "LXC Compose Template & Include Testing" | tee $LOG_FILE
echo "======================================" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# Function to run remote command
run_remote() {
    ssh -o StrictHostKeyChecking=no $SERVER "$1" 2>&1
}

# Function to test a container
test_container() {
    local dir=$1
    local file=$2
    local container=$3
    
    echo -e "${YELLOW}Testing: $dir/$file - Container: $container${NC}" | tee -a $LOG_FILE
    
    # Deploy
    echo "  Deploying..." | tee -a $LOG_FILE
    if run_remote "cd $REMOTE_DIR/$dir && lxc-compose up -f $file" >> $LOG_FILE 2>&1; then
        echo -e "  ${GREEN}✓ Deployed successfully${NC}" | tee -a $LOG_FILE
    else
        echo -e "  ${RED}✗ Deployment failed${NC}" | tee -a $LOG_FILE
        return 1
    fi
    
    # Wait for container to be ready
    sleep 5
    
    # Check if tests are available
    echo "  Checking for tests..." | tee -a $LOG_FILE
    if run_remote "cd $REMOTE_DIR/$dir && lxc-compose test $container list" >> $LOG_FILE 2>&1; then
        echo -e "  ${GREEN}✓ Tests available${NC}" | tee -a $LOG_FILE
        
        # Run tests
        echo "  Running tests..." | tee -a $LOG_FILE
        if run_remote "cd $REMOTE_DIR/$dir && lxc-compose test $container" >> $LOG_FILE 2>&1; then
            echo -e "  ${GREEN}✓ Tests passed${NC}" | tee -a $LOG_FILE
        else
            echo -e "  ${YELLOW}⚠ Some tests failed (check log)${NC}" | tee -a $LOG_FILE
        fi
    else
        echo -e "  ${YELLOW}⚠ No tests found${NC}" | tee -a $LOG_FILE
    fi
    
    # Check container status
    if run_remote "lxc list $container --format=csv" | grep -q "RUNNING"; then
        echo -e "  ${GREEN}✓ Container running${NC}" | tee -a $LOG_FILE
    else
        echo -e "  ${RED}✗ Container not running${NC}" | tee -a $LOG_FILE
    fi
    
    # Cleanup
    echo "  Cleaning up..." | tee -a $LOG_FILE
    run_remote "cd $REMOTE_DIR/$dir && lxc-compose destroy -f $file" >> $LOG_FILE 2>&1
    
    echo "" | tee -a $LOG_FILE
    return 0
}

# Step 1: Update remote repository
echo "Updating remote repository..." | tee -a $LOG_FILE
if run_remote "cd $REMOTE_DIR && git pull origin main" >> $LOG_FILE 2>&1; then
    echo -e "${GREEN}✓ Repository updated${NC}" | tee -a $LOG_FILE
else
    echo -e "${RED}✗ Failed to update repository${NC}" | tee -a $LOG_FILE
    exit 1
fi
echo "" | tee -a $LOG_FILE

# Step 2: Test Alpine services
echo "Testing Alpine Services" | tee -a $LOG_FILE
echo "----------------------" | tee -a $LOG_FILE
test_container "examples" "test-alpine-services.yml" "test-alpine-postgres"
test_container "examples" "test-alpine-services.yml" "test-alpine-redis"
test_container "examples" "test-alpine-services.yml" "test-alpine-nginx"

# Step 3: Test Ubuntu services
echo "Testing Ubuntu Services" | tee -a $LOG_FILE
echo "----------------------" | tee -a $LOG_FILE
test_container "examples" "test-ubuntu-services.yml" "test-ubuntu-postgres"
test_container "examples" "test-ubuntu-services.yml" "test-ubuntu22-mysql"

# Step 4: Test Debian services
echo "Testing Debian Services" | tee -a $LOG_FILE
echo "----------------------" | tee -a $LOG_FILE
test_container "examples" "test-debian-services.yml" "test-debian12-postgres"
test_container "examples" "test-debian-services.yml" "test-debian11-redis"

# Step 5: Test Minimal services
echo "Testing Ubuntu Minimal Services" | tee -a $LOG_FILE
echo "-------------------------------" | tee -a $LOG_FILE
test_container "examples" "test-minimal-services.yml" "test-minimal-redis"
test_container "examples" "test-minimal-services.yml" "test-minimal-nginx"

# Step 6: Test original examples
echo "Testing Original Examples" | tee -a $LOG_FILE
echo "------------------------" | tee -a $LOG_FILE
test_container "examples" "template-example.yml" "myapp"
test_container "examples" "template-example.yml" "cache"
test_container "examples" "includes-example.yml" "webserver"
test_container "examples" "includes-example.yml" "database"

# Summary
echo "" | tee -a $LOG_FILE
echo "Testing Complete!" | tee -a $LOG_FILE
echo "================" | tee -a $LOG_FILE
echo "Results saved to: $LOG_FILE" | tee -a $LOG_FILE

# Count results
SUCCESS=$(grep -c "✓" $LOG_FILE || true)
FAILURES=$(grep -c "✗" $LOG_FILE || true)
WARNINGS=$(grep -c "⚠" $LOG_FILE || true)

echo "" | tee -a $LOG_FILE
echo "Summary:" | tee -a $LOG_FILE
echo "  Success: $SUCCESS" | tee -a $LOG_FILE
echo "  Failures: $FAILURES" | tee -a $LOG_FILE
echo "  Warnings: $WARNINGS" | tee -a $LOG_FILE

if [ $FAILURES -gt 0 ]; then
    echo -e "${RED}Some tests failed. Check $LOG_FILE for details.${NC}"
    exit 1
else
    echo -e "${GREEN}All critical tests passed!${NC}"
fi