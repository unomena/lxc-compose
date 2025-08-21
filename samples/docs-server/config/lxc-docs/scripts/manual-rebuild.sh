#!/bin/sh
# Manually rebuild documentation

# Use environment variables with defaults
REPO_BRANCH=${REPO_BRANCH:-main}
BUILD_CLEAN=${BUILD_CLEAN:-true}

echo "Manually rebuilding documentation..."
cd /opt/lxc-compose
git pull origin ${REPO_BRANCH}

cd docs

# Ensure mkdocs.yml doesn't have problematic settings
sed -i '/^docs_dir:/d' mkdocs.yml 2>/dev/null || true
sed -i '/^site_dir:/d' mkdocs.yml 2>/dev/null || true

if [ "$BUILD_CLEAN" = "true" ]; then
    echo "Building with --clean flag..."
    .venv/bin/mkdocs build --clean
else
    echo "Building without --clean flag..."
    .venv/bin/mkdocs build
fi

echo "Documentation rebuilt successfully"