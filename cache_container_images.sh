#!/bin/bash

info "Caching container images for faster first use..."
echo "  This will download Alpine and Ubuntu images to speed up future container creation."

local success=true

# Test 1: Create vanilla Alpine container
info "  Downloading Alpine image..."
if lxc launch images:alpine/3.19 test-alpine-cache >/dev/null 2>&1; then
    sleep 2
    if lxc list --format=csv -c n 2>/dev/null | grep -q "^test-alpine-cache$"; then
        log "    ✓ Alpine image cached"
        lxc delete test-alpine-cache --force >/dev/null 2>&1
    else
        warning "    ✗ Alpine container creation failed"
        success=false
    fi
else
    warning "    ✗ Failed to download Alpine image"
    success=false
fi

# Test 2: Create vanilla Ubuntu minimal container
info "  Downloading Ubuntu minimal image..."
if lxc launch images:ubuntu-minimal/jammy test-ubuntu-cache >/dev/null 2>&1; then
    sleep 2
    if lxc list --format=csv -c n 2>/dev/null | grep -q "^test-ubuntu-cache$"; then
        log "    ✓ Ubuntu minimal image cached"
        lxc delete test-ubuntu-cache --force >/dev/null 2>&1
    else
        warning "    ✗ Ubuntu minimal container creation failed"
        success=false
    fi
else
    warning "    ✗ Failed to download Ubuntu minimal image"
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