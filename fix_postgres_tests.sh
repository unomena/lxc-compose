#!/bin/bash
# Fix PostgreSQL test scripts to use correct user

echo "Fixing PostgreSQL test scripts..."

# Find all PostgreSQL test files
for test_file in library/*/postgresql/tests/test.sh library/*/*/postgresql/tests/test.sh; do
    if [ -f "$test_file" ]; then
        echo "Fixing: $test_file"
        
        # Backup original
        cp "$test_file" "${test_file}.bak"
        
        # Replace incorrect user references with 'postgres'
        # Fix patterns like: su postgresql-alpine-3-19 -> su postgres
        sed -i 's/su postgresql-[a-z0-9-]*/su postgres/g' "$test_file"
        
        echo "  Fixed user references in $test_file"
    fi
done

echo "All PostgreSQL tests fixed!"