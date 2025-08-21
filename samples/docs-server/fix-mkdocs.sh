#!/bin/bash
# Quick fix script for MkDocs configuration issue

echo "Fixing MkDocs documentation structure in container..."

# Move markdown files to docs subdirectory where MkDocs expects them
echo "Reorganizing documentation structure..."
lxc exec lxc-docs -- sh -c "cd /opt/lxc-compose/docs && mkdir -p docs && mv *.md docs/ 2>/dev/null || true"

echo ""
echo "Checking directory structure:"
lxc exec lxc-docs -- ls -la /opt/lxc-compose/docs/docs/ | head -10

echo ""
echo "Attempting to rebuild documentation..."
lxc exec lxc-docs -- sh -c "cd /opt/lxc-compose/docs && .venv/bin/mkdocs build --clean"

echo ""
echo "Checking if site was built:"
lxc exec lxc-docs -- ls -la /opt/lxc-compose/docs/site/ | head -10

echo ""
echo "Restarting nginx..."
lxc exec lxc-docs -- supervisorctl restart nginx

echo "Done! Documentation should now be available at http://localhost"