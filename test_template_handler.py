#!/usr/bin/env python3
"""
Test the template handler functionality
"""

import sys
import os
import yaml

# Add CLI directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'cli'))

from template_handler import TemplateHandler

def test_template_handler():
    """Test template handling"""
    
    # Initialize handler
    handler = TemplateHandler(templates_dir='templates')
    
    # Test loading a template
    print("Testing template loading...")
    template = handler.load_template('alpine-3.19')
    print(f"  Alpine template image: {template.get('image')}")
    
    # Test alias resolution
    print("\nTesting alias resolution...")
    template = handler.load_template('ubuntu-lts')
    print(f"  ubuntu-lts resolves to image: {template.get('image')}")
    
    # Test merging with a sample container config
    print("\nTesting template merging...")
    container_config = {
        'name': 'test-postgres',
        'template': 'alpine-3.19',
        'packages': ['postgresql15-client'],
        'exposed_ports': [5432],
        'post_install': [
            {'name': 'Setup DB', 'command': 'echo "Setting up database"'}
        ]
    }
    
    merged = handler.merge_with_template(container_config)
    print(f"  Merged config:")
    print(f"    Image: {merged.get('image')}")
    print(f"    Packages: {merged.get('packages', [])[:3]}...")  # Show first 3
    print(f"    Post-install commands: {len(merged.get('post_install', []))} total")
    
    # Test processing a complete compose file
    print("\nTesting compose file processing...")
    compose_config = {
        'version': '1.0',
        'containers': {
            'postgres': {
                'template': 'debian-12',
                'packages': ['postgresql'],
                'exposed_ports': [5432]
            },
            'redis': {
                'template': 'alpine-3.19',
                'packages': ['redis'],
                'exposed_ports': [6379]
            }
        }
    }
    
    processed = handler.process_compose_file(compose_config)
    for name, container in processed['containers'].items():
        print(f"  {name}: image={container.get('image')}, packages={len(container.get('packages', []))}")
    
    print("\n✅ All tests passed!")

if __name__ == "__main__":
    test_template_handler()