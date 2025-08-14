#!/bin/bash

#############################################################################
# LXC Compose Update/Doctor Script
# Updates LXC Compose to the latest version and checks system health
#############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Functions
log() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
check() { echo -e "${CYAN}[?]${NC} $1"; }

# Check if running with proper permissions
if [[ "$EUID" -ne 0 ]] && [[ "$USER" != "root" ]]; then
    error "Please run with sudo: sudo $0"
    exit 1
fi

# Display header
display_header() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              LXC Compose Update & Doctor                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# Check system health
run_doctor() {
    info "Running system health checks..."
    echo ""
    
    local issues=0
    
    # Check if LXC Compose is installed
    check "Checking LXC Compose installation..."
    if [[ -d "/srv/lxc-compose" ]]; then
        log "LXC Compose directory exists"
    else
        error "LXC Compose not found at /srv/lxc-compose"
        ((issues++))
    fi
    
    # Check if it's a git repository
    check "Checking git repository..."
    if [[ -d "/srv/lxc-compose/.git" ]]; then
        log "Git repository found"
        cd /srv/lxc-compose
        
        # Add repository to safe.directory for git (when running with sudo)
        git config --global --add safe.directory /srv/lxc-compose 2>/dev/null || true
        
        # Check git status
        if git status --porcelain | grep -q .; then
            warning "Repository has uncommitted changes"
            git status --short
        else
            log "Repository is clean"
        fi
        
        # Check current branch
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        if [[ "$CURRENT_BRANCH" == "main" ]]; then
            log "On main branch"
        else
            warning "On branch: $CURRENT_BRANCH (not main)"
        fi
        
        # Check if up to date
        git fetch origin main --quiet
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/main)
        
        if [[ "$LOCAL" == "$REMOTE" ]]; then
            log "Repository is up to date"
        else
            warning "Updates available"
            ((issues++))
        fi
    else
        error "Not a git repository - cannot update"
        ((issues++))
    fi
    
    # Check LXC installation
    check "Checking LXC installation..."
    if command -v lxc >/dev/null 2>&1; then
        log "LXC is installed"
        
        # Check LXC service
        if systemctl is-active --quiet lxc-net; then
            log "LXC network service is running"
        else
            warning "LXC network service is not running"
            ((issues++))
        fi
    else
        error "LXC is not installed"
        ((issues++))
    fi
    
    # Check network bridge
    check "Checking network bridge..."
    if ip link show lxcbr0 >/dev/null 2>&1; then
        log "LXC bridge (lxcbr0) exists"
        IP_ADDR=$(ip -4 addr show lxcbr0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        info "Bridge IP: $IP_ADDR"
    else
        error "LXC bridge (lxcbr0) not found"
        ((issues++))
    fi
    
    # Check running containers
    check "Checking containers..."
    if command -v lxc >/dev/null 2>&1; then
        RUNNING_COUNT=$(sudo lxc-ls --running | wc -w)
        TOTAL_COUNT=$(sudo lxc-ls | wc -w)
        info "Containers: $RUNNING_COUNT running, $TOTAL_COUNT total"
        
        if [[ "$TOTAL_COUNT" -gt 0 ]]; then
            echo ""
            sudo lxc-ls --fancy
        fi
    fi
    
    # Check directory structure
    check "Checking directory structure..."
    local dirs=("/srv/apps" "/srv/shared" "/srv/logs")
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log "Directory exists: $dir"
        else
            warning "Directory missing: $dir"
            ((issues++))
        fi
    done
    
    # Check scripts
    check "Checking scripts..."
    local scripts=("/srv/lxc-compose/wizard.sh" "/srv/lxc-compose/setup-lxc-host.sh")
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]] && [[ -x "$script" ]]; then
            log "Script OK: $(basename $script)"
        else
            warning "Script missing or not executable: $script"
            ((issues++))
        fi
    done
    
    echo ""
    if [[ "$issues" -eq 0 ]]; then
        log "System health check passed - no issues found!"
    else
        warning "System health check found $issues issue(s)"
        
        # Check if updates are available and show how to update
        if [[ -d "/srv/lxc-compose/.git" ]]; then
            cd /srv/lxc-compose
            # Add repository to safe.directory for git (when running with sudo)
            git config --global --add safe.directory /srv/lxc-compose 2>/dev/null || true
            git fetch origin main --quiet 2>/dev/null || true
            LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "")
            REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "")
            
            if [[ -n "$LOCAL" ]] && [[ -n "$REMOTE" ]] && [[ "$LOCAL" != "$REMOTE" ]]; then
                echo ""
                info "To update LXC Compose to the latest version, run:"
                echo "  sudo lxc-compose update"
                echo "  or"
                echo "  cd /srv/lxc-compose && sudo git pull origin main"
            fi
        fi
    fi
    
    return $issues
}

