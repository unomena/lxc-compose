#!/bin/bash

#############################################################################
# LXC Compose Installation Script
# 
# Complete installation script that:
# 1. Sets up the host environment (packages, network, etc.)
# 2. Clones/updates the LXC Compose repository
# 3. Installs the lxc-compose command
# 4. Prepares the system for container orchestration
#
# This consolidates install.sh and setup-lxc-host.sh into one script
#
# Compatible with Ubuntu 22.04 and 24.04 LTS
# Usage: bash install.sh
#############################################################################

set -euo pipefail

# Configuration
REPO_URL="https://github.com/unomena/lxc-compose.git"
INSTALL_DIR="/srv/lxc-compose"

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
    echo "║                     Version 2.0                              ║"
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

# Update system
update_system() {
    info "Updating system packages..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    log "System updated"
}

# Install base packages
install_base_packages() {
    info "Installing base packages..."
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        wget \
        git \
        vim \
        htop \
        net-tools \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        jq \
        tree \
        zip \
        unzip \
        supervisor \
        nginx \
        ufw \
        fail2ban \
        unattended-upgrades
    
    log "Base packages installed"
}

# Install LXC/LXD
install_lxc() {
    info "Installing LXC and container tools..."
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        lxc \
        lxc-templates \
        lxc-utils \
        bridge-utils \
        dnsmasq-base \
        iptables \
        debootstrap \
        libvirt-clients \
        libvirt-daemon-system
    
    # Install LXD via snap if available (with timeout to prevent hanging)
    if command -v snap >/dev/null 2>&1; then
        if ! snap list 2>/dev/null | grep -q "^lxd "; then
            info "Installing LXD via snap (60s timeout)..."
            if timeout 60 snap install lxd --channel=5.21/stable; then
                log "LXD installed successfully"
            else
                warning "LXD installation timed out or failed (optional component)"
            fi
        else
            log "LXD already installed"
        fi
    fi
    
    log "Container tools installed"
}

# Configure network
configure_network() {
    info "Configuring LXC network bridge..."
    
    # Create directories
    mkdir -p /etc/lxc /etc/default
    
    # LXC default configuration
    cat > /etc/lxc/default.conf <<EOF
# Network configuration
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.hwaddr = 00:16:3e:xx:xx:xx

# AppArmor
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1

# Cgroup configuration
lxc.init.cmd = /sbin/init
lxc.mount.auto = proc:mixed sys:mixed cgroup:mixed
EOF
    
    # Configure LXC bridge
    cat > /etc/default/lxc-net <<EOF
USE_LXC_BRIDGE="true"
LXC_BRIDGE="lxcbr0"
LXC_ADDR="10.0.3.1"
LXC_NETMASK="255.255.255.0"
LXC_NETWORK="10.0.3.0/24"
LXC_DHCP_RANGE="10.0.3.200,10.0.3.254"
LXC_DHCP_MAX="50"
EOF
    
    # Enable and restart LXC networking
    if systemctl list-unit-files | grep -q lxc-net; then
        systemctl enable lxc-net
        systemctl restart lxc-net
    else
        # Create bridge manually
        ip link add name lxcbr0 type bridge 2>/dev/null || true
        ip addr add 10.0.3.1/24 dev lxcbr0 2>/dev/null || true
        ip link set lxcbr0 up 2>/dev/null || true
    fi
    
    log "Network configured"
}

# Install Python dependencies
install_python_deps() {
    info "Installing Python dependencies..."
    
    # Detect Python version for pip flags
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    if [[ $(echo "$PYTHON_VERSION >= 3.11" | bc -l) -eq 1 ]]; then
        PIP_FLAGS="--break-system-packages"
    else
        PIP_FLAGS=""
    fi
    
    # Install Python packages
    for package in click pyyaml jinja2 tabulate colorama requests; do
        pip3 install $PIP_FLAGS $package 2>/dev/null || \
        apt-get install -y python3-${package/pyyaml/yaml} 2>/dev/null || true
    done
    
    log "Python dependencies installed"
}

