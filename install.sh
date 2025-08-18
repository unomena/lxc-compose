#!/bin/bash

set -euo pipefail

# Configuration
INSTALL_DIR="/srv/lxc-compose"
BIN_PATH="/usr/local/bin/lxc-compose"

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

# Display banner
display_banner() {
    echo -e "${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              LXC Compose Installation Script                 ║"
    echo "║                  Simple & Lightweight                        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check if running with sudo
    if [[ "$EUID" -ne 0 ]]; then
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
            info "Initializing LXD..."
            lxd init --auto \
                --network-address=[::]  \
                --network-port=8443 \
                --storage-backend=dir
        fi
    elif command -v /snap/bin/lxd >/dev/null 2>&1; then
        if ! /snap/bin/lxd waitready --timeout=5 2>/dev/null; then
            info "Initializing LXD..."
            /snap/bin/lxd init --auto \
                --network-address=[::]  \
                --network-port=8443 \
                --storage-backend=dir
        fi
    fi
    
    log "Dependencies installed"
}

# Setup directories
setup_directories() {
    info "Setting up directories..."
    
    # Create required directories
    mkdir -p "$INSTALL_DIR/cli"
    mkdir -p "$INSTALL_DIR/configs"
    mkdir -p "/etc/lxc-compose"
    mkdir -p "/var/log/lxc-compose"
    
    log "Directories created"
}

# Copy files
copy_files() {
    info "Copying files..."
    
    # Get the directory of this script
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Copy CLI files
    cp -r "$SCRIPT_DIR/srv/lxc-compose/cli/"* "$INSTALL_DIR/cli/" 2>/dev/null || true
    
    # Copy config templates if they exist
    cp -r "$SCRIPT_DIR/srv/lxc-compose/configs/"* "$INSTALL_DIR/configs/" 2>/dev/null || true
    
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

# Pre-download Ubuntu image
download_base_image() {
    info "Pre-downloading Ubuntu LTS image for faster first container creation..."
    echo "  This may take 5-10 minutes depending on your connection speed."
    echo "  This is a one-time download that will make future containers launch quickly."
    
    # Determine Ubuntu LTS version to download
    . /etc/os-release
    if [[ "$VERSION_ID" == "24.04" ]]; then
        IMAGE="ubuntu:24.04"
    else
        IMAGE="ubuntu:22.04"
    fi
    
    # Download the image
    if command -v lxc >/dev/null 2>&1; then
        lxc image copy images:$IMAGE local: --alias $IMAGE 2>/dev/null || \
        lxc image copy ubuntu:22.04 local: --alias ubuntu:22.04 2>/dev/null || \
        info "  Image download failed, will download on first use"
    fi
    
    log "Base image ready"
}

# Create sample config
create_sample_config() {
    info "Creating sample configuration..."
    
    cat > "$INSTALL_DIR/lxc-compose.yml.example" << 'EOF'
# LXC Compose Configuration Example
# Place this file as lxc-compose.yml in your project directory

containers:
  - name: app-server
    image: ubuntu:22.04
    ip: 10.0.3.10
    ports:
      - "8080:80"    # host:container
      - "8443:443"
    mounts:
      - source: ./app
        target: /var/www/app
    services:
      - name: nginx
        command: apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'
        
  - name: database
    image: ubuntu:22.04
    ip: 10.0.3.11
    ports:
      - "5432:5432"
    mounts:
      - source: ./data
        target: /var/lib/postgresql
    services:
      - name: postgresql
        command: |
          apt-get update && apt-get install -y postgresql
          service postgresql start
EOF
    
    log "Sample config created at $INSTALL_DIR/lxc-compose.yml.example"
}

# Main installation
main() {
    display_banner
    
    check_prerequisites
    install_dependencies
    setup_directories
    copy_files
    setup_cli
    setup_network
    download_base_image
    create_sample_config
    
    echo
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo
    echo "Usage:"
    echo "  1. Create a lxc-compose.yml file in your project"
    echo "  2. Run: lxc-compose up"
    echo
    echo "Commands:"
    echo "  lxc-compose up       - Create and start containers"
    echo "  lxc-compose down     - Stop containers"
    echo "  lxc-compose start    - Start stopped containers"
    echo "  lxc-compose stop     - Stop running containers"
    echo "  lxc-compose list     - List containers and status"
    echo "  lxc-compose destroy  - Destroy containers"
    echo
    echo "Example config: $INSTALL_DIR/lxc-compose.yml.example"
}

# Run main function
main "$@"