# Update LXC Compose
run_update() {
    info "Updating LXC Compose..."
    echo ""
    
    if [[ ! -d "/srv/lxc-compose/.git" ]]; then
        error "Cannot update - not a git repository"
        error "Please reinstall using: curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash"
        return 1
    fi
    
    cd /srv/lxc-compose
    
    # Add repository to safe.directory for git (when running with sudo)
    git config --global --add safe.directory /srv/lxc-compose 2>/dev/null || true
    
    # Stash any local changes
    if git status --porcelain | grep -q .; then
        warning "Stashing local changes..."
        git stash push -m "Auto-stash before update $(date +%Y%m%d_%H%M%S)"
    fi
    
    # Force pull latest changes (reset to match remote)
    log "Pulling latest changes from GitHub..."
    git fetch origin main
    
    # Reset to match remote exactly
    if git reset --hard origin/main; then
        log "Successfully updated to latest version"
        
        # Show what changed
        echo ""
        info "Recent changes:"
        git log --oneline -5
        
        # Make sure scripts are executable
        chmod +x *.sh 2>/dev/null || true
        chmod +x scripts/*.sh 2>/dev/null || true
        chmod +x cli/*.py 2>/dev/null || true
        
        # Check if there were stashed changes
        if git stash list | grep -q "Auto-stash before update"; then
            echo ""
            warning "You have stashed local changes. To restore them:"
            info "cd /srv/lxc-compose && git stash pop"
        fi
        
        return 0
    else
        error "Failed to update - check your internet connection"
        return 1
    fi
}

# Fix common issues
run_fix() {
    info "Attempting to fix common issues..."
    echo ""
    
    # Fix permissions
    check "Fixing permissions..."
    OWNER_USER=${SUDO_USER:-ubuntu}
    chown -R $OWNER_USER:$OWNER_USER /srv/lxc-compose 2>/dev/null || true
    chmod +x /srv/lxc-compose/*.sh 2>/dev/null || true
    chmod +x /srv/lxc-compose/scripts/*.sh 2>/dev/null || true
    log "Permissions fixed"
    
    # Create missing directories
    check "Creating missing directories..."
    mkdir -p /srv/{apps,shared,logs} 2>/dev/null || true
    mkdir -p /srv/shared/{database,media,certificates} 2>/dev/null || true
    mkdir -p /srv/shared/database/{postgres,redis} 2>/dev/null || true
    log "Directories created"
    
    # Fix network if needed
    if ! ip link show lxcbr0 >/dev/null 2>&1; then
        check "Attempting to fix LXC network..."
        systemctl restart lxc-net 2>/dev/null || true
        if ip link show lxcbr0 >/dev/null 2>&1; then
            log "Network bridge fixed"
        else
            warning "Could not fix network bridge - may need manual intervention"
        fi
    fi
    
    log "Fix attempt completed"
}

# Main function
main() {
    display_header
    
    local action="${1:-doctor}"
    
    case "$action" in
        update)
            run_update
            echo ""
            info "Running post-update health check..."
            run_doctor
            ;;
        doctor)
            run_doctor
            echo ""
            
            # Ask if user wants to update if updates are available
            if [[ -d "/srv/lxc-compose/.git" ]]; then
                cd /srv/lxc-compose
                # Add repository to safe.directory for git (when running with sudo)
                git config --global --add safe.directory /srv/lxc-compose 2>/dev/null || true
                git fetch origin main --quiet
                LOCAL=$(git rev-parse HEAD)
                REMOTE=$(git rev-parse origin/main)
                
                if [[ "$LOCAL" != "$REMOTE" ]]; then
                    echo ""
                    read -p "$(echo -e "${CYAN}[?]${NC} Updates are available. Would you like to update now? [Y/n]: ")" -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                        echo ""
                        run_update
                    fi
                fi
            fi
            ;;
        fix)
            run_fix
            echo ""
            run_doctor
            ;;
        *)
            error "Unknown action: $action"
            info "Usage: $0 [doctor|update|fix]"
            info "  doctor - Check system health (default)"
            info "  update - Update to latest version"
            info "  fix    - Attempt to fix common issues"
            exit 1
            ;;
    esac
    
    echo ""
    log "Done!"
}

# Run main function
main "$@"