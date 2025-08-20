#!/bin/bash

#############################################################################
# LXC Compose Quick Installer
# 
# Downloads and runs the installation script from GitHub.
# Usage: curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash
#############################################################################

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              LXC Compose Quick Installer                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download the repository
echo -e "${BLUE}→ Downloading LXC Compose...${NC}"
curl -fsSL https://github.com/unomena/lxc-compose/archive/main.tar.gz -o lxc-compose.tar.gz
tar -xzf lxc-compose.tar.gz
cd lxc-compose-main

# Run the install script
echo -e "${BLUE}→ Running installation...${NC}"
sudo bash install.sh

# Cleanup
cd /
rm -rf "$TEMP_DIR"