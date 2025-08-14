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
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# No cleanup needed since we clone directly to /srv/lxc-compose

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
    log "Setting up LXC Compose repository in /srv/lxc-compose..."
    
    # Create /srv directory if it doesn't exist
    sudo mkdir -p /srv
    
    # Check if it's already a git repository
    if [[ -d "/srv/lxc-compose/.git" ]]; then
        log "Repository exists, updating to latest version..."
        cd /srv/lxc-compose
        
        # Stash any local changes
        if sudo git status --porcelain | grep -q .; then
            warning "Stashing local changes..."
            sudo git stash push -m "Auto-stash before update $(date +%Y%m%d_%H%M%S)"
        fi
        
        # Pull latest changes
        if sudo git pull origin main; then
            log "Successfully updated to latest version"
            
            # Check if there were stashed changes
            if sudo git stash list | grep -q "Auto-stash before update"; then
                info "Local changes were stashed. To restore: cd /srv/lxc-compose && sudo git stash pop"
            fi
        else
            warning "Could not pull latest changes - continuing with existing version"
        fi
    else
        # Remove old installation if it exists (non-git)
        if [[ -d "/srv/lxc-compose" ]]; then
            warning "Removing old non-git installation..."
            sudo rm -rf /srv/lxc-compose
        fi
        
        # Clone directly to /srv/lxc-compose
        log "Cloning repository to /srv/lxc-compose..."
        sudo git clone "$REPO_URL" /srv/lxc-compose || {
            error "Failed to clone repository to /srv/lxc-compose"
        }
    fi
    
    # Ensure we have the repository
    if [[ ! -d "/srv/lxc-compose" ]]; then
        error "Failed to set up repository in /srv/lxc-compose"
    fi
    
    log "Repository ready at /srv/lxc-compose"
}

# Install files
install_files() {
    log "Setting up LXC Compose structure..."
    
    # Create additional directories needed
    sudo mkdir -p /srv/{apps,shared,logs}
    sudo mkdir -p /srv/shared/{database,media,certificates}
    sudo mkdir -p /srv/shared/database/{postgres,redis}
    
    # Ensure all scripts are executable
    sudo chmod +x /srv/lxc-compose/*.sh 2>/dev/null || true
    sudo chmod +x /srv/lxc-compose/cli/*.py 2>/dev/null || true
    sudo chmod +x /srv/lxc-compose/scripts/*.sh 2>/dev/null || true
    sudo chmod +x /srv/lxc-compose/scripts/*.py 2>/dev/null || true
    
    # Set ownership
    OWNER_USER=${SUDO_USER:-ubuntu}
    sudo chown -R $OWNER_USER:$OWNER_USER /srv/
    
    log "Directory structure created"
}

# Create lxc-compose command
create_command() {
    log "Creating lxc-compose command..."
    
    # Create wrapper script
    sudo tee /usr/local/bin/lxc-compose > /dev/null <<'EOF'
#!/bin/bash
# LXC Compose CLI wrapper
# Check where the CLI actually is
if [[ -f "/srv/lxc-compose/srv/lxc-compose/cli/lxc_compose.py" ]]; then
    exec python3 /srv/lxc-compose/srv/lxc-compose/cli/lxc_compose.py "$@"
elif [[ -f "/srv/lxc-compose/cli/lxc_compose.py" ]]; then
    exec python3 /srv/lxc-compose/cli/lxc_compose.py "$@"
else
    echo "Error: lxc_compose.py not found"
    echo "Checked:"
    echo "  - /srv/lxc-compose/srv/lxc-compose/cli/lxc_compose.py"
    echo "  - /srv/lxc-compose/cli/lxc_compose.py"
    exit 1
fi
EOF
    
    sudo chmod +x /usr/local/bin/lxc-compose
}

# Run setup if requested
run_setup() {
    echo ""
    
    # Check if LXC is already set up
    local NEEDS_SETUP=false
    
    if ! command -v lxc >/dev/null 2>&1; then
        NEEDS_SETUP=true
        info "LXC not installed - setup required"
    elif ! ip link show lxcbr0 >/dev/null 2>&1; then
        NEEDS_SETUP=true
        info "LXC bridge not configured - setup required"
    elif [[ ! -d "/srv/apps" ]] || [[ ! -d "/srv/shared" ]] || [[ ! -d "/srv/logs" ]]; then
        NEEDS_SETUP=true
        info "Directory structure incomplete - setup required"
    fi
    
    if [[ "$NEEDS_SETUP" == "true" ]]; then
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║           Initial Setup Required                             ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
    else
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║           LXC Compose Updated! ✓                             ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        info "System already configured"
    fi
    
    echo ""
    info "Repository: /srv/lxc-compose/"
    info "Command: lxc-compose"
    echo ""
    
    # Check if we should skip setup
    SKIP_SETUP=${SKIP_SETUP:-false}
    
    # If running interactively and setup is needed
    if [[ -t 0 ]] && [[ "$SKIP_SETUP" != "true" ]] && [[ "$NEEDS_SETUP" == "true" ]]; then
        read -p "Would you like to run the full host setup now? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            RUN_SETUP=true
        else
            RUN_SETUP=false
        fi
    elif [[ "$SKIP_SETUP" == "true" ]]; then
        RUN_SETUP=false
        info "Skipping host setup (SKIP_SETUP=true)"
    elif [[ "$NEEDS_SETUP" == "true" ]]; then
        # Non-interactive mode and setup needed - run it
        RUN_SETUP=true
        log "Running host setup automatically..."
    else
        # Setup not needed
        RUN_SETUP=false
        log "System already configured - skipping setup"
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
        if [[ "$NEEDS_SETUP" == "true" ]]; then
            echo "To complete the setup, run:"
            echo "  sudo bash /srv/lxc-compose/setup-lxc-host.sh"
        else
            echo "To run the setup wizard:"
            echo "  lxc-compose wizard"
            echo ""
            echo "To check system health:"
            echo "  lxc-compose doctor"
            echo ""
            echo "To update the repository:"
            echo "  lxc-compose update"
            echo ""
            echo "To see available commands:"
            echo "  lxc-compose --help"
            echo ""
            echo "To see example usage:"
            echo "  lxc-compose examples"
        fi
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
}

# Run main function
main "$@"