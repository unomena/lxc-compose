#!/bin/bash

#############################################################################
# Clean Update Script for LXC Compose
# 
# This script ensures clean updates without local modifications
# It resets the repository to a clean state before updating
#############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# Check if running with proper permissions
if [[ "$EUID" -ne 0 ]]; then
    error "Please run with sudo: sudo $0"
    exit 1
fi

echo "======================================"
echo "LXC Compose Clean Update"
echo "======================================"
echo

# Navigate to LXC Compose directory
cd /srv/lxc-compose

# Add repository to git safe directory (for sudo operations)
git config --global --add safe.directory /srv/lxc-compose

info "Current branch and status:"
git branch
git status --short

# Check for local modifications
if git status --porcelain | grep -q .; then
    warning "Found local modifications:"
    git status --short
    echo
    read -p "Reset all local changes and update? This will LOSE any local modifications! (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Update cancelled"
        exit 1
    fi
    
    info "Resetting local changes..."
    git reset --hard HEAD
    git clean -fd
    log "Local changes reset"
else
    log "No local modifications found"
fi

info "Fetching latest updates..."
git fetch origin main

# Check if updates are available
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [[ "$LOCAL" == "$REMOTE" ]]; then
    log "Already up to date"
else
    info "Updates available, pulling changes..."
    git pull origin main --ff-only
    log "Successfully updated"
    
    # Show recent commits
    echo
    info "Recent changes:"
    git log --oneline -5
fi

# Ensure correct ownership
OWNER_USER=${SUDO_USER:-ubuntu}
info "Setting correct ownership to $OWNER_USER..."
chown -R $OWNER_USER:$OWNER_USER /srv/lxc-compose

# Verify no local modifications after update
echo
if git status --porcelain | grep -q .; then
    error "WARNING: Still have local modifications after update!"
    git status --short
    warning "This should not happen. Please report this issue."
else
    log "Repository is clean"
fi

# Run doctor to verify system health
echo
info "Running system health check..."
if [[ -f /srv/lxc-compose/cli/doctor.py ]]; then
    python3 /srv/lxc-compose/cli/doctor.py || true
else
    /srv/lxc-compose/update.sh doctor || true
fi

echo
log "Clean update complete!"