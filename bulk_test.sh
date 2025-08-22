#!/bin/bash
# Bulk test script for all LXC Compose library services
# Tests all 77 services across 7 base images

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Results directories and files
RESULTS_DIR="/srv/lxc-compose/test-results"
CONTROL_FILE="/srv/lxc-compose/test-control.txt"
SUMMARY_FILE="/srv/lxc-compose/test-summary.txt"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
NO_TEST_TESTS=0

# Make sure we have the latest code installed
echo -e "${BLUE}Installing latest LXC Compose from GitHub...${NC}"
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash

# Create results directory structure
mkdir -p "$RESULTS_DIR"

# Initialize control file with header
{
    echo "==================================================================="
    echo "LXC COMPOSE LIBRARY SERVICE TEST CONTROL FILE"
    echo "==================================================================="
    echo "Started: $(date)"
    echo "==================================================================="
    echo ""
    echo "FORMAT: [STATUS] OS/VERSION/SERVICE - REASON"
    echo ""
    echo "STATUSES:"
    echo "  [PASS]    - Service deployed and tests passed"
    echo "  [FAIL]    - Service deployed but tests failed"
    echo "  [NO_TEST] - Service deployed but no tests defined"
    echo "  [NO_DEPLOY] - Service failed to deploy"
    echo "  [SKIP]    - Service skipped (missing files)"
    echo ""
    echo "==================================================================="
    echo "TEST RESULTS:"
    echo "-------------------------------------------------------------------"
} > "$CONTROL_FILE"

# Function to check if service has tests defined
check_has_tests() {
    local service_path=$1
    local yml_file="$service_path/lxc-compose.yml"
    
    if [ ! -f "$yml_file" ]; then
        return 1
    fi
    
    # Check if tests section exists in the YAML file
    if grep -q "tests:" "$yml_file" 2>/dev/null; then
        # Check if there are actual test entries (not just empty tests section)
        if grep -A 5 "tests:" "$yml_file" | grep -qE "(internal:|external:|port_forwarding:)" 2>/dev/null; then
            return 0  # Has tests
        fi
    fi
    
    return 1  # No tests
}

