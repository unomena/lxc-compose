#!/bin/bash

#############################################################################
# LXC Compose Aliases Setup
# Sets up helpful aliases for LXC container management
#############################################################################

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }

# Remove old aliases if they exist
sed -i '/# LXC Compose Aliases/,/^$/d' ~/.bashrc 2>/dev/null || true
sed -i '/# LXC Aliases/,/^$/d' ~/.bashrc 2>/dev/null || true

# Add new aliases
cat >> ~/.bashrc <<'EOF'

# LXC Compose Aliases
alias lxcc-list='sudo lxc-ls --fancy'
alias lxcc-info='sudo lxc-info'
alias lxcc-attach='sudo lxc-attach -n'
alias lxcc-running='sudo lxc-ls --running'
alias lxcc-stop='sudo lxc-stop -n'
alias lxcc-start='sudo lxc-start -n'
alias lxcc-stop-all='for c in $(sudo lxc-ls --running); do sudo lxc-stop -n $c; done'
alias lxcc-start-all='for c in $(sudo lxc-ls); do sudo lxc-start -n $c; done'

# Navigation shortcuts
alias cdlxc='cd /srv/lxc-compose'
alias cdapps='cd /srv/apps'
alias cdlogs='cd /srv/logs'

# Monitoring
alias ports='sudo netstat -tulpn | grep LISTEN'
EOF

log "Aliases added to ~/.bashrc"
echo ""
warning "To use the aliases, run: source ~/.bashrc"
echo ""
echo "Available aliases:"
echo "  lxcc-list        - List all containers with details"
echo "  lxcc-info        - Show info about a container (e.g., lxcc-info -n datastore)"
echo "  lxcc-attach      - Enter a container (e.g., lxcc-attach datastore)"
echo "  lxcc-running     - List running containers"
echo "  lxcc-stop        - Stop a container (e.g., lxcc-stop datastore)"
echo "  lxcc-start       - Start a container (e.g., lxcc-start datastore)"
echo "  lxcc-stop-all    - Stop all running containers"
echo "  lxcc-start-all   - Start all containers"
echo "  cdlxc            - Go to /srv/lxc-compose"
echo "  cdapps           - Go to /srv/apps"
echo "  cdlogs           - Go to /srv/logs"
echo "  ports            - Show listening ports"