# Clone or update repository
setup_repository() {
    info "Setting up LXC Compose repository..."
    
    # Create /srv directory
    mkdir -p /srv
    
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        # Repository exists, update it
        info "Updating existing repository..."
        cd "$INSTALL_DIR"
        
        # Add to git safe directory
        git config --global --add safe.directory "$INSTALL_DIR"
        
        # Stash any local changes
        if git status --porcelain | grep -q .; then
            warning "Stashing local changes..."
            git stash push -m "Auto-stash before update $(date +%Y%m%d_%H%M%S)"
        fi
        
        # Pull latest
        git pull origin main || warning "Could not pull latest changes"
    else
        # Fresh installation
        if [[ -d "$INSTALL_DIR" ]]; then
            warning "Removing old non-git installation..."
            rm -rf "$INSTALL_DIR"
        fi
        
        info "Cloning repository..."
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
    
    log "Repository ready"
}

# Create directory structure
create_directories() {
    info "Creating directory structure..."
    
    mkdir -p /srv/{apps,shared,logs}
    mkdir -p /srv/shared/{database,redis,media,certificates}
    mkdir -p /srv/shared/database/{postgres,mysql}
    
    # Set ownership
    OWNER_USER=${SUDO_USER:-ubuntu}
    chown -R $OWNER_USER:$OWNER_USER /srv/
    
    log "Directory structure created"
}

# Install lxc-compose command
install_command() {
    info "Installing lxc-compose command..."
    
    # Make CLI executable
    chmod +x "$INSTALL_DIR/srv/lxc-compose/cli/lxc_compose.py"
    chmod +x "$INSTALL_DIR/wizard.sh"
    
    # Create symlink
    ln -sf "$INSTALL_DIR/srv/lxc-compose/cli/lxc_compose.py" /usr/local/bin/lxc-compose
    
    # Install doctor script if present
    if [[ -f "$INSTALL_DIR/srv/lxc-compose/cli/doctor.py" ]]; then
        chmod +x "$INSTALL_DIR/srv/lxc-compose/cli/doctor.py"
    fi
    
    log "Command installed"
}

# Configure firewall
configure_firewall() {
    info "Configuring firewall..."
    
    # Basic UFW rules
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Allow LXC bridge
    ufw allow in on lxcbr0
    ufw route allow in on lxcbr0
    ufw route allow out on lxcbr0
    
    log "Firewall configured"
}

# Configure SSH
configure_ssh() {
    info "Configuring SSH..."
    
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Apply secure settings
    cat >> /etc/ssh/sshd_config <<EOF

# LXC Compose Security Settings
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
X11Forwarding no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Compression delayed
ClientAliveInterval 120
ClientAliveCountMax 2
UsePAM yes
Protocol 2
EOF
    
    systemctl restart ssh
    log "SSH configured"
}

# Setup log rotation
setup_log_rotation() {
    info "Setting up log rotation..."
    
    cat > /etc/logrotate.d/lxc-compose <<EOF
/srv/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    sharedscripts
    postrotate
        systemctl reload supervisor 2>/dev/null || true
    endscript
}
EOF
    
    log "Log rotation configured"
}

# Run post-installation checks
post_install_checks() {
    info "Running post-installation checks..."
    
    # Check if lxc-compose command works
    if command -v lxc-compose &> /dev/null; then
        log "lxc-compose command available"
    else
        warning "lxc-compose command not found in PATH"
    fi
    
    # Check network bridge
    if ip link show lxcbr0 &> /dev/null; then
        log "Network bridge configured"
    else
        warning "Network bridge not found"
    fi
    
    # Check Python modules
    if python3 -c "import click, yaml" 2>/dev/null; then
        log "Python modules installed"
    else
        warning "Some Python modules missing"
    fi
}

# Main installation flow
main() {
    display_banner
    
    check_prerequisites
    update_system
    install_base_packages
    install_lxc
    configure_network
    install_python_deps
    setup_repository
    create_directories
    install_command
    configure_firewall
    configure_ssh
    setup_log_rotation
    post_install_checks
    
    echo ""
    echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN}     LXC Compose Installation Complete!${NC}"
    echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ${BOLD}lxc-compose wizard${NC} to start the setup wizard"
    echo "  2. Or use: ${BOLD}lxc-compose --help${NC} for CLI commands"
    echo ""
    echo "Quick start:"
    echo "  - Setup database: ${BOLD}lxc-compose wizard setup-db${NC}"
    echo "  - Setup app: ${BOLD}lxc-compose wizard setup-app${NC}"
    echo "  - Web UI: ${BOLD}lxc-compose wizard web${NC}"
    echo ""
    echo "Documentation: https://github.com/unomena/lxc-compose"
    echo ""
}

# Run main function
main "$@"