# Function to test a single service
test_service() {
    local base_image_dir=$1
    local service=$2
    local service_path="$base_image_dir/$service"
    
    # Extract base image info for display
    local os_name=$(echo $base_image_dir | cut -d'/' -f5)
    local os_version=$(echo $base_image_dir | cut -d'/' -f6)
    local service_id="${os_name}/${os_version}/${service}"
    
    # Create individual result file path
    local result_file="${RESULTS_DIR}/${os_name}-${os_version}-${service}.log"
    
    echo -e "\n${BLUE}Testing: $service_id${NC}"
    
    # Initialize individual result file
    {
        echo "==================================================================="
        echo "Service: $service_id"
        echo "Path: $service_path"
        echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "==================================================================="
        echo ""
    } > "$result_file"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Check if service directory exists
    if [ ! -d "$service_path" ]; then
        echo -e "${YELLOW}⚠ Skipping: Directory not found${NC}"
        echo "[SKIP] $service_id - Directory not found" >> "$CONTROL_FILE"
        echo "Status: SKIPPED - Directory not found" >> "$result_file"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        return
    fi
    
    # Check if lxc-compose.yml exists
    if [ ! -f "$service_path/lxc-compose.yml" ]; then
        echo -e "${YELLOW}⚠ Skipping: No lxc-compose.yml found${NC}"
        echo "[SKIP] $service_id - No lxc-compose.yml" >> "$CONTROL_FILE"
        echo "Status: SKIPPED - No lxc-compose.yml found" >> "$result_file"
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
        return
    fi
    
    # Check if service has tests defined
    local has_tests=false
    if check_has_tests "$service_path"; then
        has_tests=true
        echo -e "  ${CYAN}ℹ Tests defined: YES${NC}"
        echo "Tests Defined: YES" >> "$result_file"
    else
        echo -e "  ${YELLOW}⚠ Tests defined: NO${NC}"
        echo "Tests Defined: NO" >> "$result_file"
    fi
    
    # Navigate to service directory
    cd "$service_path" || {
        echo -e "${RED}✗ Failed to change directory${NC}"
        echo "[SKIP] $service_id - Could not cd to directory" >> "$CONTROL_FILE"
        echo "Status: FAILED - Could not cd to directory" >> "$result_file"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return
    }
    
    # Test the service with error handling
    {
        # Deploy the service
        echo "  Deploying..."
        echo "" >> "$result_file"
        echo "=== DEPLOYMENT ===" >> "$result_file"
        
        if lxc-compose up >> "$result_file" 2>&1; then
            echo -e "  ${GREEN}✓ Deployed successfully${NC}"
            echo "Deployment: SUCCESS" >> "$result_file"
            
            # Wait for service to stabilize
            sleep 5
            
            if [ "$has_tests" = true ]; then
                # Run tests if they exist
                echo "  Running tests..."
                echo "" >> "$result_file"
                echo "=== TESTS ===" >> "$result_file"
                
                if lxc-compose test >> "$result_file" 2>&1; then
                    echo -e "  ${GREEN}✓ Tests passed${NC}"
                    echo "[PASS] $service_id" >> "$CONTROL_FILE"
                    echo "" >> "$result_file"
                    echo "FINAL STATUS: PASSED" >> "$result_file"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                else
                    echo -e "  ${RED}✗ Tests failed${NC}"
                    echo "[FAIL] $service_id - Tests did not pass" >> "$CONTROL_FILE"
                    echo "" >> "$result_file"
                    echo "FINAL STATUS: FAILED - Tests did not pass" >> "$result_file"
                    FAILED_TESTS=$((FAILED_TESTS + 1))
                fi
            else
                # No tests defined but deployment succeeded
                echo -e "  ${YELLOW}⚠ No tests to run${NC}"
                echo "[NO_TEST] $service_id - No tests defined" >> "$CONTROL_FILE"
                echo "" >> "$result_file"
                echo "FINAL STATUS: NO_TEST - Service deployed but no tests defined" >> "$result_file"
                NO_TEST_TESTS=$((NO_TEST_TESTS + 1))
            fi
            
            # Clean up
            echo "  Cleaning up..."
            echo "" >> "$result_file"
            echo "=== CLEANUP ===" >> "$result_file"
            lxc-compose down >> "$result_file" 2>&1
            lxc-compose destroy --yes >> "$result_file" 2>&1  # Auto-confirm destruction
            
        else
            echo -e "  ${RED}✗ Deployment failed${NC}"
            echo "[NO_DEPLOY] $service_id - Could not deploy" >> "$CONTROL_FILE"
            echo "" >> "$result_file"
            echo "FINAL STATUS: NO_DEPLOY - Could not deploy service" >> "$result_file"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            
            # Try to clean up even if deployment failed
            echo "" >> "$result_file"
            echo "=== CLEANUP (after failure) ===" >> "$result_file"
            lxc-compose down >> "$result_file" 2>&1 || true
            lxc-compose destroy --yes >> "$result_file" 2>&1 || true
        fi
        
    } || {
        # Catch any unexpected errors
        echo -e "  ${RED}✗ Unexpected error occurred${NC}"
        echo "[FAIL] $service_id - Unexpected error" >> "$CONTROL_FILE"
        echo "" >> "$result_file"
        echo "FINAL STATUS: FAILED - Unexpected error: $?" >> "$result_file"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    }
    
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
    
    # Add section to control file
    echo "" >> "$CONTROL_FILE"
    echo "--- $os_name/$os_version ---" >> "$CONTROL_FILE"
    
    # Check if directory exists
    if [ ! -d "$base_image_dir" ]; then
        echo -e "${YELLOW}Base image directory not found: $base_image_dir${NC}"
        echo "[SKIP] $os_name/$os_version/* - Base image directory not found" >> "$CONTROL_FILE"
        return
    fi
    
    # Get list of services
    local services=$(ls -d $base_image_dir/*/ 2>/dev/null | xargs -n1 basename)
    
    if [ -z "$services" ]; then
        echo -e "${YELLOW}No services found in $base_image_dir${NC}"
        echo "[SKIP] $os_name/$os_version/* - No services found" >> "$CONTROL_FILE"
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
echo "Control file: $CONTROL_FILE"
echo "Individual results: $RESULTS_DIR/"
echo "Summary: $SUMMARY_FILE"
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

# Complete control file
{
    echo ""
    echo "==================================================================="
    echo "Completed: $(date)"
    echo "==================================================================="
} >> "$CONTROL_FILE"

# Generate summary
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                Test Summary                  ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}"
echo ""

{
    echo "==================================================================="
    echo "LXC COMPOSE LIBRARY SERVICE TEST SUMMARY"
    echo "==================================================================="
    echo "Date: $(date)"
    echo ""
    echo "Total Services Tested: $TOTAL_TESTS"
    echo ""
    echo "Results Breakdown:"
    echo "  Passed (tests ran and passed):     $PASSED_TESTS"
    echo "  Failed (tests ran but failed):     $FAILED_TESTS"
    echo "  No Tests (deployed but no tests):  $NO_TEST_TESTS"
    echo "  Skipped (missing files):           $SKIPPED_TESTS"
    echo ""
    
    # Calculate percentages
    if [ $TOTAL_TESTS -gt 0 ]; then
        echo "Percentages:"
        echo "  Pass Rate (of tested): $(echo "scale=2; $PASSED_TESTS * 100 / ($PASSED_TESTS + $FAILED_TESTS)" | bc 2>/dev/null || echo "N/A")%"
        echo "  Coverage (have tests): $(echo "scale=2; ($PASSED_TESTS + $FAILED_TESTS) * 100 / $TOTAL_TESTS" | bc 2>/dev/null || echo "N/A")%"
        echo "  Success Rate (overall): $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc 2>/dev/null || echo "N/A")%"
    fi
    
    echo ""
    echo "Files Generated:"
    echo "  Control File: $CONTROL_FILE"
    echo "  Individual Results: $RESULTS_DIR/*.log"
    echo "  This Summary: $SUMMARY_FILE"
    echo ""
    echo "==================================================================="
    
    # List problematic services for quick reference
    if [ $FAILED_TESTS -gt 0 ] || [ $NO_TEST_TESTS -gt 0 ]; then
        echo ""
        echo "SERVICES REQUIRING ATTENTION:"
        echo "-------------------------------------------------------------------"
        
        if [ $FAILED_TESTS -gt 0 ]; then
            echo ""
            echo "Failed Tests:"
            grep "^\[FAIL\]\|^\[NO_DEPLOY\]" "$CONTROL_FILE" | sed 's/^/  /'
        fi
        
        if [ $NO_TEST_TESTS -gt 0 ]; then
            echo ""
            echo "Missing Tests:"
            grep "^\[NO_TEST\]" "$CONTROL_FILE" | sed 's/^/  /'
        fi
        
        echo "-------------------------------------------------------------------"
    fi
} | tee "$SUMMARY_FILE"

# Display results with colors
echo ""
if [ $PASSED_TESTS -gt 0 ]; then
    echo -e "${GREEN}✓ $PASSED_TESTS services passed tests${NC}"
fi
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "${RED}✗ $FAILED_TESTS services failed${NC}"
fi
if [ $NO_TEST_TESTS -gt 0 ]; then
    echo -e "${YELLOW}⚠ $NO_TEST_TESTS services have no tests${NC}"
fi
if [ $SKIPPED_TESTS -gt 0 ]; then
    echo -e "${CYAN}○ $SKIPPED_TESTS services skipped${NC}"
fi

echo ""
echo "To investigate failures, check:"
echo "  1. Control file: $CONTROL_FILE"
echo "  2. Individual logs in: $RESULTS_DIR/"
echo ""
echo "Example: To check a failed service:"
echo "  grep FAIL $CONTROL_FILE"
echo "  less $RESULTS_DIR/alpine-3.19-postgresql.log"

# Exit with appropriate code
if [ $FAILED_TESTS -gt 0 ]; then
    exit 1
else
    exit 0
fi