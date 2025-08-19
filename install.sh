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
    echo "║              LXC Compose Installation Script                  ║"
    echo "║                   Simple & Lightweight                        ║"
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
    info "Pre-downloading container images for faster first container creation..."
    echo "  This may take a few minutes depending on your connection speed."
    echo "  This is a one-time download that will make future containers launch quickly."
    
    # Ensure lxc command is available
    if ! command -v lxc >/dev/null 2>&1; then
        warning "  LXC command not found, skipping image download"
        return 0
    fi
    
    info "  Checking for existing images..."
    
    # Check and download Ubuntu minimal
    if lxc image list local: --format=csv 2>/dev/null | grep -q "ubuntu-minimal:22.04\|ubuntu:22.04"; then
        log "  Ubuntu 22.04 already available"
    else
        info "  Downloading Ubuntu minimal 22.04 (~100MB)..."
        # Try downloading without hiding output for better feedback
        if lxc image copy ubuntu-minimal:22.04 local: --alias ubuntu-minimal:22.04 --quiet 2>/dev/null; then
            log "  Ubuntu minimal 22.04 downloaded successfully"
        elif lxc image copy images:ubuntu/22.04 local: --alias ubuntu:22.04 --quiet 2>/dev/null; then
            log "  Ubuntu 22.04 downloaded successfully"
        else
            warning "  Ubuntu download will happen on first container creation"
        fi
    fi
    
    # Check and download Alpine
    if lxc image list local: --format=csv 2>/dev/null | grep -q "alpine:3.19"; then
        log "  Alpine 3.19 already available"
    else
        info "  Downloading Alpine Linux 3.19 (~3MB)..."
        if lxc image copy images:alpine/3.19 local: --alias alpine:3.19 --quiet 2>/dev/null; then
            log "  Alpine 3.19 downloaded successfully"
        else
            warning "  Alpine download will happen on first container creation"
        fi
    fi
    
    log "Images ready"
}

# Create sample config
create_sample_config() {
    info "Creating sample configuration..."
    
    cat > "$INSTALL_DIR/lxc-compose.yml.example" << 'EOF'
# LXC Compose Configuration Example
# Place this file as lxc-compose.yml in your project directory

containers:
  # Example 1: Ubuntu minimal container (~100MB)
  - name: app-server
    image: ubuntu-minimal:22.04  # Options: ubuntu-minimal:22.04 (~100MB), ubuntu:22.04 (~400MB)
    ip: 10.0.3.10
    ports:
      - "8080:80"
      - "8443:443"
    mounts:
      - ./app:/var/www/app
    services:
      - name: nginx
        command: apt-get update && apt-get install -y nginx && nginx -g 'daemon off;'
  
  # Example 2: Alpine Linux container (ultra-minimal ~8MB)
  - name: web-alpine
    image: alpine:3.19  # Ultra-lightweight, uses apk instead of apt
    ip: 10.0.3.12
    ports:
      - "3000:3000"
    services:
      - name: node-app
        command: |
          apk add --no-cache nodejs npm
          cd /app && npm start
        
  # Example 3: Database with Ubuntu minimal
  - name: database
    image: ubuntu-minimal:22.04
    ip: 10.0.3.11
    ports:
      - "5432:5432"
    mounts:
      - ./data:/var/lib/postgresql
    services:
      - name: postgresql
        command: |
          apt-get update && apt-get install -y postgresql
          service postgresql start
EOF
    
    log "Sample config created at $INSTALL_DIR/lxc-compose.yml.example"
}

# Copy sample projects
copy_sample_projects() {
    info "Sample projects available..."
    echo "  - django-ubuntu-minimal: Django with PostgreSQL and Redis"
    echo "  - django-alpine: Ultra-lightweight Django"
    echo "  - django-production: Production-ready Django setup"
    echo "  - flask-minimal: Simple Flask app in Alpine"
    echo "  - image-comparison: Compare different base images"
    echo ""
    
    read -p "Would you like to copy sample projects to ~/lxc-samples? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
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
        cp -r "$SCRIPT_DIR/sample-configs" "$USER_HOME/lxc-samples"
        chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/lxc-samples"
        
        log "Sample projects copied to $USER_HOME/lxc-samples"
        echo ""
        echo "To use a sample:"
        echo "  cd ~/lxc-samples/flask-minimal"
        echo "  lxc-compose up"
    else
        info "Skipping sample projects (you can find them in the repo)"
    fi
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
    copy_sample_projects
    
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