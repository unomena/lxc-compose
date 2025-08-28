#!/bin/bash

# Parallel bulk test script for all services
# Runs multiple tests simultaneously for faster execution

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
    echo "Usage: sudo $0 [max_parallel_tests]"
    exit 1
fi

# Maximum parallel tests (default: 3)
MAX_PARALLEL=${1:-3}

# Results directory
RESULTS_DIR="/srv/lxc-compose/parallel-test-results-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Create a list of all test configurations
echo -e "${BLUE}Discovering test configurations...${NC}"
TEST_CONFIGS=()

for os_type in alpine debian ubuntu-minimal ubuntu; do
    for version_dir in tests/$os_type/*/; do
        if [ -d "$version_dir" ]; then
            version=$(basename "$version_dir")
            
            # Add individual service tests
            for service in haproxy nginx postgresql python3 redis supervisor; do
                test_file="tests/$os_type/$version/$service/lxc-compose.yml"
                if [ -f "$test_file" ]; then
                    TEST_CONFIGS+=("$test_file")
                fi
            done
            
            # Add combined test
            test_file="tests/$os_type/$version/all-services/lxc-compose.yml"
            if [ -f "$test_file" ]; then
                TEST_CONFIGS+=("$test_file")
            fi
        fi
    done
done

TOTAL_TESTS=${#TEST_CONFIGS[@]}
echo -e "${BLUE}Found $TOTAL_TESTS test configurations${NC}"
echo ""

# Function to run a single test
run_single_test() {
    local test_path=$1
    local test_num=$2
    local test_name=$(basename $(dirname "$test_path"))
    local os_name=$(basename $(dirname $(dirname "$test_path")))
    local version=$(basename $(dirname $(dirname $(dirname "$test_path"))))
    
    echo -e "${CYAN}[$test_num/$TOTAL_TESTS] Starting: $version/$os_name/$test_name${NC}"
    
    # Create log file
    LOG_FILE="$RESULTS_DIR/${version}_${os_name}_${test_name}.log"
    
    # Run the test
    {
        echo "Test: $version/$os_name/$test_name" > "$LOG_FILE"
        echo "Started: $(date)" >> "$LOG_FILE"
        echo "----------------------------------------" >> "$LOG_FILE"
        
        # Deploy
        if lxc-compose up -f "$test_path" >> "$LOG_FILE" 2>&1; then
            sleep 5
            
            # Get container name
            container_name=$(grep -A1 "^containers:" "$test_path" | tail -1 | sed 's/://g' | xargs)
            
            # Run tests
            if lxc-compose test "$container_name" >> "$LOG_FILE" 2>&1; then
                echo -e "${GREEN}[$test_num/$TOTAL_TESTS] ✓ PASSED: $version/$os_name/$test_name${NC}"
                echo "PASSED" >> "$LOG_FILE"
            else
                echo -e "${RED}[$test_num/$TOTAL_TESTS] ✗ FAILED: $version/$os_name/$test_name${NC}"
                echo "FAILED" >> "$LOG_FILE"
            fi
            
            # Cleanup
            lxc-compose down -f "$test_path" >> "$LOG_FILE" 2>&1
            lxc-compose destroy -f "$test_path" >> "$LOG_FILE" 2>&1
        else
            echo -e "${RED}[$test_num/$TOTAL_TESTS] ✗ DEPLOY FAILED: $version/$os_name/$test_name${NC}"
            echo "DEPLOY FAILED" >> "$LOG_FILE"
        fi
        
        echo "----------------------------------------" >> "$LOG_FILE"
        echo "Finished: $(date)" >> "$LOG_FILE"
    } &
}

# Run tests in parallel
echo -e "${YELLOW}Running tests with max $MAX_PARALLEL parallel jobs${NC}"
echo ""

test_num=0
for test_config in "${TEST_CONFIGS[@]}"; do
    test_num=$((test_num + 1))
    
    # Wait if we've reached max parallel jobs
    while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
        sleep 1
    done
    
    run_single_test "$test_config" "$test_num"
done

# Wait for all remaining jobs to complete
echo ""
echo -e "${YELLOW}Waiting for all tests to complete...${NC}"
wait

# Generate summary
echo ""
echo -e "${YELLOW}==================================${NC}"
echo -e "${YELLOW}         TEST SUMMARY            ${NC}"
echo -e "${YELLOW}==================================${NC}"

PASSED=$(grep -l "^PASSED$" $RESULTS_DIR/*.log 2>/dev/null | wc -l)
FAILED=$(grep -l "^FAILED$" $RESULTS_DIR/*.log 2>/dev/null | wc -l)
DEPLOY_FAILED=$(grep -l "^DEPLOY FAILED$" $RESULTS_DIR/*.log 2>/dev/null | wc -l)

echo -e "${BLUE}Total Tests:${NC} $TOTAL_TESTS"
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo -e "${RED}Deploy Failed:${NC} $DEPLOY_FAILED"

if [ $FAILED -eq 0 ] && [ $DEPLOY_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
else
    echo -e "${RED}✗ Some tests failed.${NC}"
    echo ""
    echo "Failed tests:"
    grep -l "^FAILED$\|^DEPLOY FAILED$" $RESULTS_DIR/*.log 2>/dev/null | while read log; do
        basename "$log" .log | sed 's/_/\//g'
    done
fi

echo ""
echo -e "${BLUE}Full results saved to: $RESULTS_DIR${NC}"

# Create summary file
SUMMARY_FILE="$RESULTS_DIR/summary.txt"
{
    echo "LXC Compose Parallel Test Results"
    echo "Date: $(date)"
    echo "Max Parallel: $MAX_PARALLEL"
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED"
    echo "Failed: $FAILED"
    echo "Deploy Failed: $DEPLOY_FAILED"
    echo ""
    echo "Test Results:"
    for log in $RESULTS_DIR/*.log; do
        test_name=$(basename "$log" .log | sed 's/_/\//g')
        if grep -q "^PASSED$" "$log"; then
            echo "  ✓ $test_name"
        elif grep -q "^FAILED$" "$log"; then
            echo "  ✗ $test_name (test failed)"
        elif grep -q "^DEPLOY FAILED$" "$log"; then
            echo "  ✗ $test_name (deploy failed)"
        fi
    done
} > "$SUMMARY_FILE"

exit $((FAILED + DEPLOY_FAILED))