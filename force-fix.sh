#!/bin/bash

#############################################################################
# Force Fix Script - Ensures all updates are applied
#############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              LXC Compose Force Fix Script                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running with proper permissions
if [[ "$EUID" -ne 0 ]]; then
    error "Please run with sudo: sudo bash $0"
    exit 1
fi

log "Forcing complete update of LXC Compose..."

# Step 1: Add safe directory for git
info "Configuring git safe directory..."
git config --global --add safe.directory /srv/lxc-compose

# Step 2: Go to the directory
cd /srv/lxc-compose

# Step 3: Reset any local changes
warning "Resetting any local changes..."
git reset --hard HEAD
git clean -fd

# Step 4: Fetch and pull latest
log "Fetching latest version from GitHub..."
git fetch origin main
git reset --hard origin/main

# Step 5: Make scripts executable
log "Making all scripts executable..."
chmod +x *.sh 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x srv/lxc-compose/cli/*.py 2>/dev/null || true

# Step 6: Reinstall the CLI wrapper
log "Reinstalling lxc-compose command..."
cat > /usr/local/bin/lxc-compose <<'EOF'
#!/bin/bash
# LXC Compose CLI wrapper
if [[ -f "/srv/lxc-compose/srv/lxc-compose/cli/lxc_compose.py" ]]; then
    exec python3 /srv/lxc-compose/srv/lxc-compose/cli/lxc_compose.py "$@"
else
    echo "Error: lxc_compose.py not found"
    exit 1
fi
EOF
chmod +x /usr/local/bin/lxc-compose

# Step 7: Show version info
echo ""
log "Update complete! Current version:"
git log --oneline -1

echo ""
info "Latest changes:"
git log --oneline -5

echo ""
log "Force fix complete!"
info "You can now run: lxc-compose wizard"
echo ""