#!/bin/bash

#############################################################################
# LXC Host Machine Setup Script - Production Version
# Compatible with Ubuntu 22.04 and 24.04 LTS
# Run as ubuntu user with passwordless sudo
# Usage: bash setup-lxc-host.sh
#############################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if running with proper permissions
# Accept either ubuntu user or root (when run via sudo)
if [[ "$USER" != "ubuntu" ]] && [[ "$EUID" -ne 0 ]]; then
    error "This script should be run as the 'ubuntu' user or with sudo"
    exit 1
fi

# Get the actual user (even when running with sudo)
ACTUAL_USER=${SUDO_USER:-$USER}
if [[ "$ACTUAL_USER" != "ubuntu" ]] && [[ "$ACTUAL_USER" != "root" ]]; then
    warning "Script is designed for the 'ubuntu' user, running as '$ACTUAL_USER'"
fi

log "Starting LXC host machine setup..."
info "Detected OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
info "Architecture: $(uname -m)"

#############################################################################
# 1. SYSTEM UPDATE AND BASIC PACKAGES
#############################################################################

log "Updating system packages..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

log "Installing essential packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
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
    python3-pip \
    python3-venv \
    python3-dev \
    jq \
    tree \
    ncdu \
    iotop \
    sysstat \
    mtr-tiny \
    unzip \
    rsync \
    dnsutils \
    iputils-ping \
    bc

#############################################################################
# 2. SECURITY SETUP
#############################################################################

log "Configuring UFW firewall..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ufw

# Reset UFW to defaults
sudo ufw --force reset

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp comment 'SSH'

# Allow HTTP and HTTPS for applications
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Enable UFW
sudo ufw --force enable

log "Configuring SSH hardening..."
# Backup original sshd_config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)

# SSH Hardening
OWNER_USER=${SUDO_USER:-ubuntu}
sudo mkdir -p /etc/ssh/sshd_config.d/
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null <<EOF
# SSH Hardening Configuration
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10
AllowUsers $OWNER_USER
Protocol 2
EOF

# Restart SSH service (Ubuntu 22.04+ uses 'ssh' not 'sshd')
log "Restarting SSH service..."
sudo systemctl restart ssh || sudo systemctl restart sshd || warning "Could not restart SSH service"

log "Installing and configuring fail2ban..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban

# Configure fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

#############################################################################
# 3. LXC AND CONTAINER TOOLS
#############################################################################

log "Installing LXC and related tools..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    lxc \
    lxc-templates \
    lxc-utils \
    bridge-utils \
    dnsmasq-base \
    iptables \
    debootstrap \
    libvirt-clients \
    libvirt-daemon-system

# Install LXD via snap if available (optional)
if command -v snap >/dev/null 2>&1; then
    log "Installing LXD via snap (optional)..."
    sudo snap install lxd || warning "Could not install LXD - this is optional"
fi

#############################################################################
# 4. NETWORK CONFIGURATION FOR LXC
#############################################################################

log "Configuring LXC network bridge..."

# Create directories
sudo mkdir -p /etc/lxc
sudo mkdir -p /etc/default

# LXC default configuration
sudo tee /etc/lxc/default.conf > /dev/null <<EOF
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
sudo tee /etc/default/lxc-net > /dev/null <<EOF
USE_LXC_BRIDGE="true"
LXC_BRIDGE="lxcbr0"
LXC_ADDR="10.0.3.1"
LXC_NETMASK="255.255.255.0"
LXC_NETWORK="10.0.3.0/24"
LXC_DHCP_RANGE="10.0.3.200,10.0.3.254"
LXC_DHCP_MAX="50"
LXC_DHCP_CONFILE=""
LXC_DOMAIN=""
EOF

# Enable and restart LXC networking
if systemctl list-unit-files | grep -q lxc-net; then
    sudo systemctl enable lxc-net
    sudo systemctl restart lxc-net
else
    warning "lxc-net service not found, creating bridge manually..."
    sudo ip link add name lxcbr0 type bridge 2>/dev/null || true
    sudo ip addr add 10.0.3.1/24 dev lxcbr0 2>/dev/null || true
    sudo ip link set lxcbr0 up 2>/dev/null || true
fi

