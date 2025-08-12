#!/bin/bash

#############################################################################
# LXC Compose Quick Installer
# This script is designed to be downloaded and executed via curl/wget
# Usage: curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash
#############################################################################

set -euo pipefail

# Configuration
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh"
TEMP_INSTALL_SCRIPT="/tmp/lxc-compose-install.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
log() {
    echo -e "${GREEN}[LXC-Compose]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running with proper permissions
if [[ "$EUID" -eq 0 ]] && [[ "$USER" != "ubuntu" ]]; then
    info "Running as root, will use sudo where needed"
elif [[ "$USER" != "ubuntu" ]]; then
    error "Please run as 'ubuntu' user or with sudo"
fi

# Check OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        error "This installer is designed for Ubuntu systems"
    fi
else
    error "Cannot determine operating system"
fi

log "Downloading LXC Compose installer..."

# Download the install script
if command -v curl &> /dev/null; then
    curl -fsSL "$INSTALL_SCRIPT_URL" -o "$TEMP_INSTALL_SCRIPT"
elif command -v wget &> /dev/null; then
    wget -qO "$TEMP_INSTALL_SCRIPT" "$INSTALL_SCRIPT_URL"
else
    error "Neither curl nor wget found. Please install one of them first."
fi

# Verify download
if [[ ! -f "$TEMP_INSTALL_SCRIPT" ]]; then
    error "Failed to download installation script"
fi

# Make executable
chmod +x "$TEMP_INSTALL_SCRIPT"

log "Starting installation..."

# Run the installer
bash "$TEMP_INSTALL_SCRIPT"

# Cleanup
rm -f "$TEMP_INSTALL_SCRIPT"

log "Installation process completed!"