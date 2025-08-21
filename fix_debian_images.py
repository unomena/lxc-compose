#!/usr/bin/env python3
"""
Fix Debian image references to use images: prefix
"""

from pathlib import Path
import re

def fix_debian_images():
    """Fix all Debian image references"""
    library_path = Path("library/debian")
    
    for version_dir in library_path.iterdir():
        if not version_dir.is_dir():
            continue
            
        version = version_dir.name
        print(f"Fixing Debian {version} services...")
        
        for service_dir in version_dir.iterdir():
            if not service_dir.is_dir():
                continue
                
            config_file = service_dir / "lxc-compose.yml"
            if config_file.exists():
                content = config_file.read_text()
                # Replace debian:11 or debian:12 with images:debian/11 or images:debian/12
                old_image = f"debian:{version}"
                new_image = f"images:debian/{version}"
                
                if old_image in content:
                    content = content.replace(old_image, new_image)
                    config_file.write_text(content)
                    print(f"  Fixed {service_dir.name}: {old_image} → {new_image}")

if __name__ == "__main__":
    fix_debian_images()