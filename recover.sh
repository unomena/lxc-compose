#!/bin/bash

#############################################################################
# LXC Compose Recovery Script
# 
# This script helps recover from installation issues, particularly when
# snap installations hang or other services get stuck.
#
# Usage: ./recover.sh
#############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running with appropriate privileges
if [[ "$EUID" -ne 0 ]]; then
    error "This script must be run with sudo"
    echo "Usage: sudo ./recover.sh"
    exit 1
fi

echo "======================================"
echo "LXC Compose Installation Recovery Tool"
echo "======================================"
echo

# Step 1: Kill any hanging snap processes
log "Checking for hanging snap processes..."
if pgrep -f "snap install" > /dev/null; then
    warning "Found hanging snap install process"
    info "Killing snap install processes..."
    pkill -f "snap install" || true
    sleep 2
    log "Killed hanging snap processes"
else
    info "No hanging snap processes found"
fi

# Step 2: Restart snapd service
log "Restarting snapd service..."
systemctl stop snapd.socket snapd.service 2>/dev/null || true
sleep 2
systemctl start snapd.socket snapd.service 2>/dev/null || true
sleep 3

if systemctl is-active --quiet snapd; then
    log "snapd service restarted successfully"
else
    warning "snapd service may not be running properly"
fi

# Step 3: Clean up any snap locks
log "Cleaning up snap locks..."
rm -f /var/lib/snapd/state.lock 2>/dev/null || true
rm -f /var/lib/snapd/inhibit/* 2>/dev/null || true

# Step 4: Try to complete LXD installation if needed
log "Checking LXD installation status..."
if ! snap list 2>/dev/null | grep -q "^lxd "; then
    info "LXD is not installed via snap"
    read -p "Would you like to install LXD now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Installing LXD with 60-second timeout..."
        if timeout 60 snap install lxd --channel=5.21/stable; then
            log "LXD installed successfully"
        else
            warning "LXD installation failed or timed out"
            warning "You can try manually later with: sudo snap install lxd --channel=5.21/stable"
        fi
    fi
else
    log "LXD is already installed"
fi

# Step 5: Fix network bridge if needed
log "Checking network bridge configuration..."
if ! ip link show lxcbr0 &>/dev/null; then
    warning "LXC bridge (lxcbr0) not found"
    info "Creating LXC bridge..."
    ip link add name lxcbr0 type bridge 2>/dev/null || true
    ip addr add 10.0.3.1/24 dev lxcbr0 2>/dev/null || true
    ip link set lxcbr0 up 2>/dev/null || true
    log "Created LXC bridge"
else
    log "LXC bridge exists"
fi

# Step 6: Restart LXC networking
log "Restarting LXC networking..."
if systemctl list-unit-files | grep -q lxc-net; then
    systemctl restart lxc-net 2>/dev/null || true
    log "LXC networking restarted"
else
    info "lxc-net service not found (this is normal on some systems)"
fi

# Step 7: Check Python dependencies
log "Checking Python dependencies..."
MISSING_MODULES=""
for module in click yaml jinja2 tabulate colorama requests; do
    if ! python3 -c "import $module" 2>/dev/null; then
        MISSING_MODULES="$MISSING_MODULES $module"
    fi
done

if [ -n "$MISSING_MODULES" ]; then
    warning "Missing Python modules:$MISSING_MODULES"
    info "Installing missing modules..."
    
    # Detect Python version for pip flags
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    if [[ $(echo "$PYTHON_VERSION >= 3.11" | bc -l) -eq 1 ]]; then
        PIP_FLAGS="--break-system-packages"
    else
        PIP_FLAGS=""
    fi
    
    for module in $MISSING_MODULES; do
        pip3 install $PIP_FLAGS $module 2>/dev/null || apt-get install -y python3-${module//_/-} 2>/dev/null || true
    done
    log "Python dependencies installed"
else
    log "All Python dependencies are installed"
fi

# Step 8: Fix directory permissions
log "Fixing directory permissions..."
if [ -d /srv/lxc-compose ]; then
    OWNER_USER=${SUDO_USER:-ubuntu}
    chown -R $OWNER_USER:$OWNER_USER /srv/ 2>/dev/null || true
    log "Directory permissions fixed"
else
    warning "/srv/lxc-compose directory not found"
    info "You may need to run the installation script"
fi

# Step 9: Create lxc-compose command if missing
if ! command -v lxc-compose &>/dev/null; then
    if [ -f /srv/lxc-compose/cli/lxc_compose.py ]; then
        log "Creating lxc-compose command..."
        ln -sf /srv/lxc-compose/cli/lxc_compose.py /usr/local/bin/lxc-compose
        chmod +x /srv/lxc-compose/cli/lxc_compose.py
        log "lxc-compose command created"
    else
        warning "lxc-compose CLI script not found"
    fi
else
    log "lxc-compose command already exists"
fi

# Final status check
echo
echo "======================================"
echo "Recovery Process Complete"
echo "======================================"
echo

# Run doctor if available
if command -v lxc-compose &>/dev/null; then
    info "Running system diagnostics..."
    lxc-compose doctor || true
else
    warning "lxc-compose command not available"
    info "Please run the installation script:"
    info "  curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash"
fi

echo
log "Recovery complete. If issues persist, please check the documentation."