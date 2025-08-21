#!/bin/bash

set -euo pipefail

# Configuration
INSTALL_DIR="/srv/lxc-compose"
BIN_PATH="/usr/local/bin/lxc-compose"
GITHUB_REPO="unomena/lxc-compose"
GITHUB_BRANCH="main"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; exit 1; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Script directory detection
SCRIPT_DIR=""
TEMP_DIR=""
IS_REMOTE_INSTALL=false

# Display banner
display_banner() {
    echo -e "${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              LXC Compose Installation Script                  ║"
    echo "║                   Simple & Lightweight                        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Cleanup function
cleanup() {
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set up trap for cleanup
trap cleanup EXIT

# Detect installation method and prepare files
prepare_installation() {
    # Check if we're running from a local repository
    if [[ -f "cli/lxc_compose.py" ]] && [[ -d "samples" ]]; then
        # Local installation - files are in current directory
        SCRIPT_DIR="$(pwd)"
        info "Installing from local repository..."
    elif [[ -f "../cli/lxc_compose.py" ]] && [[ -d "../samples" ]]; then
        # Running from within a subdirectory of the repo
        SCRIPT_DIR="$(cd .. && pwd)"
        info "Installing from local repository..."
    else
        # Remote installation - need to download
        IS_REMOTE_INSTALL=true
        info "Downloading LXC Compose from GitHub..."
        
        # Create temporary directory
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        # Download repository
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "https://github.com/${GITHUB_REPO}/archive/${GITHUB_BRANCH}.tar.gz" -o lxc-compose.tar.gz || \
                error "Failed to download LXC Compose"
        elif command -v wget >/dev/null 2>&1; then
            wget -q "https://github.com/${GITHUB_REPO}/archive/${GITHUB_BRANCH}.tar.gz" -O lxc-compose.tar.gz || \
                error "Failed to download LXC Compose"
        else
            error "Neither curl nor wget is available. Please install one of them."
        fi
        
        # Extract archive
        tar -xzf lxc-compose.tar.gz || error "Failed to extract archive"
        
        # Set script directory to extracted location
        SCRIPT_DIR="${TEMP_DIR}/lxc-compose-${GITHUB_BRANCH}"
        
        if [[ ! -d "$SCRIPT_DIR" ]]; then
            # Try alternative directory name
            SCRIPT_DIR="${TEMP_DIR}/lxc-compose-main"
        fi
        
        if [[ ! -d "$SCRIPT_DIR" ]]; then
            error "Failed to find extracted files"
        fi
        
        log "Downloaded LXC Compose successfully"
    fi
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check if running with sudo
    if [[ "$EUID" -ne 0 ]] && [[ "$(id -u)" -ne 0 ]]; then
        error "This script must be run with sudo"
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
    
    log "Prerequisites check passed"
}

# Install dependencies
install_dependencies() {
    info "Installing dependencies..."
    
    # Update package list
    apt-get update -qq
    
    # Determine which LXD package to install based on Ubuntu version
    . /etc/os-release
    if [[ "$VERSION_ID" == "24.04" ]]; then
        # Ubuntu 24.04 uses snap for LXD
        info "Installing LXD via snap for Ubuntu 24.04..."
        snap install lxd || true
        LXD_CMD="lxd"
    else
        # Ubuntu 22.04 and earlier use apt package
        LXD_CMD="lxd"
        apt-get install -y lxd || true
    fi
    
    # Install other required packages
    apt-get install -y \
        lxc \
        python3 \
        python3-click \
        python3-yaml \
        iptables \
        curl \
        wget
    
    # Initialize LXD if not already initialized
    if command -v lxd >/dev/null 2>&1; then
        if ! lxd waitready --timeout=5 2>/dev/null; then
            info "Initializing LXD with minimal config..."
            # Use minimal init to avoid YAML issues
            cat <<EOF | lxd init --preseed
config: {}
networks: []
storage_pools:
- config:
    source: /var/snap/lxd/common/lxd/storage-pools/default
  description: ""
  name: default
  driver: dir
profiles:
- config: {}
  description: ""
  devices:
    root:
      path: /
      pool: default
      type: disk
  name: default
projects: []
cluster: null
EOF
        else
            # LXD is running, check if it's properly initialized
            if ! lxc storage list --format=csv 2>/dev/null | grep -q "default"; then
                info "LXD needs initialization. Running minimal setup..."
                # Try preseed initialization for existing LXD
                cat <<EOF | lxd init --preseed 2>/dev/null || true
storage_pools:
- config: {}
  description: ""
  name: default
  driver: dir
EOF
                # If preseed fails, try direct creation
                if ! lxc storage list --format=csv 2>/dev/null | grep -q "default"; then
                    info "Creating default storage pool directly..."
                    lxc storage create default dir 2>&1 | grep -v "yaml:" || true
                fi
            fi
        fi
    elif command -v /snap/bin/lxd >/dev/null 2>&1; then
        if ! /snap/bin/lxd waitready --timeout=5 2>/dev/null; then
            info "Initializing LXD with minimal config..."
            # Use minimal init to avoid YAML issues
            cat <<EOF | /snap/bin/lxd init --preseed
config: {}
networks: []
storage_pools:
- config:
    source: /var/snap/lxd/common/lxd/storage-pools/default
  description: ""
  name: default
  driver: dir
profiles:
- config: {}
  description: ""
  devices:
    root:
      path: /
      pool: default
      type: disk
  name: default
projects: []
cluster: null
EOF
        else
            # LXD is running, check if it's properly initialized
            if ! lxc storage list --format=csv 2>/dev/null | grep -q "default"; then
                info "LXD needs initialization. Running minimal setup..."
                # Try preseed initialization for existing LXD
                cat <<EOF | /snap/bin/lxd init --preseed 2>/dev/null || true
storage_pools:
- config: {}
  description: ""
  name: default
  driver: dir
EOF
                # If preseed fails, try direct creation
                if ! lxc storage list --format=csv 2>/dev/null | grep -q "default"; then
                    info "Creating default storage pool directly..."
                    lxc storage create default dir 2>&1 | grep -v "yaml:" || true
                fi
            fi
        fi
    fi
    
    # Ensure network bridge exists
    if ! lxc network list --format=csv 2>/dev/null | grep -q "^lxdbr0,"; then
        info "Creating network bridge..."
        lxc network create lxdbr0 2>/dev/null || true
        if lxc network list --format=csv 2>/dev/null | grep -q "^lxdbr0,"; then
            log "Network bridge created successfully"
        fi
    fi
    
    # Ensure default profile has root disk
    if ! lxc profile device show default 2>/dev/null | grep -q "root:"; then
        info "Adding root disk to default profile..."
        lxc profile device add default root disk path=/ pool=default 2>/dev/null || true
    fi
    
    # Ensure default profile has network device
    if ! lxc profile device show default 2>/dev/null | grep -q "eth0:"; then
        info "Adding network device to default profile..."
        lxc profile device add default eth0 nic name=eth0 network=lxdbr0 2>/dev/null || true
    fi

    # Install UPF (using the same pattern for consistency)
    info "Installing UPF (Universal Port Forwarding)..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://raw.githubusercontent.com/unomena/upf/main/install.sh | sudo bash
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://raw.githubusercontent.com/unomena/upf/main/install.sh | sudo bash
    fi
    
    log "Dependencies installed"
}

# Setup directories
setup_directories() {
    info "Setting up directories..."

    # Backup existing installation if it exists
    if [[ -d "$INSTALL_DIR" ]]; then
        warning "Existing installation found. Creating backup..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Create required directories
    mkdir -p "$INSTALL_DIR/cli"
    mkdir -p "$INSTALL_DIR/docs"
    mkdir -p "$INSTALL_DIR/samples"
    mkdir -p "$INSTALL_DIR/etc"  # For shared hosts file
    mkdir -p "/etc/lxc-compose"
    mkdir -p "/var/log/lxc-compose"
    
    # Set proper permissions for shared hosts directory
    chmod 755 "$INSTALL_DIR/etc"
    
    # Create initial hosts file if it doesn't exist
    HOSTS_FILE="$INSTALL_DIR/etc/hosts"
    if [[ ! -f "$HOSTS_FILE" ]]; then
        cat > "$HOSTS_FILE" << 'EOF'
# LXC Compose managed hosts file
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback

# Container entries
EOF
        chmod 644 "$HOSTS_FILE"
        log "Created shared hosts file"
    fi
    
    log "Directories created"
}

# Copy files
copy_files() {
    info "Copying files..."
    
    # Copy CLI files
    if [[ -d "$SCRIPT_DIR/cli" ]]; then
        cp -r "$SCRIPT_DIR/cli/"* "$INSTALL_DIR/cli/" 2>/dev/null || true
    fi
    
    # Copy docs
    if [[ -d "$SCRIPT_DIR/docs" ]]; then
        cp -r "$SCRIPT_DIR/docs/"* "$INSTALL_DIR/docs/" 2>/dev/null || true
    fi
    
    # Copy samples
    if [[ -d "$SCRIPT_DIR/samples" ]]; then
        cp -r "$SCRIPT_DIR/samples/"* "$INSTALL_DIR/samples/" 2>/dev/null || true
    fi
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR/cli/lxc_compose.py"
    chmod +x "$INSTALL_DIR/cli/lxc-compose-wrapper.sh" 2>/dev/null || true
    
    log "Files copied"
}

# Setup CLI wrapper
setup_cli() {
    info "Setting up lxc-compose command..."
    
    # Create simple wrapper script
    cat > "$BIN_PATH" << 'EOF'
#!/bin/bash
exec python3 /srv/lxc-compose/cli/lxc_compose.py "$@"
EOF
    
    chmod +x "$BIN_PATH"
    
    log "CLI command installed at $BIN_PATH"
}

# Setup network
setup_network() {
    info "Setting up network..."
    
    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    
    # Setup iptables for NAT
    DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -n "$DEFAULT_IFACE" ]; then
        # Check if rule already exists before adding
        if ! iptables -t nat -C POSTROUTING -s 10.0.0.0/16 -o "$DEFAULT_IFACE" -j MASQUERADE 2>/dev/null; then
            iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -o "$DEFAULT_IFACE" -j MASQUERADE
        fi
    fi
    
    # Save iptables rules
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
    elif command -v iptables-save >/dev/null 2>&1; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4
    fi
    
    log "Network configured"
}

# Copy sample projects
copy_sample_projects() {
    info "Sample projects available..."
    echo "  - django-celery-app: Django + Celery + PostgreSQL + Redis"
    echo "  - django-minimal: Django + PostgreSQL in Alpine (150MB)"
    echo "  - flask-app: Flask with Redis cache"
    echo "  - nodejs-app: Express.js with MongoDB"
    echo "  - searxng-app: Privacy-respecting search engine"
    echo ""
    info "Copying sample projects to ~/lxc-samples..."
    
    # Get the real user's home directory (not root)
    if [ -n "$SUDO_USER" ]; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        USER_NAME="$SUDO_USER"
    else
        USER_HOME="$HOME"
        USER_NAME="$USER"
    fi
    
    # Copy samples
    if [[ -d "$USER_HOME/lxc-samples" ]]; then
        rm -rf "$USER_HOME/lxc-samples"
    fi
    
    if [[ -d "$SCRIPT_DIR/samples" ]]; then
        cp -r "$SCRIPT_DIR/samples" "$USER_HOME/lxc-samples"
        chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/lxc-samples"
        log "Sample projects copied to $USER_HOME/lxc-samples"
    else
        warning "Sample projects not found in installation files"
    fi
    
    echo ""
    echo "To use a sample:"
    echo "  cd ~/lxc-samples/django-minimal"
    echo "  lxc-compose up"
}

# Verify installation
verify_installation() {
    info "Verifying installation..."
    
    # Check if lxc-compose command is available
    if command -v lxc-compose >/dev/null 2>&1; then
        log "lxc-compose command is available"
    else
        error "lxc-compose command not found in PATH"
    fi
    
    # Check if LXD is running
    if lxc list >/dev/null 2>&1; then
        log "LXD is running and accessible"
    else
        warning "LXD may not be properly configured"
    fi
    
    # Check if UPF is installed
    if command -v upf >/dev/null 2>&1; then
        log "UPF is installed"
    else
        warning "UPF installation may have failed"
    fi
}

# Main installation
main() {
    display_banner
    
    # Prepare installation (download if needed)
    prepare_installation
    
    # Run installation steps
    check_prerequisites
    install_dependencies
    setup_directories
    copy_files
    setup_cli
    setup_network
    copy_sample_projects
    verify_installation
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ Installation complete!${NC}"
    echo ""
    
    if [[ "$IS_REMOTE_INSTALL" == true ]]; then
        echo "Installation method: Remote (downloaded from GitHub)"
    else
        echo "Installation method: Local repository"
    fi
    
    echo ""
    echo "Quick start:"
    echo "  1. Create a lxc-compose.yml file in your project"
    echo "  2. Add a .env file for environment variables (optional)"
    echo "  3. Run: lxc-compose up"
    echo ""
    echo "Sample projects available in: ~/lxc-samples/"
    echo "Try one:"
    echo "  cd ~/lxc-samples/django-celery-app"
    echo "  lxc-compose up"
    echo ""
    echo "Available commands:"
    echo "  lxc-compose up       - Create and start containers"
    echo "  lxc-compose down     - Stop containers"
    echo "  lxc-compose list     - List containers and their status"
    echo "  lxc-compose destroy  - Stop and remove containers"
    echo "  lxc-compose logs     - View container logs"
    echo "  lxc-compose test     - Run health tests"
    echo ""
    echo "Documentation: https://github.com/${GITHUB_REPO}"
}

# Handle being piped from curl/wget
if [ -t 0 ]; then
    # Running interactively
    main "$@"
else
    # Being piped - still run main
    main "$@"
fi