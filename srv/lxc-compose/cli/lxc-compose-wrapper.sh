#!/bin/bash

# LXC Compose wrapper script that handles sudo authentication upfront

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Commands that require sudo privileges
SUDO_COMMANDS="up down ps exec restart start stop rm"

# Check if the command requires sudo
NEEDS_SUDO=false
for cmd in $SUDO_COMMANDS; do
    if [[ "$1" == "$cmd" ]]; then
        NEEDS_SUDO=true
        break
    fi
done

# If sudo is needed, check if we need authentication
if [ "$NEEDS_SUDO" = true ]; then
    # Check if sudo works without a password
    if sudo -n true 2>/dev/null; then
        # Passwordless sudo is configured, no need to authenticate
        :
    else
        # Request sudo privileges upfront
        # This will prompt for password if needed and cache it
        sudo -v
        
        # Keep sudo alive in background (refresh every 50 seconds)
        (while true; do sudo -n true; sleep 50; done 2>/dev/null) &
        SUDO_KEEPALIVE_PID=$!
        
        # Ensure we kill the keepalive process on exit
        trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT
    fi
fi

# Execute the Python script with all arguments
exec python3 "$SCRIPT_DIR/lxc_compose.py" "$@"