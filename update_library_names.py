#!/usr/bin/env python3
"""
Update library service container names to be more specific
"""

import os
import yaml
from pathlib import Path

def update_container_names():
    """Update all library service container names to include template info"""
    
    library_path = Path("library")
    updated = 0
    
    for distro_dir in library_path.iterdir():
        if not distro_dir.is_dir():
            continue
            
        distro = distro_dir.name
        
        for version_dir in distro_dir.iterdir():
            if not version_dir.is_dir():
                continue
                
            version = version_dir.name
            
            for service_dir in version_dir.iterdir():
                if not service_dir.is_dir():
                    continue
                    
                service = service_dir.name
                config_file = service_dir / "lxc-compose.yml"
                
                if not config_file.exists():
                    continue
                
                # Read config
                with open(config_file, 'r') as f:
                    config = yaml.safe_load(f)
                
                if 'containers' not in config:
                    continue
                
                # Update container names
                new_containers = {}
                changed = False
                
                for name, container in config['containers'].items():
                    # Create new name format: service-distro-version
                    # Simplify the name
                    if distro == 'ubuntu-minimal':
                        distro_short = 'minimal'
                    else:
                        distro_short = distro
                    
                    # Use dots for version in name
                    version_clean = version.replace('.', '-')
                    
                    new_name = f"{service}-{distro_short}-{version_clean}"
                    
                    # Update container
                    if name != new_name:
                        print(f"  {distro}/{version}/{service}: {name} → {new_name}")
                        container['name'] = new_name
                        new_containers[new_name] = container
                        changed = True
                        
                        # Also update test files if they reference the old name
                        tests_dir = service_dir / "tests"
                        if tests_dir.exists():
                            for test_file in tests_dir.glob("*.sh"):
                                with open(test_file, 'r') as f:
                                    test_content = f.read()
                                
                                # Update container name references in test
                                if name in test_content:
                                    test_content = test_content.replace(f'"{name}"', f'"{new_name}"')
                                    test_content = test_content.replace(f' {name} ', f' {new_name} ')
                                    test_content = test_content.replace(f'${name}', f'${new_name}')
                                    
                                    with open(test_file, 'w') as f:
                                        f.write(test_content)
                                    print(f"    Updated test: {test_file.name}")
                    else:
                        new_containers[name] = container
                
                if changed:
                    config['containers'] = new_containers
                    
                    # Write back
                    with open(config_file, 'w') as f:
                        yaml.dump(config, f, default_flow_style=False, sort_keys=False)
                    
                    updated += 1
    
    print(f"\nUpdated {updated} configuration files")
    return updated

def main():
    print("Updating library service container names...")
    print("=" * 50)
    
    count = update_container_names()
    
    if count > 0:
        print("\n✅ Container names updated successfully!")
        print("\nNow containers will have unique names like:")
        print("  - postgresql-alpine-3-19")
        print("  - postgresql-ubuntu-24-04")
        print("  - redis-debian-12")
        print("\nThis prevents naming conflicts when using includes.")
    else:
        print("\nNo updates needed - names already specific.")

if __name__ == "__main__":
    main()