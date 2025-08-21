#!/bin/bash
# Update library container names to be more specific

echo "Updating container names in library services..."
echo "=============================================="

# Function to update a service
update_service() {
    local path=$1
    local service=$2
    local distro=$3
    local version=$4
    
    # Simplify distro name
    local distro_short=$distro
    if [[ "$distro" == "ubuntu-minimal" ]]; then
        distro_short="minimal"
    fi
    
    # Clean version (replace . with -)
    local version_clean=${version//./-}
    
    # New container name
    local new_name="${service}-${distro_short}-${version_clean}"
    
    # Update the lxc-compose.yml file
    local config_file="${path}/lxc-compose.yml"
    if [[ -f "$config_file" ]]; then
        # Update container name in the containers section
        # This is a simple approach - just replace the service name with the new name
        if grep -q "^  ${service}:" "$config_file"; then
            echo "  Updating $distro/$version/$service → $new_name"
            sed -i.bak "s/^  ${service}:/  ${new_name}:/" "$config_file"
            
            # Also update any test files
            if [[ -d "${path}/tests" ]]; then
                for test_file in ${path}/tests/*.sh; do
                    if [[ -f "$test_file" ]]; then
                        # Update references to the container name in tests
                        sed -i.bak "s/${service}/${new_name}/g" "$test_file"
                    fi
                done
            fi
        fi
    fi
}

# Process all library services
for distro_path in library/*; do
    if [[ -d "$distro_path" ]]; then
        distro=$(basename "$distro_path")
        
        for version_path in $distro_path/*; do
            if [[ -d "$version_path" ]]; then
                version=$(basename "$version_path")
                
                for service_path in $version_path/*; do
                    if [[ -d "$service_path" ]]; then
                        service=$(basename "$service_path")
                        update_service "$service_path" "$service" "$distro" "$version"
                    fi
                done
            fi
        done
    fi
done

# Clean up backup files
find library -name "*.bak" -delete

echo ""
echo "✅ Container names updated!"
echo ""
echo "Examples of new names:"
echo "  postgresql-alpine-3-19"
echo "  nginx-ubuntu-24-04"
echo "  redis-minimal-22-04"
echo ""
echo "This prevents conflicts when using includes from different templates."