#!/usr/bin/env python3
"""
Validate template handler syntax without dependencies
"""

import os
import ast

def validate_python_syntax(file_path):
    """Validate Python file syntax"""
    with open(file_path, 'r') as f:
        code = f.read()
    
    try:
        ast.parse(code)
        return True, "OK"
    except SyntaxError as e:
        return False, str(e)

# Check template handler
cli_dir = "cli"
template_handler = os.path.join(cli_dir, "template_handler.py")
lxc_compose = os.path.join(cli_dir, "lxc_compose.py")

print("Validating Python syntax...")

for file_path in [template_handler, lxc_compose]:
    if os.path.exists(file_path):
        valid, msg = validate_python_syntax(file_path)
        if valid:
            print(f"  ✅ {file_path}: Valid")
        else:
            print(f"  ❌ {file_path}: {msg}")
    else:
        print(f"  ⚠️  {file_path}: Not found")

print("\nChecking template files...")
templates_dir = "templates"
template_count = 0
alias_count = 0

for template_file in os.listdir(templates_dir):
    if template_file.endswith('.yml'):
        template_count += 1
        # Check if it's likely an alias by size (aliases are smaller)
        file_size = os.path.getsize(os.path.join(templates_dir, template_file))
        if file_size < 200:  # Aliases are typically under 200 bytes
            alias_count += 1

print(f"  Found {template_count} template files ({template_count - alias_count} base, {alias_count} aliases)")

print("\nChecking library updates...")
import_count = 0
for root, dirs, files in os.walk("library"):
    for file in files:
        if file == "lxc-compose.yml":
            file_path = os.path.join(root, file)
            with open(file_path, 'r') as f:
                content = f.read()
                if "template:" in content:
                    import_count += 1

print(f"  Found {import_count} library configs using template:")

if import_count == 77:
    print("  ✅ All 77 library configs updated!")
else:
    print(f"  ⚠️  Expected 77, found {import_count}")

print("\nDone!")