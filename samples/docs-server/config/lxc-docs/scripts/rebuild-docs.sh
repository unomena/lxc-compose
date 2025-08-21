#!/bin/sh
# Auto-rebuild documentation when repository updates

# Use environment variables with defaults
REPO_BRANCH=${REPO_BRANCH:-main}
UPDATE_INTERVAL=${UPDATE_INTERVAL:-300}
AUTO_UPDATE=${AUTO_UPDATE:-true}
BUILD_CLEAN=${BUILD_CLEAN:-true}

if [ "$AUTO_UPDATE" != "true" ]; then
    echo "Auto-update is disabled (AUTO_UPDATE=$AUTO_UPDATE)"
    # Keep the process running but don't check for updates
    while true; do
        sleep 86400
    done
fi

echo "Auto-update enabled, checking every ${UPDATE_INTERVAL} seconds for branch ${REPO_BRANCH}"

while true; do
    cd /opt/lxc-compose
    
    # Check for updates
    git fetch origin
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/${REPO_BRANCH})
    
    if [ "$LOCAL" != "$REMOTE" ]; then
        echo "Updates detected, rebuilding documentation..."
        git pull origin ${REPO_BRANCH}
        
        # Build from docs directory
        cd docs
        if [ "$BUILD_CLEAN" = "true" ]; then
            .venv/bin/mkdocs build --clean
        else
            .venv/bin/mkdocs build
        fi
        echo "Documentation rebuilt at $(date)"
        cd ..
    fi
    
    # Check at configured interval
    sleep ${UPDATE_INTERVAL}
done