#!/usr/bin/env python3
"""Add log specifications to all library services"""

import os
import glob

# Log specifications for each service type
LOG_SPECS = {
    'postgresql': [
        'postgresql:/var/log/postgresql/postgresql.log'
    ],
    'redis': [
        'redis:/var/log/redis/redis-server.log'
    ],
    'mysql': [
        'mysql:/var/log/mysql/error.log',
        'query:/var/log/mysql/query.log'
    ],
    'nginx': [
        'access:/var/log/nginx/access.log',
        'error:/var/log/nginx/error.log'
    ],
    'haproxy': [
        'haproxy:/var/log/haproxy.log'
    ],
    'mongodb': [
        'mongodb:/var/log/mongodb.log'
    ],
    'memcached': [
        'memcached:/var/log/memcached.log'
    ],
    'rabbitmq': [
        'rabbitmq:/var/log/rabbitmq/rabbit.log',
        'startup:/var/log/rabbitmq/startup_log'
    ],
    'elasticsearch': [
        'elasticsearch:/opt/elasticsearch/logs/elasticsearch.log'
    ],
    'grafana': [
        'grafana:/var/log/grafana/grafana.log'
    ],
    'prometheus': [
        'prometheus:/opt/prometheus/prometheus.log'
    ]
}

def add_logs_to_service(file_path, service_type):
    """Add log specifications to a service file"""
    
    # Get the log specs for this service
    if service_type not in LOG_SPECS:
        print(f"  No log specs defined for {service_type}")
        return False
    
    logs = LOG_SPECS[service_type]
    
    # Read the file
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    # Check if logs already exist
    has_logs = any('logs:' in line and not line.strip().startswith('#') for line in lines)
    if has_logs:
        print(f"  Logs already defined")
        return False
    
    # Find where to insert logs (after tests section, before post_install)
    new_lines = []
    added_logs = False
    i = 0
    
    while i < len(lines):
        line = lines[i]
        new_lines.append(line)
        
        # Look for tests section
        if 'tests:' in line and not line.strip().startswith('#') and not added_logs:
            # Skip through the tests section
            i += 1
            while i < len(lines):
                if lines[i].strip() and not lines[i].startswith('    '):
                    # End of tests section
                    break
                new_lines.append(lines[i])
                i += 1
            
            # Add logs section
            new_lines.append('    \n')
            new_lines.append('    logs:\n')
            for log in logs:
                new_lines.append(f'      - {log}\n')
            added_logs = True
            continue
        
        i += 1
    
    if not added_logs:
        # If no tests section found, add logs before post_install
        new_lines2 = []
        for line in new_lines:
            if 'post_install:' in line and not line.strip().startswith('#') and not added_logs:
                # Add logs section before post_install
                new_lines2.append('    logs:\n')
                for log in logs:
                    new_lines2.append(f'      - {log}\n')
                new_lines2.append('    \n')
                added_logs = True
            new_lines2.append(line)
        new_lines = new_lines2
    
    if added_logs:
        # Write back
        with open(file_path, 'w') as f:
            f.writelines(new_lines)
        return True
    
    return False

def check_logs_status():
    """Check which services have logs defined"""
    stats = {
        'with_logs': 0,
        'without_logs': 0,
        'services': {}
    }
    
    for file_path in glob.glob('library/**/*.yml', recursive=True):
        # Skip if not a service config
        if 'lxc-compose.yml' not in file_path:
            continue
            
        # Extract service type from path
        service_type = os.path.basename(os.path.dirname(file_path))
        
        # Read and check for logs
        with open(file_path, 'r') as f:
            content = f.read()
            
        has_logs = 'logs:' in content and not content.split('logs:')[0].rstrip().endswith('#')
        
        if has_logs:
            stats['with_logs'] += 1
            status = '✓'
        else:
            stats['without_logs'] += 1
            status = '✗'
        
        if service_type not in stats['services']:
            stats['services'][service_type] = {'with': 0, 'without': 0}
        
        if status == '✓':
            stats['services'][service_type]['with'] += 1
        else:
            stats['services'][service_type]['without'] += 1
    
    return stats

def main():
    print("Checking log specifications in library services...")
    print("=" * 60)
    
    # First check current status
    before_stats = check_logs_status()
    print(f"Current status:")
    print(f"  Services with logs: {before_stats['with_logs']}")
    print(f"  Services without logs: {before_stats['without_logs']}")
    print()
    
    if before_stats['without_logs'] == 0:
        print("✅ All services already have log specifications!")
        return
    
    print("Adding log specifications to services...")
    print("-" * 60)
    
    added_count = 0
    for file_path in sorted(glob.glob('library/**/*.yml', recursive=True)):
        # Skip if not a service config
        if 'lxc-compose.yml' not in file_path:
            continue
            
        # Extract service type from path
        service_type = os.path.basename(os.path.dirname(file_path))
        
        # Extract base and version for display
        parts = file_path.split('/')
        base = parts[1] if len(parts) > 1 else 'unknown'
        version = parts[2] if len(parts) > 2 else 'unknown'
        
        print(f"Processing {service_type} on {base}/{version}...")
        
        if add_logs_to_service(file_path, service_type):
            print(f"  ✓ Added log specifications")
            added_count += 1
    
    print()
    print("=" * 60)
    
    # Check final status
    after_stats = check_logs_status()
    print(f"Final status:")
    print(f"  Services with logs: {after_stats['with_logs']}")
    print(f"  Services without logs: {after_stats['without_logs']}")
    print(f"  Added logs to: {added_count} services")
    print()
    
    # Show breakdown by service type
    print("Breakdown by service type:")
    print("-" * 40)
    for service in sorted(after_stats['services'].keys()):
        stats = after_stats['services'][service]
        total = stats['with'] + stats['without']
        if stats['without'] == 0:
            status = "✅"
        else:
            status = "❌"
        print(f"{status} {service:15s}: {stats['with']}/{total} have logs")

if __name__ == '__main__':
    main()