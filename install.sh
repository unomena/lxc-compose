#!/bin/bash

#############################################################################
# LXC Compose Installation Script (install.sh)
# 
# Full installation script that:
# 1. Downloads LXC Compose from GitHub repository
# 2. Installs all files to /srv/lxc-compose/
# 3. Creates the lxc-compose command
# 4. Automatically runs the host setup (unless in interactive mode)
#
# Compatible with Ubuntu 22.04 and 24.04 LTS
# 
# Usage:
#   - Via curl one-liner: Use get.sh instead
#   - Direct: ./install.sh
#   - Skip setup: SKIP_SETUP=true ./install.sh
#############################################################################

set -euo pipefail

# Configuration
REPO_URL="https://github.com/unomena/lxc-compose.git"
INSTALL_DIR="/srv"
TEMP_DIR="/tmp/lxc-compose-install-$$"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    cleanup
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as ubuntu user or with sudo
    if [[ "$USER" != "ubuntu" ]] && [[ "$EUID" -ne 0 ]]; then
        error "This script should be run as 'ubuntu' user or with sudo"
    fi
    
    # Check Ubuntu version
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS version"
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        error "This script is designed for Ubuntu systems only"
    fi
    
    if [[ "$VERSION_ID" != "22.04" ]] && [[ "$VERSION_ID" != "24.04" ]]; then
        warning "This script is tested on Ubuntu 22.04 and 24.04 LTS"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    fi
    
    # Check for git
    if ! command -v git &> /dev/null; then
        info "Git not found, installing..."
        sudo apt-get update
        sudo apt-get install -y git
    fi
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        info "Curl not found, installing..."
        sudo apt-get install -y curl
    fi
}

# Download repository
download_repo() {
    log "Downloading LXC Compose repository..."
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Clone repository
    if ! git clone "$REPO_URL" lxc-compose 2>/dev/null; then
        # If clone fails, try downloading as archive
        warning "Git clone failed, trying archive download..."
        curl -L "https://github.com/unomena/lxc-compose/archive/main.tar.gz" -o lxc-compose.tar.gz
        tar -xzf lxc-compose.tar.gz
        mv lxc-compose-main lxc-compose
    fi
    
    if [[ ! -d "lxc-compose" ]]; then
        error "Failed to download repository"
    fi
}

# Install files
install_files() {
    log "Installing LXC Compose files..."
    
    cd "$TEMP_DIR/lxc-compose"
    
    # Create directory structure
    sudo mkdir -p /srv/{lxc-compose,apps,shared,logs}
    sudo mkdir -p /srv/lxc-compose/{cli,templates,configs,scripts,lib}
    sudo mkdir -p /srv/lxc-compose/templates/{base,app,database,monitor}
    sudo mkdir -p /srv/shared/{database,media,certificates}
    sudo mkdir -p /srv/shared/database/{postgres,redis}
    
    # Copy files from srv/ directory
    if [[ -d "srv" ]]; then
        log "Copying srv/ contents..."
        sudo cp -r srv/* /srv/ 2>/dev/null || true
    fi
    
    # Copy CLI files
    if [[ -d "srv/lxc-compose/cli" ]]; then
        sudo cp -r srv/lxc-compose/cli/* /srv/lxc-compose/cli/ 2>/dev/null || true
    fi
    
    # Copy templates
    if [[ -d "srv/lxc-compose/templates" ]]; then
        sudo cp -r srv/lxc-compose/templates/* /srv/lxc-compose/templates/ 2>/dev/null || true
    fi
    
    # Copy configs
    if [[ -d "srv/lxc-compose/configs" ]]; then
        sudo cp -r srv/lxc-compose/configs/* /srv/lxc-compose/configs/ 2>/dev/null || true
    fi
    
    # Copy scripts
    if [[ -d "srv/lxc-compose/scripts" ]]; then
        sudo cp -r srv/lxc-compose/scripts/* /srv/lxc-compose/scripts/ 2>/dev/null || true
    fi
    
    # Copy setup script if exists
    if [[ -f "setup-lxc-host.sh" ]]; then
        sudo cp setup-lxc-host.sh /srv/lxc-compose/setup-lxc-host.sh
        sudo chmod +x /srv/lxc-compose/setup-lxc-host.sh
    fi
    
    # Set ownership
    sudo chown -R ubuntu:ubuntu /srv/
    
    # Make scripts executable
    sudo chmod +x /srv/lxc-compose/cli/*.py 2>/dev/null || true
    sudo chmod +x /srv/lxc-compose/scripts/*.sh 2>/dev/null || true
    sudo chmod +x /srv/lxc-compose/scripts/*.py 2>/dev/null || true
}

# Create lxc-compose command
create_command() {
    log "Creating lxc-compose command..."
    
    # Create wrapper script
    sudo tee /usr/local/bin/lxc-compose > /dev/null <<'EOF'
#!/bin/bash
# LXC Compose CLI wrapper
exec python3 /srv/lxc-compose/cli/lxc_compose.py "$@"
EOF
    
    sudo chmod +x /usr/local/bin/lxc-compose
}

# Run setup if requested
run_setup() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           LXC Compose Files Installed! ✓                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    info "Files installed to: /srv/lxc-compose/"
    info "Command available: lxc-compose"
    echo ""
    
    # Check if we should skip setup (for manual runs or if already set up)
    SKIP_SETUP=${SKIP_SETUP:-false}
    
    # If running interactively and not skipping, ask
    if [[ -t 0 ]] && [[ "$SKIP_SETUP" != "true" ]]; then
        read -p "Would you like to run the full host setup now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            RUN_SETUP=true
        else
            RUN_SETUP=false
        fi
    else
        # Non-interactive mode (piped) or SKIP_SETUP=true - run setup automatically unless skipped
        if [[ "$SKIP_SETUP" == "true" ]]; then
            RUN_SETUP=false
            info "Skipping host setup (SKIP_SETUP=true)"
        else
            RUN_SETUP=true
            log "Running host setup automatically..."
        fi
    fi
    
    if [[ "$RUN_SETUP" == "true" ]]; then
        if [[ -f "/srv/lxc-compose/setup-lxc-host.sh" ]]; then
            log "Setting up LXC host environment..."
            echo ""
            sudo bash /srv/lxc-compose/setup-lxc-host.sh
        else
            warning "Setup script not found at /srv/lxc-compose/setup-lxc-host.sh"
            warning "You can run it manually later"
        fi
    else
        echo ""
        echo "To complete the setup later, run:"
        echo "  sudo bash /srv/lxc-compose/setup-lxc-host.sh"
        echo ""
    fi
}

# Main installation flow
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              LXC Compose Installation Script                 ║"
    echo "║         Docker Compose-like orchestration for LXC            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    download_repo
    install_files
    create_command
    run_setup
    
    cleanup
}

# Run main function
main "$@"