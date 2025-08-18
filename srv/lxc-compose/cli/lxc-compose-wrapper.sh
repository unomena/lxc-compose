#!/bin/bash

# Simple wrapper script for lxc-compose

# Get the real directory where this script is located (resolving symlinks)
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Execute the Python script with all arguments
exec python3 "$SCRIPT_DIR/lxc_compose.py" "$@"