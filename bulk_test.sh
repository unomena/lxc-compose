#!/bin/bash
# Bulk test script for all LXC Compose library services
# Tests all 77 services across 7 base images

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Results file
RESULTS_FILE="/srv/lxc-compose/service_test_results.txt"
SUMMARY_FILE="/srv/lxc-compose/test_summary.txt"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Make sure we have the latest code installed
echo -e "${BLUE}Installing latest LXC Compose from GitHub...${NC}"
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash

# Initialize results files
echo "=== LXC Compose Library Service Test Results ===" > $RESULTS_FILE
echo "Test started at: $(date)" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Function to test a single service
test_service() {
    local base_image_dir=$1
    local service=$2
    local service_path="$base_image_dir/$service"
    
    # Extract base image info for display
    local os_name=$(echo $base_image_dir | cut -d'/' -f5)
    local os_version=$(echo $base_image_dir | cut -d'/' -f6)
    
    echo -e "\n${BLUE}Testing: $os_name/$os_version/$service${NC}"
    echo "----------------------------------------" >> $RESULTS_FILE
    echo "Service: $os_name/$os_version/$service" >> $RESULTS_FILE
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')" >> $RESULTS_FILE
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Check if service directory exists
    if [ ! -d "$service_path" ]; then
        echo -e "${YELLOW}⚠ Skipping: Directory not found${NC}"
        echo "Status: SKIPPED - Directory not found" >> $RESULTS_FILE
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        return
    fi
    
    # Check if lxc-compose.yml exists
    if [ ! -f "$service_path/lxc-compose.yml" ]; then
        echo -e "${YELLOW}⚠ Skipping: No lxc-compose.yml found${NC}"
        echo "Status: SKIPPED - No lxc-compose.yml" >> $RESULTS_FILE
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        return
    fi
    
    # Navigate to service directory
    cd "$service_path" || {
        echo -e "${RED}✗ Failed to change directory${NC}"
        echo "Status: FAILED - Could not cd to directory" >> $RESULTS_FILE
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return
    }
    
    # Test the service with error handling
    {
        # Deploy the service
        echo "  Deploying..."
        if lxc-compose up >> $RESULTS_FILE 2>&1; then
            echo -e "  ${GREEN}✓ Deployed successfully${NC}"
            
            # Wait for service to stabilize
            sleep 5
            
            # Run tests
            echo "  Running tests..."
            if lxc-compose test >> $RESULTS_FILE 2>&1; then
                echo -e "  ${GREEN}✓ Tests passed${NC}"
                echo "Status: PASSED" >> $RESULTS_FILE
                PASSED_TESTS=$((PASSED_TESTS + 1))
            else
                echo -e "  ${RED}✗ Tests failed${NC}"
                echo "Status: FAILED - Tests did not pass" >> $RESULTS_FILE
                FAILED_TESTS=$((FAILED_TESTS + 1))
            fi
            
            # Clean up
            echo "  Cleaning up..."
            lxc-compose down >> $RESULTS_FILE 2>&1
            lxc-compose destroy --yes >> $RESULTS_FILE 2>&1  # Auto-confirm destruction
            
        else
            echo -e "  ${RED}✗ Deployment failed${NC}"
            echo "Status: FAILED - Could not deploy" >> $RESULTS_FILE
            FAILED_TESTS=$((FAILED_TESTS + 1))
            
            # Try to clean up even if deployment failed
            lxc-compose down >> $RESULTS_FILE 2>&1 || true
            lxc-compose destroy --yes >> $RESULTS_FILE 2>&1 || true
        fi
        
    } || {
        # Catch any unexpected errors
        echo -e "  ${RED}✗ Unexpected error occurred${NC}"
        echo "Status: FAILED - Unexpected error: $?" >> $RESULTS_FILE
        FAILED_TESTS=$((FAILED_TESTS + 1))
    }
    
    echo "" >> $RESULTS_FILE
    
    # Return to base directory
    cd - > /dev/null
}

# Function to test all services in a base image directory
test_base_image() {
    local base_image_dir=$1
    local os_name=$(echo $base_image_dir | cut -d'/' -f5)
    local os_version=$(echo $base_image_dir | cut -d'/' -f6)
    
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}Testing Base Image: $os_name/$os_version${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    
    # Check if directory exists
    if [ ! -d "$base_image_dir" ]; then
        echo -e "${YELLOW}Base image directory not found: $base_image_dir${NC}"
        return
    fi
    
    # Get list of services
    local services=$(ls -d $base_image_dir/*/ 2>/dev/null | xargs -n1 basename)
    
    if [ -z "$services" ]; then
        echo -e "${YELLOW}No services found in $base_image_dir${NC}"
        return
    fi
    
    # Test each service
    for service in $services; do
        test_service "$base_image_dir" "$service"
    done
}

# Main execution
echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   LXC Compose Library Service Bulk Testing   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo "Results will be saved to: $RESULTS_FILE"
echo "Summary will be saved to: $SUMMARY_FILE"
echo ""

# Test all base images
BASE_IMAGES=(
    "/srv/lxc-compose/library/alpine/3.19"
    "/srv/lxc-compose/library/debian/11"
    "/srv/lxc-compose/library/debian/12"
    "/srv/lxc-compose/library/ubuntu/22.04"
    "/srv/lxc-compose/library/ubuntu/24.04"
    "/srv/lxc-compose/library/ubuntu-minimal/22.04"
    "/srv/lxc-compose/library/ubuntu-minimal/24.04"
)

# Run tests for each base image
for base_image in "${BASE_IMAGES[@]}"; do
    test_base_image "$base_image"
done

# Generate summary
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                Test Summary                  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

{
    echo "=== Test Summary ==="
    echo "Date: $(date)"
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Skipped: $SKIPPED_TESTS"
    echo ""
    echo "Success Rate: $([ $TOTAL_TESTS -gt 0 ] && echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc || echo 0)%"
} | tee $SUMMARY_FILE

# Display results
if [ $PASSED_TESTS -gt 0 ]; then
    echo -e "${GREEN}✓ $PASSED_TESTS tests passed${NC}"
fi
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}✗ $FAILED_TESTS tests failed${NC}"
fi
if [ $SKIPPED_TESTS -gt 0 ]; then
    echo -e "${YELLOW}⚠ $SKIPPED_TESTS tests skipped${NC}"
fi

echo ""
echo "Detailed results saved to: $RESULTS_FILE"
echo "Summary saved to: $SUMMARY_FILE"

# Exit with appropriate code
if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
else
    exit 0
fi