# Configure firewall for LXC bridge
log "Configuring firewall rules for LXC bridge..."
sudo ufw allow in on lxcbr0 || true
sudo ufw route allow in on lxcbr0 || true
sudo ufw route allow out on lxcbr0 || true

#############################################################################
# 5. PYTHON ENVIRONMENT FOR CLI TOOLS
#############################################################################

log "Setting up Python environment for LXC Compose CLI..."

# Check network connectivity first
log "Checking network connectivity..."
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    warning "No internet connectivity detected. Some packages may not install."
    warning "You may need to configure DNS or proxy settings."
fi

# Install Python packages - handle both old and new pip versions
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)

if [[ $(echo "$PYTHON_VERSION >= 3.11" | bc -l) -eq 1 ]]; then
    # Ubuntu 24.04 with Python 3.11+ requires --break-system-packages
    PIP_FLAGS="--break-system-packages"
else
    PIP_FLAGS=""
fi

# Don't try to upgrade pip, just install packages
log "Installing Python packages..."

# Try to install packages, but continue if some fail
for package in click pyyaml jinja2 tabulate colorama requests; do
    if sudo pip3 install $PIP_FLAGS $package 2>/dev/null; then
        info "Installed $package"
    else
        # Try with apt if pip fails
        case $package in
            click) sudo apt-get install -y python3-click 2>/dev/null || true ;;
            pyyaml) sudo apt-get install -y python3-yaml 2>/dev/null || true ;;
            jinja2) sudo apt-get install -y python3-jinja2 2>/dev/null || true ;;
            tabulate) sudo apt-get install -y python3-tabulate 2>/dev/null || true ;;
            colorama) sudo apt-get install -y python3-colorama 2>/dev/null || true ;;
            requests) sudo apt-get install -y python3-requests 2>/dev/null || true ;;
        esac
    fi
done

# Check if essential packages are installed
if ! python3 -c "import click" 2>/dev/null; then
    warning "Python click module not installed - CLI may not work properly"
fi
if ! python3 -c "import yaml" 2>/dev/null; then
    warning "Python yaml module not installed - CLI may not work properly"
fi

#############################################################################
# 6. DIRECTORY STRUCTURE
#############################################################################

log "Creating directory structure..."

sudo mkdir -p /srv/{lxc-compose,apps,shared,logs}
sudo mkdir -p /srv/lxc-compose/{cli,templates,configs,scripts,lib}
sudo mkdir -p /srv/lxc-compose/templates/{base,app,database,monitor}
sudo mkdir -p /srv/shared/{database,media,certificates}
sudo mkdir -p /srv/shared/database/{postgres,redis}

# Set ownership to the actual user
OWNER_USER=${SUDO_USER:-ubuntu}
sudo chown -R $OWNER_USER:$OWNER_USER /srv/

#############################################################################
# 7. LOG ROTATION CONFIGURATION
#############################################################################

log "Configuring centralized log rotation..."

OWNER_USER=${SUDO_USER:-ubuntu}
sudo tee /etc/logrotate.d/lxc-apps > /dev/null <<'EOF'
/srv/logs/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 ubuntu ubuntu
    sharedscripts
    postrotate
        for container in $(lxc-ls --running 2>/dev/null); do
            lxc-attach -n $container -- supervisorctl reload 2>/dev/null || true
        done
    endscript
}
EOF

# Update the ownership in the logrotate file
sudo sed -i "s/create 0644 ubuntu ubuntu/create 0644 $OWNER_USER $OWNER_USER/" /etc/logrotate.d/lxc-apps

#############################################################################
# 8. MONITORING TOOLS
#############################################################################

log "Installing monitoring tools..."

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    htop \
    iftop \
    nethogs \
    glances || warning "Some monitoring tools may already be installed"

# Try to install optional monitoring tools
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y netdata || warning "Netdata not available"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y prometheus-node-exporter || warning "Node exporter not available"

# Disable netdata by default if installed
if systemctl list-units --all | grep -q "netdata"; then
    sudo systemctl stop netdata
    sudo systemctl disable netdata
    info "Netdata installed but disabled - enable with: sudo systemctl enable --now netdata"
fi

# Enable node exporter if installed
if systemctl list-units --all | grep -q "prometheus-node-exporter"; then
    sudo systemctl enable prometheus-node-exporter
    sudo systemctl start prometheus-node-exporter
    info "Prometheus node exporter running on port 9100"
