#!/bin/sh
# Initialize documentation build environment

set -e

echo "==================================="
echo "Initializing Documentation Server"
echo "==================================="

# Use environment variables with defaults
REPO_URL=${REPO_URL:-https://github.com/unomena/lxc-compose.git}
REPO_BRANCH=${REPO_BRANCH:-main}
BUILD_CLEAN=${BUILD_CLEAN:-true}

# Clone repository
echo "Cloning repository from $REPO_URL..."
cd /opt
if [ ! -d "lxc-compose" ]; then
    git clone $REPO_URL lxc-compose
    cd lxc-compose
    git checkout $REPO_BRANCH
    echo "Repository cloned successfully"
else
    echo "Repository already exists, pulling latest..."
    cd lxc-compose
    git pull origin $REPO_BRANCH
fi

# Setup Python environment
echo "Setting up Python environment..."
cd /opt/lxc-compose/docs
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    .venv/bin/pip install --upgrade pip setuptools wheel
    .venv/bin/pip install -r requirements.txt
    echo "Python environment created"
else
    echo "Python environment already exists"
fi

# Build documentation
echo "Building documentation..."
.venv/bin/mkdocs build --clean
echo "Documentation built successfully"

# Ensure scripts are executable
chmod +x /docs/scripts/*.sh

echo "==================================="
echo "Documentation server initialized!"
echo "Access at http://localhost"
echo "===================================="