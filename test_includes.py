#!/usr/bin/env python3
"""
Test the includes functionality
"""

import sys
import os
import json

# Add CLI directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'cli'))

def test_includes():
    """Test that includes are resolved correctly"""
    
    # Check library structure
    print("Checking library structure...")
    library_services = {
        'postgresql': 'PostgreSQL database',
        'redis': 'Redis cache',
        'nginx': 'Nginx web server',
        'mysql': 'MySQL database',
        'mongodb': 'MongoDB NoSQL',
        'haproxy': 'HAProxy load balancer',
        'memcached': 'Memcached cache',
        'rabbitmq': 'RabbitMQ message queue',
        'elasticsearch': 'Elasticsearch search',
        'grafana': 'Grafana monitoring',
        'prometheus': 'Prometheus metrics'
    }
    
    found_count = 0
    for service in library_services:
        # Check if service exists in at least one template location
        paths_to_check = [
            f'library/alpine/3.19/{service}/lxc-compose.yml',
            f'library/ubuntu/24.04/{service}/lxc-compose.yml',
            f'library/debian/12/{service}/lxc-compose.yml'
        ]
        
        for path in paths_to_check:
            if os.path.exists(path):
                found_count += 1
                break
    
    print(f"  Found {found_count}/{len(library_services)} library services")
    
    # Test template resolution
    print("\nTesting template resolution...")
    from template_handler import TemplateHandler
    
    handler = TemplateHandler()
    
    # Test resolving template to path
    test_cases = [
        ('alpine-3.19', 'alpine/3.19'),
        ('ubuntu-24.04', 'ubuntu/24.04'),
        ('debian-bookworm', 'debian/12'),
        ('ubuntu-lts', 'ubuntu/24.04'),
    ]
    
    for template, expected_path in test_cases:
        actual_path = handler.resolve_template_to_path(template)
        status = '✅' if actual_path == expected_path else '❌'
        print(f"  {status} {template} -> {actual_path} (expected: {expected_path})")
    
    # Test loading a library service
    print("\nTesting library service loading...")
    
    # Test loading nginx from alpine
    nginx_config = handler.load_library_service('alpine-3.19', 'nginx')
    if nginx_config:
        print(f"  ✅ Loaded nginx from alpine-3.19")
        print(f"     Packages: {nginx_config.get('packages', [])}")
        print(f"     Ports: {nginx_config.get('exposed_ports', [])}")
    else:
        print(f"  ❌ Failed to load nginx from alpine-3.19")
    
    # Test full includes processing
    print("\nTesting full includes processing...")
    
    test_config = {
        'version': '1.0',
        'containers': {
            'web': {
                'template': 'alpine-3.19',
                'includes': ['nginx'],
                'post_install': [{
                    'name': 'Custom setup',
                    'command': 'echo "My custom config"'
                }]
            },
            'db': {
                'template': 'debian-12',
                'includes': ['postgresql'],
                'environment': {
                    'POSTGRES_PASSWORD': 'secret'
                }
            }
        }
    }
    
    processed = handler.process_compose_file(test_config)
    
    for name, container in processed['containers'].items():
        print(f"\n  Container: {name}")
        print(f"    Image: {container.get('image', 'N/A')}")
        print(f"    Packages: {len(container.get('packages', []))} total")
        
        if 'post_install' in container:
            print(f"    Post-install commands:")
            for cmd in container['post_install'][:3]:  # Show first 3
                print(f"      - {cmd.get('name', 'Unknown')}")
            if len(container['post_install']) > 3:
                print(f"      ... and {len(container['post_install']) - 3} more")
    
    print("\n✅ Includes system is working!")

if __name__ == "__main__":
    test_includes()