fi

#############################################################################
# 9. SYSCTL OPTIMIZATIONS
#############################################################################

log "Applying sysctl optimizations..."

# Load kernel modules
sudo modprobe overlay || true
sudo modprobe br_netfilter || true

# Make modules persistent
echo "overlay" | sudo tee /etc/modules-load.d/lxc.conf
echo "br_netfilter" | sudo tee -a /etc/modules-load.d/lxc.conf

# Sysctl settings
sudo tee /etc/sysctl.d/99-lxc-host.conf > /dev/null <<'EOF'
# LXC Host Optimizations

# Network
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

# Performance
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 65535
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# Connection tracking
net.netfilter.nf_conntrack_max = 524288
net.nf_conntrack_max = 524288

# File handles
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 8192

# Process limits
kernel.pid_max = 4194304

# Memory
vm.max_map_count = 262144
vm.swappiness = 10
vm.overcommit_memory = 1

# Security
kernel.unprivileged_userns_clone = 1
kernel.keys.root_maxkeys = 1000000
EOF

sudo sysctl --system || warning "Some sysctl settings may not apply"

#############################################################################
# 10. HELPER SCRIPTS
#############################################################################

log "Creating helper scripts..."

# Container creation script
cat > /srv/lxc-compose/scripts/create-container.sh <<'SCRIPT'
#!/bin/bash
set -e

CONTAINER_NAME=$1
CONTAINER_IP=$2
CONTAINER_TYPE=${3:-app}

if [[ -z "$CONTAINER_NAME" || -z "$CONTAINER_IP" ]]; then
    echo "Usage: $0 <container_name> <container_ip> [type]"
    echo "  Types: app (default), database, monitor"
    echo "  Example: $0 app-1 10.0.3.11 app"
    exit 1
fi

echo "Creating $CONTAINER_TYPE container '$CONTAINER_NAME' with IP $CONTAINER_IP..."

# Create container
sudo lxc-create -n "$CONTAINER_NAME" -t download -- \
    --dist ubuntu --release jammy --arch $(dpkg --print-architecture)

# Configure container
CONFIG_FILE="/var/lib/lxc/$CONTAINER_NAME/config"
sudo tee -a "$CONFIG_FILE" > /dev/null <<EOF

# Network
lxc.net.0.ipv4.address = $CONTAINER_IP/24
lxc.net.0.ipv4.gateway = 10.0.3.1

# Resources (comment out if not supported)
# lxc.cgroup2.memory.max = 2G
# lxc.cgroup2.cpu.max = 200000 100000

# Mounts
lxc.mount.entry = /srv/apps/$CONTAINER_NAME srv/app none bind,create=dir 0 0
lxc.mount.entry = /srv/logs/$CONTAINER_NAME var/log/app none bind,create=dir 0 0
EOF

# Add DNS configuration inside the container's resolv.conf after it starts
echo "nameserver 8.8.8.8" | sudo tee /srv/apps/$CONTAINER_NAME/resolv.conf.template > /dev/null

# Create directories
sudo mkdir -p /srv/apps/$CONTAINER_NAME/{code,config,media}
sudo mkdir -p /srv/logs/$CONTAINER_NAME
OWNER_USER=${SUDO_USER:-ubuntu}
sudo chown -R $OWNER_USER:$OWNER_USER /srv/apps/$CONTAINER_NAME /srv/logs/$CONTAINER_NAME

# Copy setup script
sudo cp /srv/lxc-compose/scripts/setup-container-internal.sh /srv/apps/$CONTAINER_NAME/

echo "Container created! Start with: sudo lxc-start -n $CONTAINER_NAME"
echo "Then attach: sudo lxc-attach -n $CONTAINER_NAME"
echo "Run inside: /srv/app/setup-container-internal.sh $CONTAINER_TYPE"
echo ""
echo "Note: If DNS doesn't work, run inside container:"
echo "  echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
SCRIPT

# Container list script
cat > /srv/lxc-compose/scripts/list-containers.sh <<'SCRIPT'
#!/bin/bash
printf "\n%-20s %-10s %-15s %-10s\n" "CONTAINER" "STATE" "IP ADDRESS" "TYPE"
echo "========================================================="

