#!/bin/bash

#############################################################################
# Setup Port Forwarding for LXC Containers
# This script configures iptables to forward ports from the host to containers
#############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1" >&2; exit 1; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }

# Check if running with sudo
if [[ "$EUID" -ne 0 ]]; then
    error "This script must be run with sudo"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Setting up Port Forwarding for LXC Containers        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Get the main network interface (the one with default route)
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [[ -z "$MAIN_INTERFACE" ]]; then
    error "Could not determine main network interface"
fi

# Get the host IP on the main interface
HOST_IP=$(ip -4 addr show "$MAIN_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
if [[ -z "$HOST_IP" ]]; then
    error "Could not determine host IP address"
fi

info "Host IP: $HOST_IP on interface $MAIN_INTERFACE"

# Enable IP forwarding
log "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Function to add port forwarding rule
add_port_forward() {
    local host_port=$1
    local container_ip=$2
    local container_port=$3
    local protocol=${4:-tcp}
    local comment=$5
    
    # Remove existing rule if it exists
    iptables -t nat -D PREROUTING -i "$MAIN_INTERFACE" -p "$protocol" --dport "$host_port" -j DNAT --to-destination "${container_ip}:${container_port}" 2>/dev/null || true
    iptables -D FORWARD -p "$protocol" -d "$container_ip" --dport "$container_port" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
    
    # Add new rules
    iptables -t nat -A PREROUTING -i "$MAIN_INTERFACE" -p "$protocol" --dport "$host_port" -j DNAT --to-destination "${container_ip}:${container_port}" -m comment --comment "$comment"
    iptables -A FORWARD -p "$protocol" -d "$container_ip" --dport "$container_port" -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT -m comment --comment "$comment"
    
    log "Forwarding $HOST_IP:$host_port -> $container_ip:$container_port ($protocol) # $comment"
}

# Setup masquerading for outbound traffic
log "Setting up masquerading..."
iptables -t nat -D POSTROUTING -o "$MAIN_INTERFACE" -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -o "$MAIN_INTERFACE" -j MASQUERADE

# Port forwarding configuration
log "Setting up port forwarding rules..."

# Datastore services
add_port_forward 5432 10.0.3.2 5432 tcp "PostgreSQL on datastore"
add_port_forward 6379 10.0.3.2 6379 tcp "Redis on datastore"

# App-1 services
add_port_forward 8080 10.0.3.11 80 tcp "Nginx on app-1"
add_port_forward 8000 10.0.3.11 8000 tcp "Django dev server on app-1"

# Additional app containers (if needed)
# add_port_forward 8081 10.0.3.12 80 tcp "Nginx on app-2"
# add_port_forward 8001 10.0.3.12 8000 tcp "Django dev server on app-2"

# Save iptables rules
log "Saving iptables rules..."
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save
elif command -v iptables-save >/dev/null 2>&1; then
    iptables-save > /etc/iptables/rules.v4
fi

# Create systemd service to restore rules on boot
log "Creating systemd service for persistence..."
cat > /etc/systemd/system/lxc-port-forward.service <<EOF
[Unit]
Description=LXC Port Forwarding Rules
After=network.target lxc-net.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sleep 5 && /srv/lxc-compose/scripts/setup-port-forwarding.sh'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable lxc-port-forward.service

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Port Forwarding Configuration Complete! ✓          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
info "Access your services from your Mac at:"
echo ""
echo "  PostgreSQL:    $HOST_IP:5432"
echo "  Redis:         $HOST_IP:6379"
echo "  App-1 (nginx): http://$HOST_IP:8080"
echo "  App-1 (dev):   http://$HOST_IP:8000"
echo ""
info "To check current port forwarding rules:"
echo "  sudo iptables -t nat -L PREROUTING -n -v --line-numbers"
echo ""
info "To remove a specific rule:"
echo "  sudo iptables -t nat -D PREROUTING <line-number>"
echo ""