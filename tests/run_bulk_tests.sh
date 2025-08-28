#!/bin/bash

# Master bulk test script for all services across all base templates
# Tests individual services and combined services for each base template

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}This script must be run with sudo${NC}"
    echo "Usage: sudo $0 [--individual|--combined|--all]"
    exit 1
fi

# Parse command line arguments
TEST_MODE="all"
if [ "$1" = "--individual" ]; then
    TEST_MODE="individual"
elif [ "$1" = "--combined" ]; then
    TEST_MODE="combined"
elif [ "$1" = "--all" ]; then
    TEST_MODE="all"
fi

# Results directories and files
RESULTS_DIR="/srv/lxc-compose/test-results-$(date +%Y%m%d-%H%M%S)"
SUMMARY_FILE="$RESULTS_DIR/summary.txt"
FAILED_FILE="$RESULTS_DIR/failed.txt"

# Create results directory
mkdir -p "$RESULTS_DIR"

# Initialize summary
echo "==================================" > "$SUMMARY_FILE"
echo "LXC Compose Bulk Test Results" >> "$SUMMARY_FILE"
echo "Test Mode: $TEST_MODE" >> "$SUMMARY_FILE"
echo "Date: $(date)" >> "$SUMMARY_FILE"
echo "==================================" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test
run_test() {
    local test_path=$1
    local test_name=$(basename $(dirname "$test_path"))
    local os_name=$(basename $(dirname $(dirname "$test_path")))
    local version=$(basename $(dirname $(dirname $(dirname "$test_path"))))
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}[$TOTAL_TESTS] Testing: ${CYAN}$version/$os_name/$test_name${NC}"
    
    # Create log file for this test
    LOG_FILE="$RESULTS_DIR/${version}_${os_name}_${test_name}.log"
    
    # Record start time
    echo "Test: $version/$os_name/$test_name" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    
    # Run the test
    {
        # Deploy the container
        echo "=== DEPLOYING ===" >> "$LOG_FILE"
        if lxc-compose up -f "$test_path" >> "$LOG_FILE" 2>&1; then
            echo "Deployment successful" >> "$LOG_FILE"
            
            # Wait for container to stabilize
            sleep 5
            
            # Extract container name from the config
            container_name=$(grep -A1 "^containers:" "$test_path" | tail -1 | sed 's/://g' | xargs)
            
            # Run tests
            echo "=== RUNNING TESTS ===" >> "$LOG_FILE"
            if lxc-compose test "$container_name" >> "$LOG_FILE" 2>&1; then
                echo -e "${GREEN}  ✓ Tests passed${NC}"
                echo "Tests PASSED" >> "$LOG_FILE"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                TEST_RESULT="PASSED"
            else
                echo -e "${RED}  ✗ Tests failed${NC}"
                echo "Tests FAILED" >> "$LOG_FILE"
                FAILED_TESTS=$((FAILED_TESTS + 1))
                TEST_RESULT="FAILED"
                echo "$version/$os_name/$test_name" >> "$FAILED_FILE"
            fi
            
            # Cleanup
            echo "=== CLEANUP ===" >> "$LOG_FILE"
            lxc-compose down -f "$test_path" >> "$LOG_FILE" 2>&1
            lxc-compose destroy -f "$test_path" >> "$LOG_FILE" 2>&1
        else
            echo -e "${RED}  ✗ Deployment failed${NC}"
            echo "Deployment FAILED" >> "$LOG_FILE"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            TEST_RESULT="FAILED"
            echo "$version/$os_name/$test_name (deployment)" >> "$FAILED_FILE"
        fi
    }
    
    # Record end time and result
    echo "----------------------------------------" >> "$LOG_FILE"
    echo "Finished: $(date)" >> "$LOG_FILE"
    echo "Result: $TEST_RESULT" >> "$LOG_FILE"
    
    # Add to summary
    echo "$version/$os_name/$test_name: $TEST_RESULT" >> "$SUMMARY_FILE"
}

# Function to test all services for a distribution
test_distribution() {
    local os_type=$1
    local version=$2
    
    echo ""
    echo -e "${YELLOW}=== Testing $os_type $version ===${NC}"
    echo ""
    echo "## $os_type $version" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"
    
    # Test individual services if requested
    if [ "$TEST_MODE" = "individual" ] || [ "$TEST_MODE" = "all" ]; then
        echo -e "${CYAN}Testing individual services...${NC}"
        for service in haproxy nginx postgresql python3 redis supervisor; do
            test_file="tests/$os_type/$version/$service/lxc-compose.yml"
            if [ -f "$test_file" ]; then
                run_test "$test_file"
            else
                echo -e "${YELLOW}  ⚠ Skipping $service (no test file)${NC}"
            fi
        done
    fi
    
    # Test combined services if requested
    if [ "$TEST_MODE" = "combined" ] || [ "$TEST_MODE" = "all" ]; then
        echo -e "${CYAN}Testing combined services...${NC}"
        test_file="tests/$os_type/$version/all-services/lxc-compose.yml"
        if [ -f "$test_file" ]; then
            run_test "$test_file"
        else
            echo -e "${YELLOW}  ⚠ Skipping all-services (no test file)${NC}"
        fi
    fi
    
    echo "" >> "$SUMMARY_FILE"
}

# Main test execution
echo -e "${BOLD}${BLUE}Starting LXC Compose Bulk Tests${NC}"
echo -e "${BLUE}Results will be saved to: $RESULTS_DIR${NC}"
echo ""

# Test all distributions
test_distribution "alpine" "3.19"
test_distribution "debian" "11"
test_distribution "debian" "12"
test_distribution "ubuntu-minimal" "22.04"
test_distribution "ubuntu-minimal" "24.04"
test_distribution "ubuntu" "22.04"
test_distribution "ubuntu" "24.04"

# Final summary
echo ""
echo -e "${YELLOW}==================================${NC}"
echo -e "${YELLOW}         TEST SUMMARY            ${NC}"
echo -e "${YELLOW}==================================${NC}"
echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC} $PASSED_TESTS"
echo -e "${RED}Failed:${NC} $FAILED_TESTS"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
else
    echo -e "${RED}✗ Some tests failed. Check $FAILED_FILE for details.${NC}"
fi

echo ""
echo -e "${BLUE}Full results saved to: $RESULTS_DIR${NC}"

# Add final summary to file
echo "" >> "$SUMMARY_FILE"
echo "==================================" >> "$SUMMARY_FILE"
echo "FINAL SUMMARY" >> "$SUMMARY_FILE"
echo "==================================" >> "$SUMMARY_FILE"
echo "Total Tests: $TOTAL_TESTS" >> "$SUMMARY_FILE"
echo "Passed: $PASSED_TESTS" >> "$SUMMARY_FILE"
echo "Failed: $FAILED_TESTS" >> "$SUMMARY_FILE"
echo "Success Rate: $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc)%" >> "$SUMMARY_FILE"

exit $FAILED_TESTS