for container in $(sudo lxc-ls 2>/dev/null); do
    state=$(sudo lxc-info -n $container -s 2>/dev/null | awk '{print $2}')
    if [[ "$state" == "RUNNING" ]]; then
        ip=$(sudo lxc-info -n $container -i 2>/dev/null | awk '{print $2}' | head -1)
        [[ -z "$ip" ]] && ip="Obtaining..."
    else
        ip="N/A"
    fi
    
    # Detect type from name
    if [[ "$container" == *"database"* ]]; then
        type="database"
    elif [[ "$container" == *"monitor"* ]]; then
        type="monitor"
    else
        type="app"
    fi
    
    printf "%-20s %-10s %-15s %-10s\n" "$container" "$state" "$ip" "$type"
done
echo ""
SCRIPT

# Container management script
cat > /srv/lxc-compose/scripts/manage-container.sh <<'SCRIPT'
#!/bin/bash
ACTION=$1
CONTAINER=$2

usage() {
    echo "Usage: $0 {start|stop|restart|attach|exec|info|destroy} <container> [command]"
    exit 1
}

[[ -z "$ACTION" || -z "$CONTAINER" ]] && usage

case "$ACTION" in
    start)
        sudo lxc-start -n "$CONTAINER"
        echo "Container $CONTAINER started"
        sleep 2
        sudo lxc-info -n "$CONTAINER" -i
        ;;
    stop)
        sudo lxc-stop -n "$CONTAINER"
        echo "Container $CONTAINER stopped"
        ;;
    restart)
        sudo lxc-stop -n "$CONTAINER"
        sleep 2
        sudo lxc-start -n "$CONTAINER"
        echo "Container $CONTAINER restarted"
        ;;
    attach)
        sudo lxc-attach -n "$CONTAINER"
        ;;
    exec)
        shift 2
        sudo lxc-attach -n "$CONTAINER" -- "$@"
        ;;
    info)
        sudo lxc-info -n "$CONTAINER"
        ;;
    destroy)
        read -p "Destroy $CONTAINER? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo lxc-stop -n "$CONTAINER" 2>/dev/null || true
            sudo lxc-destroy -n "$CONTAINER"
            sudo rm -rf /srv/apps/$CONTAINER /srv/logs/$CONTAINER
            echo "Container $CONTAINER destroyed"
        fi
        ;;
    *)
        usage
        ;;
esac
SCRIPT

# Container internal setup script
cat > /srv/lxc-compose/scripts/setup-container-internal.sh <<'SCRIPT'
#!/bin/bash
# Run INSIDE container to setup environment

set -e
CONTAINER_TYPE=${1:-app}

echo "Setting up $CONTAINER_TYPE container..."

# Update system
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Base packages
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl wget vim htop sudo systemd systemd-sysv \
    ca-certificates gnupg lsb-release

