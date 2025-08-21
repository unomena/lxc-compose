#!/usr/bin/env python3
"""
Verify that test inheritance works correctly with includes
"""

import sys
import os
import yaml

# Add CLI directory to path
sys.path.insert(0, 'cli')

from template_handler import TemplateHandler

def verify_test_inheritance():
    """Verify tests are inherited from library services"""
    
    handler = TemplateHandler()
    
    print("Verifying Test Inheritance")
    print("=========================\n")
    
    # Test case 1: Simple include
    print("Test 1: PostgreSQL include should inherit tests")
    config = {
        'version': '1.0',
        'containers': {
            'test-db': {
                'template': 'alpine-3.19',
                'includes': ['postgresql'],
                'environment': {'POSTGRES_PASSWORD': 'test'}
            }
        }
    }
    
    processed = handler.process_compose_file(config)
    container = processed['containers']['test-db']
    
    # Check if tests are inherited
    if 'tests' in container:
        print(f"  ✓ Tests inherited: {container['tests']}")
    else:
        print("  ✗ No tests found in processed config")
        
    # Load the original library service to compare
    lib_service = handler.load_library_service('alpine-3.19', 'postgresql')
    if lib_service and 'tests' in lib_service:
        print(f"  ✓ Library service has tests: {lib_service['tests']}")
    else:
        print("  ⚠ Library service missing tests")
    
    print()
    
    # Test case 2: Multiple includes
    print("Test 2: Multiple includes should merge tests")
    config = {
        'version': '1.0',
        'containers': {
            'web-stack': {
                'template': 'ubuntu-24.04',
                'includes': ['nginx', 'redis']
            }
        }
    }
    
    processed = handler.process_compose_file(config)
    container = processed['containers']['web-stack']
    
    if 'tests' in container:
        print(f"  ✓ Tests from includes: {container.get('tests', {})}")
    else:
        print("  ⚠ No tests in merged config")
    
    print()
    
    # Test case 3: Check actual test files
    print("Test 3: Verify test files exist in library")
    test_locations = [
        'library/alpine/3.19/postgresql/tests/test.sh',
        'library/ubuntu/24.04/nginx/tests/nginx.sh',
        'library/debian/12/redis/tests/test.sh'
    ]
    
    for test_file in test_locations:
        if os.path.exists(test_file):
            print(f"  ✓ {test_file} exists")
        else:
            print(f"  ✗ {test_file} missing")
    
    print()
    
    # Test case 4: Check inheritance chain
    print("Test 4: Full inheritance chain")
    config = {
        'version': '1.0',
        'containers': {
            'app': {
                'template': 'ubuntu-lts',  # Alias
                'includes': ['postgresql'],
                'packages': ['curl'],
                'tests': {
                    'custom': ['mytest:/tests/custom.sh']
                }
            }
        }
    }
    
    processed = handler.process_compose_file(config)
    container = processed['containers']['app']
    
    print(f"  Image: {container.get('image')}")
    print(f"  Packages: {container.get('packages', [])}")
    print(f"  Tests: {container.get('tests', {})}")
    
    # Verify all parts are present
    checks = [
        ('Image from template', 'ubuntu:24.04' in str(container.get('image', ''))),
        ('PostgreSQL packages', 'postgresql' in str(container.get('packages', []))),
        ('Additional package', 'curl' in container.get('packages', [])),
        ('Library tests', 'external' in container.get('tests', {})),
        ('Custom tests', 'custom' in container.get('tests', {}))
    ]
    
    print("\n  Inheritance verification:")
    for check, result in checks:
        status = '✓' if result else '✗'
        print(f"    {status} {check}")
    
    print("\n" + "="*50)
    print("Test inheritance verification complete!")
    print("\nNOTE: Tests should be automatically available when")
    print("running 'lxc-compose test <container>' on deployed containers.")

if __name__ == "__main__":
    verify_test_inheritance()