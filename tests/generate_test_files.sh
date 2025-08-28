#!/bin/bash

# Generate test files for all distributions and services

# Function to create individual service test file
create_service_test() {
    local os_type=$1
    local version=$2
    local service=$3
    local template=$4
    local container_name=$5
    local dir="$os_type/$version/$service"
    
    # Set exposed ports based on service
    local ports=""
    case $service in
        haproxy) ports="80, 443, 8404" ;;
        nginx) ports="80, 443" ;;
        postgresql) ports="5432" ;;
        redis) ports="6379" ;;
        *) ports="" ;;
    esac
    
    # Create the test file
    cat > "$dir/lxc-compose.yml" << EOF
version: '1.0'
containers:
  ${container_name}:
    template: $template
    includes:
      - $service
EOF

    # Add exposed ports if needed
    if [ -n "$ports" ]; then
        echo "    exposed_ports: [$ports]" >> "$dir/lxc-compose.yml"
    fi
    
    # Add tests section
    cat >> "$dir/lxc-compose.yml" << EOF
    tests:
      internal:
        - ${service}-check:library/services/$os_type/$version/$service/tests/${service}.sh
EOF
    
    # Some services have additional test files
    if [ -f "library/services/$os_type/$version/$service/tests/test.sh" ]; then
        sed -i "s|${service}.sh|test.sh|" "$dir/lxc-compose.yml" 2>/dev/null || \
        sed -i '' "s|${service}.sh|test.sh|" "$dir/lxc-compose.yml" 2>/dev/null
    fi
}

# Function to create combined services test file
create_all_services_test() {
    local os_type=$1
    local version=$2
    local template=$3
    local container_name=$4
    local dir="$os_type/$version/all-services"
    
    cat > "$dir/lxc-compose.yml" << EOF
version: '1.0'
containers:
  ${container_name}:
    template: $template
    includes:
      - haproxy
      - nginx
      - postgresql
      - python3
      - redis
      - supervisor
    exposed_ports: [80, 443, 5432, 6379, 8080, 8404]
    post_install:
      - echo "All $template services installed"
    tests:
      internal:
EOF

    # Add test entries for each service
    for service in haproxy nginx postgresql python3 redis supervisor; do
        if [ -f "library/services/$os_type/$version/$service/tests/test.sh" ]; then
            echo "        - ${service}-check:library/services/$os_type/$version/$service/tests/test.sh" >> "$dir/lxc-compose.yml"
        elif [ -f "library/services/$os_type/$version/$service/tests/${service}.sh" ]; then
            echo "        - ${service}-check:library/services/$os_type/$version/$service/tests/${service}.sh" >> "$dir/lxc-compose.yml"
        fi
    done
}

# Debian 12
echo "Creating Debian 12 test files..."
for service in haproxy nginx postgresql python3 redis supervisor; do
    create_service_test "debian" "12" "$service" "debian-12" "${service}-debian12-test"
done
create_all_services_test "debian" "12" "debian-12" "all-services-debian12-test"

# Ubuntu Minimal 22.04
echo "Creating Ubuntu Minimal 22.04 test files..."
for service in haproxy nginx postgresql python3 redis supervisor; do
    create_service_test "ubuntu-minimal" "22.04" "$service" "ubuntu-minimal-22.04" "${service}-uminimal2204-test"
done
create_all_services_test "ubuntu-minimal" "22.04" "ubuntu-minimal-22.04" "all-services-uminimal2204-test"

# Ubuntu Minimal 24.04
echo "Creating Ubuntu Minimal 24.04 test files..."
for service in haproxy nginx postgresql python3 redis supervisor; do
    create_service_test "ubuntu-minimal" "24.04" "$service" "ubuntu-minimal-24.04" "${service}-uminimal2404-test"
done
create_all_services_test "ubuntu-minimal" "24.04" "ubuntu-minimal-24.04" "all-services-uminimal2404-test"

# Ubuntu 22.04
echo "Creating Ubuntu 22.04 test files..."
for service in haproxy nginx postgresql python3 redis supervisor; do
    create_service_test "ubuntu" "22.04" "$service" "ubuntu-22.04" "${service}-ubuntu2204-test"
done
create_all_services_test "ubuntu" "22.04" "ubuntu-22.04" "all-services-ubuntu2204-test"

# Ubuntu 24.04
echo "Creating Ubuntu 24.04 test files..."
for service in haproxy nginx postgresql python3 redis supervisor; do
    create_service_test "ubuntu" "24.04" "$service" "ubuntu-24.04" "${service}-ubuntu2404-test"
done
create_all_services_test "ubuntu" "24.04" "ubuntu-24.04" "all-services-ubuntu2404-test"

echo "Test files generated successfully!"