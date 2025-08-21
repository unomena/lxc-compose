#!/bin/bash
# Test all services locally

set -e

RESULTS_FILE="test_results.md"
echo "# Service Test Results - $(date)" > $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Test function
test_service() {
    local distro=$1
    local version=$2
    local service=$3
    local path="library/$distro/$version/$service"
    
    if [ ! -d "$path" ]; then
        echo "❌ $distro/$version/$service - Not found" | tee -a $RESULTS_FILE
        return
    fi
    
    echo "Testing $distro/$version/$service..."
    cd "$path"
    
    # Check if config exists
    if [ ! -f "lxc-compose.yml" ]; then
        echo "❌ $distro/$version/$service - No config" | tee -a $RESULTS_FILE
        cd - > /dev/null
        return
    fi
    
    # Check if test exists
    if [ ! -f "tests/${service}.sh" ] && [ ! -f "tests/test.sh" ]; then
        echo "⚠️  $distro/$version/$service - No tests" | tee -a $RESULTS_FILE
        cd - > /dev/null
        return
    fi
    
    # Validate YAML syntax
    if python3 -c "import yaml; yaml.safe_load(open('lxc-compose.yml'))" 2>/dev/null; then
        echo "✅ $distro/$version/$service - Valid config" | tee -a $RESULTS_FILE
    else
        echo "❌ $distro/$version/$service - Invalid YAML" | tee -a $RESULTS_FILE
    fi
    
    cd - > /dev/null
}

# Test all combinations
for distro in alpine ubuntu ubuntu-minimal debian; do
    for version in 3.19 22.04 24.04 11 12; do
        # Skip invalid combinations
        if [[ "$distro" == "alpine" && "$version" != "3.19" ]]; then continue; fi
        if [[ "$distro" == "ubuntu" && "$version" != "22.04" && "$version" != "24.04" ]]; then continue; fi
        if [[ "$distro" == "ubuntu-minimal" && "$version" != "22.04" && "$version" != "24.04" ]]; then continue; fi
        if [[ "$distro" == "debian" && "$version" != "11" && "$version" != "12" ]]; then continue; fi
        
        echo "" | tee -a $RESULTS_FILE
        echo "## $distro/$version" | tee -a $RESULTS_FILE
        echo "" | tee -a $RESULTS_FILE
        
        for service in postgresql mysql mongodb redis nginx haproxy memcached rabbitmq elasticsearch grafana prometheus; do
            test_service "$distro" "$version" "$service"
        done
    done
done

echo ""
echo "Results saved to $RESULTS_FILE"

# Summary
echo ""
echo "## Summary"
total=$(grep -c "✅\|❌\|⚠️" $RESULTS_FILE)
valid=$(grep -c "✅" $RESULTS_FILE)
invalid=$(grep -c "❌" $RESULTS_FILE)
notests=$(grep -c "⚠️" $RESULTS_FILE)

echo "Total: $total services"
echo "Valid: $valid services"
echo "Invalid: $invalid services"
echo "No tests: $notests services"