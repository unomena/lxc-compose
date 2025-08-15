#!/bin/bash

#############################################################################
# Expose LXC Container Services on Host
# Simple script to expose container services on the Multipass VM's IP
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

ACTION="${1:-setup}"  # setup or remove

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Exposing LXC Container Services                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Get all network interfaces and their IPs
info "Available network interfaces:"
ip -4 addr show | grep -E "^[0-9]+:|inet " | sed 's/^[0-9]*: /  /'

# Get the Multipass VM's IP (usually on eth0 or enp0s1)
VM_IP=$(ip -4 addr show | grep -v "127.0.0.1" | grep -v "10.0.3." | grep "inet " | head -1 | awk '{print $2}' | cut -d/ -f1)

if [[ -z "$VM_IP" ]]; then
    warning "Could not auto-detect VM IP. Please enter it manually:"
    read -p "Enter the Multipass VM IP (visible from your Mac): " VM_IP
fi

info "Using VM IP: $VM_IP"

if [[ "$ACTION" == "setup" ]]; then
    log "Setting up port forwarding..."
    
    # Enable IP forwarding
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-lxc-forward.conf
    
    # Setup iptables rules for each service
    # PostgreSQL
    iptables -t nat -A PREROUTING -d "$VM_IP" -p tcp --dport 5432 -j DNAT --to-destination 10.0.3.2:5432
    iptables -A FORWARD -p tcp -d 10.0.3.2 --dport 5432 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    
    # Redis
    iptables -t nat -A PREROUTING -d "$VM_IP" -p tcp --dport 6379 -j DNAT --to-destination 10.0.3.2:6379
    iptables -A FORWARD -p tcp -d 10.0.3.2 --dport 6379 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    
    # App-1 HTTP
    iptables -t nat -A PREROUTING -d "$VM_IP" -p tcp --dport 8080 -j DNAT --to-destination 10.0.3.11:80
    iptables -A FORWARD -p tcp -d 10.0.3.11 --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    
    # App-1 Django Dev Server
    iptables -t nat -A PREROUTING -d "$VM_IP" -p tcp --dport 8000 -j DNAT --to-destination 10.0.3.11:8000
    iptables -A FORWARD -p tcp -d 10.0.3.11 --dport 8000 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
    
    # Masquerading
    iptables -t nat -A POSTROUTING -s 10.0.3.0/24 ! -d 10.0.3.0/24 -j MASQUERADE
    
    log "Port forwarding rules applied!"
    
elif [[ "$ACTION" == "remove" ]]; then
    log "Removing port forwarding rules..."
    
    # Remove specific rules (ignore errors if they don't exist)
    iptables -t nat -D PREROUTING -d "$VM_IP" -p tcp --dport 5432 -j DNAT --to-destination 10.0.3.2:5432 2>/dev/null || true
    iptables -t nat -D PREROUTING -d "$VM_IP" -p tcp --dport 6379 -j DNAT --to-destination 10.0.3.2:6379 2>/dev/null || true
    iptables -t nat -D PREROUTING -d "$VM_IP" -p tcp --dport 8080 -j DNAT --to-destination 10.0.3.11:80 2>/dev/null || true
    iptables -t nat -D PREROUTING -d "$VM_IP" -p tcp --dport 8000 -j DNAT --to-destination 10.0.3.11:8000 2>/dev/null || true
    
    log "Port forwarding rules removed!"
    
else
    error "Unknown action: $ACTION. Use 'setup' or 'remove'"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Access Information                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "From your Mac, you can now access:"
echo ""
echo "  PostgreSQL:    psql -h $VM_IP -p 5432 -U appuser -d sampleapp"
echo "  Redis:         redis-cli -h $VM_IP -p 6379"
echo "  Web App:       http://$VM_IP:8080  (nginx)"
echo "  Django Dev:    http://$VM_IP:8000  (development server)"
echo ""
info "Current iptables NAT rules:"
iptables -t nat -L PREROUTING -n | grep -E "DNAT|Chain" || true
echo ""