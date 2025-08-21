#!/bin/bash
# Quick fix script for MkDocs configuration issue

echo "Fixing MkDocs configuration in container..."

# Remove any docs_dir or site_dir settings from mkdocs.yml
lxc exec lxc-docs -- sh -c "cd /opt/lxc-compose/docs && sed -i '/^docs_dir:/d' mkdocs.yml"
lxc exec lxc-docs -- sh -c "cd /opt/lxc-compose/docs && sed -i '/^site_dir:/d' mkdocs.yml"

echo "Checking mkdocs.yml (first 15 lines):"
lxc exec lxc-docs -- head -15 /opt/lxc-compose/docs/mkdocs.yml

echo ""
echo "Attempting to rebuild documentation..."
lxc exec lxc-docs -- sh -c "cd /opt/lxc-compose/docs && .venv/bin/mkdocs build --clean"

echo ""
echo "Checking if site was built:"
lxc exec lxc-docs -- ls -la /opt/lxc-compose/docs/site/ | head -10

echo "Done! Documentation should now be available at http://localhost"