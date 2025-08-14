#!/bin/bash

#############################################################################
# Register Container with LXC Compose Manager
# Updates the registry file when containers are created/modified
#############################################################################

set -euo pipefail

CONTAINER_NAME="$1"
CONTAINER_TYPE="${2:-app}"
CONTAINER_IP="${3:-}"
SERVICES="${4:-}"

REGISTRY_FILE="/etc/lxc-compose/registry.json"

# Create registry file if it doesn't exist
if [ ! -f "$REGISTRY_FILE" ]; then
    mkdir -p /etc/lxc-compose
    echo '{
        "containers": {},
        "port_forwards": [],
        "network": {
            "bridge": "lxcbr0",
            "subnet": "10.0.3.0/24",
            "gateway": "10.0.3.1",
            "next_ip": 2
        }
    }' > "$REGISTRY_FILE"
fi

# Get container IP if not provided
if [ -z "$CONTAINER_IP" ]; then
    CONTAINER_IP=$(sudo lxc-info -n "$CONTAINER_NAME" -iH 2>/dev/null | head -1 || echo "")
fi

# Determine services based on type
if [ -z "$SERVICES" ]; then
    case "$CONTAINER_TYPE" in
        datastore)
            SERVICES='["postgresql", "redis"]'
            ;;
        app)
            SERVICES='["nginx", "python", "nodejs"]'
            ;;
        django)
            SERVICES='["django", "celery", "nginx"]'
            ;;
        *)
            SERVICES='[]'
            ;;
    esac
else
    # Convert comma-separated list to JSON array
    SERVICES=$(echo "$SERVICES" | sed 's/,/","/g' | sed 's/^/["/' | sed 's/$/"]/')
fi

# Update registry using Python (more reliable for JSON manipulation)
python3 - <<EOF
import json
from datetime import datetime

with open('$REGISTRY_FILE', 'r') as f:
    registry = json.load(f)

registry['containers']['$CONTAINER_NAME'] = {
    'name': '$CONTAINER_NAME',
    'type': '$CONTAINER_TYPE',
    'ip': '$CONTAINER_IP',
    'services': $SERVICES,
    'created': datetime.now().isoformat(),
    'status': 'running'
}

registry['last_updated'] = datetime.now().isoformat()

with open('$REGISTRY_FILE', 'w') as f:
    json.dump(registry, f, indent=2)

print(f"Container {registry['containers']['$CONTAINER_NAME']['name']} registered successfully")
EOF