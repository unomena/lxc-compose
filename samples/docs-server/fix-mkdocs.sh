#!/bin/bash
# Script to rebuild documentation in LXC container

echo "Rebuilding documentation in container..."

echo "Checking directory structure:"
lxc exec lxc-docs -- ls -la /opt/lxc-compose/docs/docs/ | head -10

echo ""
echo "Rebuilding documentation..."
lxc exec lxc-docs -- sh -c "cd /opt/lxc-compose/docs && .venv/bin/mkdocs build --clean"

echo ""
echo "Checking if site was built:"
lxc exec lxc-docs -- ls -la /opt/lxc-compose/docs/site/ | head -10

echo ""
echo "Restarting nginx..."
lxc exec lxc-docs -- supervisorctl restart nginx

echo "Done! Documentation should now be available at http://localhost"