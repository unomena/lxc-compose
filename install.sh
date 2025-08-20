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
    
    log "Dependencies installed"
}

# Setup directories
setup_directories() {
    info "Setting up directories..."
    
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
    
    # Get the directory of this script
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Copy CLI files
    cp -r "$SCRIPT_DIR/srv/lxc-compose/cli/"* "$INSTALL_DIR/cli/" 2>/dev/null || true
    
    # Copy docs
    cp -r "$SCRIPT_DIR/docs/"* "$INSTALL_DIR/docs/" 2>/dev/null || true
    
    # Copy samples
    cp -r "$SCRIPT_DIR/samples/"* "$INSTALL_DIR/samples/" 2>/dev/null || true
    
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

cache_container_images() {
    info "Caching container images for faster first use..."
    echo "  This will download Alpine and Ubuntu images to speed up future container creation."

    local success=true

    # Test 1: Create vanilla Alpine container
    info "  Downloading Alpine image..."
    if lxc launch images:alpine/3.19 test-alpine-cache >/dev/null 2>&1; then
        sleep 2
        if lxc list --format=csv -c n 2>/dev/null | grep -q "^test-alpine-cache$"; then
            log "    ✓ Alpine image cached"
        else
            warning "    ✗ Alpine container creation failed"
            success=false
        fi
        lxc delete test-alpine-cache --force >/dev/null 2>&1
    else
        warning "    ✗ Failed to download Alpine image"
        success=false
    fi

    # Test 2: Create vanilla Ubuntu minimal container
    info "  Downloading Ubuntu minimal image..."
    if lxc launch ubuntu-minimal:lts test-ubuntu-minimal-cache >/dev/null 2>&1; then
        sleep 2
        if lxc list --format=csv -c n 2>/dev/null | grep -q "^test-ubuntu-minimal-cache$"; then
            log "    ✓ Ubuntu minimal image cached"
        else
            warning "    ✗ Ubuntu minimal container creation failed"
            success=false
        fi
        lxc delete test-ubuntu-minimal-cache --force >/dev/null 2>&1
    else
        warning "    ✗ Failed to download Ubuntu minimal image"
        success=false
    fi

    # Test 3: Create vanilla Ubuntu LTS container
    info "  Downloading Ubuntu LTS image..."
    if lxc launch ubuntu:lts test-ubuntu-lts-cache >/dev/null 2>&1; then
        sleep 2
        if lxc list --format=csv -c n 2>/dev/null | grep -q "^test-ubuntu-lts-cache$"; then
            log "    ✓ Ubuntu LTS image cached"
        else
            warning "    ✗ Ubuntu LTS container creation failed"
            success=false
        fi
        lxc delete test-ubuntu-lts-cache --force >/dev/null 2>&1
    else
        warning "    ✗ Failed to download Ubuntu LTS image"
        success=false
    fi

    # Test basic lxc-compose command
    info "  Testing lxc-compose command..."
    if $BIN_PATH list >/dev/null 2>&1; then
        log "    ✓ lxc-compose command works"
    else
        warning "    ✗ lxc-compose command failed"
        success=false
    fi

    # Summary
    echo ""
    if [ "$success" = true ]; then
        log "  ✓ Installation successful! Images cached for faster container creation."
    else
        warning "  ⚠ Some components failed, but lxc-compose is installed."
        warning "  You may need to manually download container images on first use."
    fi
}

# Copy sample projects
copy_sample_projects() {
    info "Sample projects available..."
    echo "  - django-minimal: Django + PostgreSQL in Alpine (150MB)"
    echo "  - flask-app: Flask with Redis cache"
    echo "  - nodejs-app: Express.js with MongoDB"
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
    cp -r "$SCRIPT_DIR/samples" "$USER_HOME/lxc-samples"
    chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/lxc-samples"
    
    log "Sample projects copied to $USER_HOME/lxc-samples"
    echo ""
    echo "To use a sample:"
    echo "  cd ~/lxc-samples/django-minimal"
    echo "  lxc-compose up"
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
    cache_container_images
    copy_sample_projects
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ Installation complete!${NC}"
    echo ""
    echo "Quick start:"
    echo "  1. Create a lxc-compose.yml file in your project"
    echo "  2. Add a .env file for environment variables (optional)"
    echo "  3. Run: lxc-compose up"
    echo ""
    echo "Sample projects available in: ~/lxc-samples/"
    echo "Try one:"
    echo "  cd ~/lxc-samples/django-minimal"
    echo "  lxc-compose up"
    echo ""
    echo "Available commands:"
    echo "  lxc-compose up       - Create and start containers"
    echo "  lxc-compose down     - Stop containers"
    echo "  lxc-compose list     - List containers and their status"
    echo "  lxc-compose destroy  - Stop and remove containers"
    echo ""
    echo "Documentation: https://github.com/unomena/lxc-compose"
}

# Run main function
main "$@"