# Setup based on type
if [[ "$CONTAINER_TYPE" == "app" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        python3 python3-pip python3-venv python3-dev \
        build-essential libpq-dev redis-tools \
        postgresql-client nginx supervisor
    
    # Create app user
    useradd -m -s /bin/bash app || true
    mkdir -p /srv/app /var/log/app
    chown -R app:app /srv/app /var/log/app
    
    echo "App container ready!"

elif [[ "$CONTAINER_TYPE" == "database" ]]; then
    # Use Ubuntu's standard PostgreSQL packages (more reliable)
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        postgresql postgresql-client postgresql-contrib \
        redis-server redis-tools
    
    # Get PostgreSQL version
    PG_VERSION=$(ls /etc/postgresql/ | head -1)
    
    # Configure PostgreSQL
    if [[ -n "$PG_VERSION" ]]; then
        echo "listen_addresses = '*'" >> /etc/postgresql/$PG_VERSION/main/postgresql.conf
        echo "host all all 10.0.3.0/24 md5" >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf
        
        systemctl restart postgresql
    fi
    
    # Configure Redis
    if [[ -f /etc/redis/redis.conf ]]; then
        sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf
        sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
        systemctl restart redis-server
    fi
    
    echo "Database container ready!"
    echo "PostgreSQL version: $PG_VERSION"
    echo "Create PostgreSQL user: sudo -u postgres createuser --interactive"
    echo "Create database: sudo -u postgres createdb dbname"

elif [[ "$CONTAINER_TYPE" == "monitor" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        prometheus grafana nginx
    echo "Monitor container ready!"
fi

echo "Setup complete for $CONTAINER_TYPE container!"
SCRIPT

# Make scripts executable
chmod +x /srv/lxc-compose/scripts/*.sh

#############################################################################
# 11. SYSTEMD SERVICE
#############################################################################

log "Creating systemd service..."

sudo tee /etc/systemd/system/lxc-containers.service > /dev/null <<'EOF'
[Unit]
Description=LXC Containers
After=network-online.target lxc-net.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c 'for c in $(lxc-ls); do lxc-start -n $c; done'
ExecStop=/bin/bash -c 'for c in $(lxc-ls --running); do lxc-stop -n $c; done'

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable lxc-containers.service

#############################################################################
# 12. BASH ALIASES
#############################################################################

log "Setting up bash aliases..."

if ! grep -q "# LXC Aliases" ~/.bashrc; then
    cat >> ~/.bashrc <<'EOF'

# LXC Compose Aliases
alias lxcc-list='/srv/lxc-compose/scripts/list-containers.sh'
alias lxcc-create='/srv/lxc-compose/scripts/create-container.sh'
alias lxcc-manage='/srv/lxc-compose/scripts/manage-container.sh'
alias lxcc-running='sudo lxc-ls --running'
alias lxcc-stop-all='for c in $(sudo lxc-ls --running); do sudo lxc-stop -n $c; done'
alias lxcc-start-all='for c in $(sudo lxc-ls); do sudo lxc-start -n $c; done'

# Shortcuts (alternative names)
alias create-container='/srv/lxc-compose/scripts/create-container.sh'
alias list-containers='/srv/lxc-compose/scripts/list-containers.sh'
alias manage-container='/srv/lxc-compose/scripts/manage-container.sh'

# Navigation
alias cdlxc='cd /srv/lxc-compose'
alias cdapps='cd /srv/apps'
alias cdlogs='cd /srv/logs'

# Monitoring
alias ports='sudo netstat -tulpn | grep LISTEN'
alias monitor='glances'
EOF
fi

#############################################################################
# 13. DOCUMENTATION
#############################################################################

log "Creating documentation..."

cat > /srv/README.md <<'DOCUMENTATION'
# LXC Host Setup Complete

## Quick Start Commands

### Create containers:
```bash
# Database container
lxcc-create database 10.0.3.2 database
sudo lxc-start -n database
sudo lxc-attach -n database
# Inside container:
/srv/app/setup-container-internal.sh database

# App container
lxcc-create app-1 10.0.3.11 app
sudo lxc-start -n app-1
sudo lxc-attach -n app-1
# Inside container:
/srv/app/setup-container-internal.sh app
```

### Manage containers:
```bash
lxcc-list                     # List all containers
lxcc-manage start app-1       # Start container
lxcc-manage stop app-1        # Stop container
lxcc-manage attach app-1      # Enter container
lxcc-manage info app-1        # Container info
```

## Network Layout
- Bridge: lxcbr0 (10.0.3.1)
- Containers: 10.0.3.2-199
- Recommended:
  - 10.0.3.2: database
  - 10.0.3.3: monitor
  - 10.0.3.11+: apps

## Directory Structure
- /srv/lxc-compose/ - System files
- /srv/apps/{container}/ - App data (→ /srv/app)
- /srv/logs/{container}/ - Logs (→ /var/log/app)
- /srv/shared/ - Shared resources

## Security
- UFW firewall (ports: 22, 80, 443)
- fail2ban on SSH
- SSH key-only auth
DOCUMENTATION

#############################################################################
# FINAL STATUS
#############################################################################

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                 LXC Host Setup Complete! ✓                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 System: $(lsb_release -ds)"
echo "🔒 Security: UFW + fail2ban enabled"
echo "🌐 Network: lxcbr0 (10.0.3.1/24)"
echo "📂 Base: /srv/"
echo ""
echo "🚀 Next Steps:"
echo "   1. source ~/.bashrc"
echo "   2. lxcc-create database 10.0.3.2 database"
echo "   3. lxcc-create app-1 10.0.3.11 app"
echo ""
echo "📖 Full docs: /srv/README.md"
echo ""

log "All done! ✓"