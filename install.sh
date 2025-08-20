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

# Run comprehensive post-installation tests
run_installation_tests() {
    info "Running post-installation verification tests..."
    echo "  This will create test containers to ensure everything is working correctly."
    echo "  All test containers will be automatically removed after verification."
    
    local test_passed=0
    local test_failed=0
    
    # Create a test directory
    TEST_DIR="/tmp/lxc-compose-test-$$"
    mkdir -p "$TEST_DIR"
    
    # Test 1: Alpine container with basic features
    info "  Test 1/4: Alpine container with mounts and ports..."
    cat > "$TEST_DIR/test-alpine.yml" << 'EOF'
version: '1.0'
containers:
  test-alpine:
    template: alpine
    release: "3.19"
    exposed_ports: [8080]
    mounts:
      - /tmp:/host-tmp
    post_install:
      - name: "Test setup"
        command: |
          echo "Alpine test successful" > /host-tmp/alpine-test.txt
          echo "#!/bin/sh\necho 'Hello from Alpine'" > /tmp/test.sh
          chmod +x /tmp/test.sh
EOF
    
    if $BIN_PATH up -f "$TEST_DIR/test-alpine.yml" >/dev/null 2>&1; then
        sleep 2
        
        # Test mount
        if [ -f "/tmp/alpine-test.txt" ]; then
            log "    ✓ Mount test passed"
            rm -f /tmp/alpine-test.txt
            ((test_passed++))
        else
            warning "    ✗ Mount test failed"
            ((test_failed++))
        fi
        
        # Test container execution
        if lxc exec test-alpine -- /tmp/test.sh 2>/dev/null | grep -q "Hello from Alpine"; then
            log "    ✓ Container execution test passed"
            ((test_passed++))
        else
            warning "    ✗ Container execution test failed"
            ((test_failed++))
        fi
        
        # Clean up
        $BIN_PATH destroy -f "$TEST_DIR/test-alpine.yml" >/dev/null 2>&1
    else
        warning "    ✗ Alpine container creation failed"
        ((test_failed++))
    fi
    
    # Test 2: Ubuntu container with networking
    info "  Test 2/4: Ubuntu container with packages..."
    cat > "$TEST_DIR/test-ubuntu.yml" << 'EOF'
version: '1.0'
containers:
  test-ubuntu:
    template: ubuntu
    release: jammy
    exposed_ports: [80]
    packages:
      - curl
      - nginx
EOF
    
    if $BIN_PATH up -f "$TEST_DIR/test-ubuntu.yml" >/dev/null 2>&1; then
        sleep 3
        
        # Test package installation
        if lxc exec test-ubuntu -- which curl >/dev/null 2>&1; then
            log "    ✓ Package installation test passed"
            ((test_passed++))
        else
            warning "    ✗ Package installation test failed"
            ((test_failed++))
        fi
        
        # Test networking
        if lxc exec test-ubuntu -- curl -s -o /dev/null -w "%{http_code}" http://example.com 2>/dev/null | grep -q "200"; then
            log "    ✓ Network connectivity test passed"
            ((test_passed++))
        else
            warning "    ✗ Network connectivity test failed"
            ((test_failed++))
        fi
        
        # Test port forwarding
        if iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q "dpt:80.*test-ubuntu"; then
            log "    ✓ Port forwarding test passed"
            ((test_passed++))
        else
            warning "    ✗ Port forwarding test failed"
            ((test_failed++))
        fi
        
        # Clean up
        $BIN_PATH destroy -f "$TEST_DIR/test-ubuntu.yml" >/dev/null 2>&1
    else
        warning "    ✗ Ubuntu container creation failed"
        ((test_failed++))
    fi
    
    # Test 3: Multi-container with dependencies and hosts file
    info "  Test 3/4: Multi-container networking..."
    cat > "$TEST_DIR/test-multi.yml" << 'EOF'
version: '1.0'
containers:
  test-db:
    template: alpine
    release: "3.19"
    post_install:
      - name: "Create marker"
        command: echo "DB Ready" > /tmp/db-ready.txt
  test-app:
    template: alpine  
    release: "3.19"
    depends_on:
      - test-db
    post_install:
      - name: "Test connection"
        command: |
          # Test if we can resolve test-db hostname
          if ping -c 1 test-db >/dev/null 2>&1; then
            echo "success" > /tmp/connection-test.txt
          else
            echo "failed" > /tmp/connection-test.txt
          fi
EOF
    
    if $BIN_PATH up -f "$TEST_DIR/test-multi.yml" >/dev/null 2>&1; then
        sleep 3
        
        # Test both containers are running
        if lxc list --format=csv 2>/dev/null | grep -q "test-db.*RUNNING" && \
           lxc list --format=csv 2>/dev/null | grep -q "test-app.*RUNNING"; then
            log "    ✓ Multi-container creation test passed"
            ((test_passed++))
        else
            warning "    ✗ Multi-container creation test failed"
            ((test_failed++))
        fi
        
        # Test hosts file entries
        if grep -q "test-db" /srv/lxc-compose/etc/hosts 2>/dev/null && \
           grep -q "test-app" /srv/lxc-compose/etc/hosts 2>/dev/null; then
            log "    ✓ Hosts file test passed"
            ((test_passed++))
        else
            warning "    ✗ Hosts file test failed"
            ((test_failed++))
        fi
        
        # Test container connectivity
        result=$(lxc exec test-app -- cat /tmp/connection-test.txt 2>/dev/null || echo "failed")
        if [ "$result" = "success" ]; then
            log "    ✓ Container networking test passed"
            ((test_passed++))
        else
            warning "    ✗ Container networking test failed"
            ((test_failed++))
        fi
        
        # Clean up
        $BIN_PATH destroy -f "$TEST_DIR/test-multi.yml" >/dev/null 2>&1
    else
        warning "    ✗ Multi-container creation failed"
        ((test_failed++))
    fi
    
    # Test 4: List command functionality
    info "  Test 4/4: Command functionality..."
    
    # Test list command with no containers
    if $BIN_PATH list >/dev/null 2>&1; then
        log "    ✓ List command test passed"
        ((test_passed++))
    else
        warning "    ✗ List command test failed"
        ((test_failed++))
    fi
    
    # Clean up test directory
    rm -rf "$TEST_DIR"
    
    # Summary
    echo ""
    info "Test Summary:"
    log "  Passed: $test_passed tests"
    if [ $test_failed -gt 0 ]; then
        warning "  Failed: $test_failed tests"
        warning "  Some tests failed. You may need to troubleshoot specific features."
    else
        log "  All tests passed! LXC Compose is fully operational."
    fi
    
    # The test process will have downloaded and cached the images
    info "  Container images have been cached during testing for faster future use."
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
    run_installation_tests
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
