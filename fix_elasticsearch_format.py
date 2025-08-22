#!/usr/bin/env python3
"""Fix formatting issues in Elasticsearch configs where logs were inserted incorrectly"""

import glob

def fix_elasticsearch_file(file_path):
    """Fix a single elasticsearch file"""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Check if this file has the issue
    if 'logs:\n      - elasticsearch:/opt/elasticsearch/logs/elasticsearch.log\n# Note:' in content:
        # Fix the issue by moving the comment back to the right place
        lines = content.split('\n')
        new_lines = []
        skip_next = False
        
        for i, line in enumerate(lines):
            if skip_next:
                skip_next = False
                continue
                
            if line == '    logs:' and i+1 < len(lines) and 'elasticsearch:/opt' in lines[i+1]:
                # Skip the logs lines for now, we'll add them back later
                skip_next = True
                continue
            elif line.startswith('# Note: Elasticsearch'):
                # This comment should be part of the command
                continue
            elif line == '        command: |':
                # Add the command with the note
                new_lines.append(line)
                new_lines.append('          # Note: Elasticsearch requires manual download on Alpine')
                continue
            else:
                new_lines.append(line)
        
        # Now add logs section after tests
        final_lines = []
        for i, line in enumerate(new_lines):
            final_lines.append(line)
            if 'tests:' in line and not line.strip().startswith('#'):
                # Find end of tests section
                j = i + 1
                while j < len(new_lines) and (new_lines[j].startswith('      ') or new_lines[j].strip() == ''):
                    final_lines.append(new_lines[j])
                    j += 1
                # Add logs
                final_lines.append('    ')
                final_lines.append('    logs:')
                final_lines.append('      - elasticsearch:/opt/elasticsearch/logs/elasticsearch.log')
                # Skip the lines we already added
                for k in range(j, len(new_lines)):
                    if new_lines[k] not in final_lines:
                        final_lines.append(new_lines[k])
                break
        
        # Write back
        with open(file_path, 'w') as f:
            f.write('\n'.join(final_lines))
        
        return True
    return False

def main():
    print("Fixing Elasticsearch formatting issues...")
    fixed = 0
    
    for file_path in glob.glob('library/**/elasticsearch/lxc-compose.yml', recursive=True):
        print(f"Checking {file_path}...")
        if fix_elasticsearch_file(file_path):
            print(f"  ✓ Fixed")
            fixed += 1
    
    print(f"\nFixed {fixed} files")

if __name__ == '__main__':
    main()