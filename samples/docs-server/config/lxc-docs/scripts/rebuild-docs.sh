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
        
        # Build from parent directory
        if [ "$BUILD_CLEAN" = "true" ]; then
            /opt/lxc-compose/docs/.venv/bin/mkdocs build --config-file docs/mkdocs.yml --clean
        else
            /opt/lxc-compose/docs/.venv/bin/mkdocs build --config-file docs/mkdocs.yml
        fi
        echo "Documentation rebuilt at $(date)"
    fi
    
    # Check at configured interval
    sleep ${UPDATE_INTERVAL}
done