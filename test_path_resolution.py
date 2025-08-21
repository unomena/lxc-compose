#!/usr/bin/env python3
"""Test script to verify test path resolution for library includes"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'cli'))

from template_handler import TemplateHandler
import yaml

def test_path_resolution():
    print("Testing path resolution for library includes...")
    print("=" * 50)
    
    # Load the test configuration
    config_file = 'examples/test-path-resolution.yml'
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f)
    
    # Process with template handler
    handler = TemplateHandler()
    processed = handler.process_compose_file(config)
    
    # Test each container
    for container_name, container in processed['containers'].items():
        print(f"\nContainer: {container_name}")
        print(f"  Template: {container.get('template', 'N/A')}")
        print(f"  Image: {container.get('image', 'N/A')}")
        
        # Check for included packages
        if 'packages' in container:
            print(f"  Packages ({len(container['packages'])} total):")
            for pkg in container['packages'][:5]:  # Show first 5
                print(f"    - {pkg}")
            if len(container['packages']) > 5:
                print(f"    ... and {len(container['packages']) - 5} more")
        
        # Check for tests
        if 'tests' in container:
            print("  Tests:")
            for test_type, tests in container['tests'].items():
                print(f"    {test_type}:")
                for test in tests:
                    if isinstance(test, str):
                        if '@library:' in test:
                            main_part, lib_path = test.split('@library:', 1)
                            name, path = main_part.split(':', 1) if ':' in main_part else ('test', main_part)
                            print(f"      • {name}: {path}")
                            print(f"        (from library: {lib_path})")
                        else:
                            name, path = test.split(':', 1) if ':' in test else ('test', test)
                            print(f"      • {name}: {path}")
        else:
            print("  Tests: None")
        
        # Check for library service metadata
        if '__library_service_path__' in container:
            print(f"  Library metadata: {container['__library_service_path__']}")
    
    print("\n" + "=" * 50)
    print("Path resolution test complete!")
    
    # Now test with the actual CLI module
    print("\nTesting with CLI module...")
    from lxc_compose import LXCCompose
    
    compose = LXCCompose(config_file)
    compose.config = compose.load_config()
    compose.config = compose.template_handler.process_compose_file(compose.config)
    compose.containers = compose.parse_containers()
    
    # Check first container
    if compose.containers:
        first = compose.containers[0]
        print(f"First container: {first.get('name')}")
        if 'tests' in first:
            print("Has tests: Yes")
            for test_type in ['internal', 'external', 'port_forwarding']:
                if test_type in first['tests']:
                    print(f"  {test_type}: {len(first['tests'][test_type])} tests")
        else:
            print("Has tests: No")

if __name__ == '__main__':
    test_path_resolution()