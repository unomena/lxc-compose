#!/usr/bin/env python3
"""
Update all library lxc-compose.yml files to use template: instead of image:
"""

import os
from pathlib import Path

def update_to_template(file_path):
    """Update a single lxc-compose.yml file to use template"""
    
    # Read the file
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Map image references to template names
    replacements = [
        ('image: images:alpine/3.19', 'template: alpine-3.19'),
        ('image: ubuntu:22.04', 'template: ubuntu-22.04'),
        ('image: ubuntu:24.04', 'template: ubuntu-24.04'),
        ('image: ubuntu-minimal:22.04', 'template: ubuntu-minimal-22.04'),
        ('image: ubuntu-minimal:24.04', 'template: ubuntu-minimal-24.04'),
        ('image: images:debian/11', 'template: debian-11'),
        ('image: images:debian/12', 'template: debian-12'),
    ]
    
    # Apply replacements
    original = content
    for old, new in replacements:
        content = content.replace(old, new)
    
    # Write back if changed
    if content != original:
        with open(file_path, 'w') as f:
            f.write(content)
        return True
    return False

def main():
    library_path = Path("library")
    count = 0
    
    # Find all lxc-compose.yml files
    for yml_file in library_path.glob("**/lxc-compose.yml"):
        if update_to_template(yml_file):
            count += 1
            print(f"Updated: {yml_file}")
    
    print(f"\nTotal files updated: {count}")

if __name__ == "__main__":
    main()