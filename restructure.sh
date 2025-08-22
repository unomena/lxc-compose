#!/bin/bash
# Restructure library to have templates and services subdirectories

set -e

echo "Restructuring lxc-compose library..."

# Create new structure
mkdir -p library/templates
mkdir -p library/services

# Move templates into library/templates
if [ -d "templates" ]; then
    echo "Moving templates to library/templates..."
    mv templates/*.yml library/templates/ 2>/dev/null || true
    mv templates/README.md library/templates/ 2>/dev/null || true
    rmdir templates 2>/dev/null || true
fi

# Move existing library services to library/services
echo "Moving services to library/services..."
for os_dir in library/*/; do
    # Skip the new templates and services directories
    if [[ "$os_dir" == "library/templates/" ]] || [[ "$os_dir" == "library/services/" ]]; then
        continue
    fi
    
    # Get OS name (alpine, ubuntu, etc.)
    os_name=$(basename "$os_dir")
    
    # Move each version's services
    for version_dir in "$os_dir"*/; do
        version=$(basename "$version_dir")
        
        # Create target directory
        mkdir -p "library/services/${os_name}/${version}"
        
        # Move all service directories
        for service_dir in "$version_dir"*/; do
            if [ -d "$service_dir" ]; then
                service=$(basename "$service_dir")
                echo "  Moving ${os_name}/${version}/${service}"
                mv "$service_dir" "library/services/${os_name}/${version}/"
            fi
        done
        
        # Remove empty version directory
        rmdir "$version_dir" 2>/dev/null || true
    done
    
    # Remove empty OS directory
    rmdir "$os_dir" 2>/dev/null || true
done

echo "Restructure complete!"
echo ""
echo "New structure:"
echo "  library/"
echo "    templates/     - Base OS templates"
echo "    services/      - Pre-configured services"
echo "      alpine/3.19/ - Alpine services"
echo "      ubuntu/24.04/ - Ubuntu services"
echo "      ..."