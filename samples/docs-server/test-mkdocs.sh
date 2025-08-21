#!/bin/bash
# Test script to debug MkDocs configuration

echo "==================================="
echo "Testing MkDocs Configuration"
echo "==================================="

# Build and run the Docker container
echo "Building Docker image..."
docker build -t lxc-docs-test . || exit 1

echo ""
echo "Running container for testing..."
docker run --rm -it --name mkdocs-test lxc-docs-test /bin/sh -c '
    echo "=== Checking directory structure ==="
    ls -la /opt/lxc-compose/docs/ | head -20
    
    echo ""
    echo "=== Checking for docs/docs directory ==="
    ls -la /opt/lxc-compose/docs/docs 2>&1 || echo "No docs/docs directory (this is good)"
    
    echo ""
    echo "=== MkDocs config (first 20 lines) ==="
    head -20 /opt/lxc-compose/docs/mkdocs.yml
    
    echo ""
    echo "=== Checking for docs_dir or site_dir in config ==="
    grep -E "^(docs_dir|site_dir):" /opt/lxc-compose/docs/mkdocs.yml || echo "No docs_dir or site_dir found (this is good)"
    
    echo ""
    echo "=== Python/MkDocs versions ==="
    /opt/lxc-compose/docs/.venv/bin/python --version
    /opt/lxc-compose/docs/.venv/bin/mkdocs --version
    
    echo ""
    echo "=== Attempting to build docs ==="
    cd /opt/lxc-compose/docs
    .venv/bin/mkdocs build --clean --verbose
    
    echo ""
    echo "=== Checking if site was built ==="
    ls -la /opt/lxc-compose/docs/site/ | head -10
'

echo ""
echo "==================================="
echo "Test complete!"
echo "==================================="