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
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              LXC Compose Quick Installer                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Download and run the install script
echo -e "${BLUE}Downloading installation script...${NC}"
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh -o /tmp/lxc-compose-install.sh

echo -e "${BLUE}Running installation...${NC}"
sudo bash /tmp/lxc-compose-install.sh

# Cleanup
rm -f /tmp/lxc-compose-install.sh

echo -e "${GREEN}Installation complete! Run 'lxc-compose wizard' to get started.${NC}"
