#!/bin/bash

#############################################################################
# LXC Compose Wizard - Main Management Interface
# 
# This is the primary interface for all LXC Compose operations after installation.
# It provides an interactive menu system for container management, updates,
# diagnostics, and recovery.
#
# Usage:
#   lxc-compose wizard          # Interactive menu
#   lxc-compose wizard [action] # Direct action
#############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }
prompt() { echo -e "${CYAN}?${NC} $1"; }

# Check if running with proper permissions
check_sudo() {
    if [[ "$EUID" -ne 0 ]]; then
        error "This operation requires sudo privileges"
        info "Please run: sudo lxc-compose wizard"
        exit 1
    fi
}

# Display header
display_header() {
    clear
    echo -e "${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                      LXC Compose Wizard                       ║"
    echo "║                 Container Orchestration System                ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Display main menu
display_menu() {
    echo -e "\n${BOLD}Main Menu${NC}\n"
    echo -e "  ${CYAN}1)${NC} Setup Database (PostgreSQL)"
    echo -e "  ${CYAN}2)${NC} Setup Cache (Redis)"
    echo -e "  ${CYAN}3)${NC} Setup Application Container"
    echo -e "  ${CYAN}4)${NC} Deploy Django Sample App"
    echo ""
    echo -e "  ${CYAN}5)${NC} List Containers"
    echo -e "  ${CYAN}6)${NC} Container Management ${YELLOW}▶${NC}"
    echo -e "  ${CYAN}7)${NC} Port Forwarding ${YELLOW}▶${NC}"
    echo ""
    echo -e "  ${CYAN}8)${NC} System Update"
    echo -e "  ${CYAN}9)${NC} System Diagnostics (Doctor)"
    echo -e "  ${CYAN}10)${NC} Recovery Tools ${YELLOW}▶${NC}"
    echo ""
    echo -e "  ${CYAN}11)${NC} Web Interface ${YELLOW}▶${NC}"
    echo -e "  ${CYAN}12)${NC} Documentation"
    echo ""
    echo -e "  ${CYAN}0)${NC} Exit"
    echo ""
}

# Container management submenu
container_management_menu() {
    clear
    display_header
    echo -e "\n${BOLD}Container Management${NC}\n"
    
    # Show current containers first
    echo -e "${CYAN}Current Containers:${NC}"
    echo "----------------------------------------"
    
    # Check if any containers exist
    local container_count=$(sudo lxc-ls | wc -w)
    if [[ $container_count -eq 0 ]]; then
        echo -e "${YELLOW}No containers found${NC}"
    else
        # Display containers with their status
        sudo lxc-ls -f | grep -E "NAME|RUNNING|STOPPED" || echo "No containers found"
    fi
    
    echo ""
    echo -e "${CYAN}Management Options:${NC}"
    echo "----------------------------------------"
    echo -e "  ${CYAN}1)${NC} Start Container"
    echo -e "  ${CYAN}2)${NC} Stop Container"
    echo -e "  ${CYAN}3)${NC} Restart Container"
    echo -e "  ${CYAN}4)${NC} View Container Logs"
    echo -e "  ${CYAN}5)${NC} Execute Command in Container"
    echo -e "  ${CYAN}6)${NC} Attach to Container Shell"
    echo -e "  ${CYAN}7)${NC} Container Information"
    echo -e "  ${CYAN}8)${NC} Container Console (TTY)"
    echo -e "  ${CYAN}9)${NC} Destroy Container"
    echo ""
    echo -e "  ${CYAN}R)${NC} Refresh List"
    echo -e "  ${CYAN}0)${NC} Back to Main Menu"
    echo ""
    
    read -p "Select option: " choice
    
    case $choice in
        1) start_container; container_management_menu ;;
        2) stop_container; container_management_menu ;;
        3) restart_container; container_management_menu ;;
        4) view_logs; container_management_menu ;;
        5) exec_command; container_management_menu ;;
        6) attach_shell; container_management_menu ;;
        7) container_info; container_management_menu ;;
        8) container_console; container_management_menu ;;
        9) destroy_container; container_management_menu ;;
        [Rr]) container_management_menu ;;  # Refresh
        0) return ;;
        *) warning "Invalid option"; sleep 2; container_management_menu ;;
    esac
}

# Port forwarding submenu
port_forwarding_menu() {
    clear
    display_header
    echo -e "\n${BOLD}Port Forwarding Management${NC}\n"
    
    # Show current port forwards
    echo -e "${CYAN}Current Port Forwards:${NC}"
    echo "----------------------------------------"
    
    # Use the lxc-compose port list command
    if command -v lxc-compose >/dev/null 2>&1; then
        lxc-compose port list || echo "No port forwards configured"
    else
        echo "LXC Compose CLI not available"
    fi
    
    echo ""
    echo -e "${CYAN}Port Forwarding Options:${NC}"
    echo "----------------------------------------"
    echo -e "  ${CYAN}1)${NC} Add Port Forward"
    echo -e "  ${CYAN}2)${NC} Remove Port Forward"
    echo -e "  ${CYAN}3)${NC} Show Port Forwards for Container"
    echo -e "  ${CYAN}4)${NC} Update Container IPs"
    echo -e "  ${CYAN}5)${NC} Apply All Rules (after reboot)"
    echo -e "  ${CYAN}6)${NC} Clear All Port Forwards"
    echo ""
    echo -e "  ${CYAN}7)${NC} Quick Setup: Django App Ports"
    echo -e "  ${CYAN}8)${NC} Quick Setup: Database Ports"
    echo ""
    echo -e "  ${CYAN}R)${NC} Refresh List"
    echo -e "  ${CYAN}0)${NC} Back to Main Menu"
    echo ""
    
    read -p "Select option: " choice
    
    case $choice in
        1) add_port_forward; port_forwarding_menu ;;
        2) remove_port_forward; port_forwarding_menu ;;
        3) show_container_ports; port_forwarding_menu ;;
        4) update_container_ips; port_forwarding_menu ;;
        5) apply_all_port_rules; port_forwarding_menu ;;
        6) clear_all_port_forwards; port_forwarding_menu ;;
        7) setup_django_ports; port_forwarding_menu ;;
        8) setup_database_ports; port_forwarding_menu ;;
        [Rr]) port_forwarding_menu ;;  # Refresh
        0) return ;;
        *) warning "Invalid option"; sleep 2; port_forwarding_menu ;;
    esac
}

# Port forwarding functions
add_port_forward() {
    echo -e "\n${CYAN}Add Port Forward${NC}"
    echo "----------------------------------------"
    
    # Show available containers
    echo -e "${YELLOW}Available containers:${NC}"
    sudo lxc-ls -f | grep -E "NAME|RUNNING" || echo "No containers found"
    echo ""
    
    read -p "Enter host port: " host_port
    if [[ -z "$host_port" ]]; then
        warning "Host port is required"
        sleep 2
        return
    fi
    
    read -p "Enter container name: " container
    if [[ -z "$container" ]]; then
        warning "Container name is required"
        sleep 2
        return
    fi
    
    read -p "Enter container port (default: same as host port): " container_port
    container_port=${container_port:-$host_port}
    
    read -p "Enter description (optional): " description
    
    # Execute the command
    if [[ -n "$description" ]]; then
        sudo lxc-compose port add "$host_port" "$container" "$container_port" -d "$description"
    else
        sudo lxc-compose port add "$host_port" "$container" "$container_port"
    fi
    
    log "Port forward added successfully"
    sleep 2
}

remove_port_forward() {
    echo -e "\n${CYAN}Remove Port Forward${NC}"
    echo "----------------------------------------"
    
    # Show current forwards
    lxc-compose port list
    echo ""
    
    read -p "Enter host port to remove: " host_port
    if [[ -z "$host_port" ]]; then
        warning "Host port is required"
        sleep 2
        return
    fi
    
    read -p "Protocol (tcp/udp) [default: tcp]: " protocol
    protocol=${protocol:-tcp}
    
    sudo lxc-compose port remove "$host_port" -p "$protocol"
    
    log "Port forward removed"
    sleep 2
}

show_container_ports() {
    echo -e "\n${CYAN}Show Container Port Forwards${NC}"
    echo "----------------------------------------"
    
    # Show available containers
    echo -e "${YELLOW}Available containers:${NC}"
    sudo lxc-ls | xargs echo || echo "No containers found"
    echo ""
    
    read -p "Enter container name: " container
    if [[ -z "$container" ]]; then
        return
    fi
    
    lxc-compose port show "$container"
    echo ""
    read -p "Press Enter to continue..."
}

update_container_ips() {
    echo -e "\n${CYAN}Update Container IPs${NC}"
    echo "----------------------------------------"
    
    read -p "Enter container name (or press Enter for all): " container
    
    if [[ -z "$container" ]]; then
        info "Updating all container IPs..."
        sudo lxc-compose port apply
    else
        info "Updating IPs for container: $container"
        sudo lxc-compose port update "$container"
    fi
    
    log "Container IPs updated"
    sleep 2
}

apply_all_port_rules() {
    info "Applying all port forwarding rules..."
    sudo lxc-compose port apply
    log "All port forwarding rules applied"
    sleep 2
}

clear_all_port_forwards() {
    warning "This will remove ALL port forwarding rules!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo lxc-compose port clear
        log "All port forwards cleared"
    else
        info "Cancelled"
    fi
    sleep 2
}

setup_django_ports() {
    echo -e "\n${CYAN}Quick Setup: Django App Ports${NC}"
    echo "----------------------------------------"
    
    read -p "Enter Django container name [default: app-1]: " container
    container=${container:-app-1}
    
    info "Setting up standard Django ports for $container..."
    
    # Nginx/HTTP
    sudo lxc-compose port add 8080 "$container" 80 -d "Nginx HTTP" || true
    # Django dev server
    sudo lxc-compose port add 8000 "$container" 8000 -d "Django Dev Server" || true
    # Alternative Django port
    sudo lxc-compose port add 8001 "$container" 8001 -d "Django Alt Port" || true
    
    log "Django ports configured for $container"
    echo ""
    echo "Access your Django app at:"
    echo "  - http://<host-ip>:8080 (Nginx)"
    echo "  - http://<host-ip>:8000 (Django dev server)"
    
    sleep 3
}

setup_database_ports() {
    echo -e "\n${CYAN}Quick Setup: Database Ports${NC}"
    echo "----------------------------------------"
    
    read -p "Enter database container name [default: datastore]: " container
    container=${container:-datastore}
    
    info "Setting up database ports for $container..."
    
    # PostgreSQL
    sudo lxc-compose port add 5432 "$container" 5432 -d "PostgreSQL" || true
    # Redis
    sudo lxc-compose port add 6379 "$container" 6379 -d "Redis" || true
    
    log "Database ports configured for $container"
    echo ""
    echo "Access your databases at:"
    echo "  - PostgreSQL: <host-ip>:5432"
    echo "  - Redis: <host-ip>:6379"
    
    sleep 3
}

# Recovery tools submenu
recovery_menu() {
    clear
    display_header
    echo -e "\n${BOLD}Recovery Tools${NC}\n"
    echo -e "  ${CYAN}1)${NC} Clean Update (Reset & Update)"
    echo -e "  ${CYAN}2)${NC} Fix Hanging Installations"
    echo -e "  ${CYAN}3)${NC} Reset Network Configuration"
    echo -e "  ${CYAN}4)${NC} Fix Permissions"
    echo -e "  ${CYAN}5)${NC} Reinstall Python Dependencies"
    echo -e "  ${CYAN}6)${NC} Full System Recovery"
    echo ""
    echo -e "  ${CYAN}0)${NC} Back to Main Menu"
    echo ""
    
    read -p "Select option: " choice
    
    case $choice in
        1) clean_update ;;
        2) fix_hanging_install ;;
        3) reset_network ;;
        4) fix_permissions ;;
        5) reinstall_python_deps ;;
        6) full_recovery ;;
        0) return ;;
        *) warning "Invalid option"; sleep 2; recovery_menu ;;
    esac
}

# Setup PostgreSQL in new or existing container
setup_postgresql() {
    check_sudo
    info "PostgreSQL Setup"
    
    # Ask for PostgreSQL version first
    echo -e "\n${CYAN}Select PostgreSQL version:${NC}"
    echo "  1) PostgreSQL 14 (Default, Ubuntu 22.04 standard)"
    echo "  2) PostgreSQL 15 (Latest stable)"
    echo "  3) PostgreSQL 16 (Cutting edge)"
    echo "  4) PostgreSQL 13 (Legacy support)"
    echo ""
    read -p "Enter choice [1-4] (default: 1): " pg_choice
    
    # Set PostgreSQL version based on choice
    case "${pg_choice:-1}" in
        1)
            PG_VERSION="14"
            PG_PACKAGE="postgresql"
            info "Using PostgreSQL 14 (Ubuntu default)"
            ;;
        2)
            PG_VERSION="15"
            PG_PACKAGE="postgresql-15"
            info "Using PostgreSQL 15"
            ;;
        3)
            PG_VERSION="16"
            PG_PACKAGE="postgresql-16"
            info "Using PostgreSQL 16"
            ;;
        4)
            PG_VERSION="13"
            PG_PACKAGE="postgresql-13"
            info "Using PostgreSQL 13"
            ;;
        *)
            PG_VERSION="14"
            PG_PACKAGE="postgresql"
            warning "Invalid choice, using PostgreSQL 14"
            ;;
    esac
    
    # Check for existing containers
    echo ""
    local container_count=$(sudo lxc-ls | wc -w)
    local container_name=""
    
    if [[ $container_count -eq 0 ]]; then
        # No containers exist, must create new one
        warning "No containers found on this system"
        echo ""
        read -p "Enter name for new container (default: datastore): " container_name
        container_name="${container_name:-datastore}"
        
        # Create the container
        create_basic_container "$container_name"
        if [[ $? -ne 0 ]]; then
            error "Failed to create container"
            return 1
        fi
    else
        # Containers exist, show them and ask what to do
        info "Available containers:"
        sudo lxc-ls -f | grep -E "NAME|RUNNING"
        
        echo ""
        echo -e "${CYAN}Installation target:${NC}"
        echo "  1) Install in existing container"
        echo "  2) Create new container"
        echo ""
        read -p "Enter choice [1-2]: " target_choice
        
        if [[ "$target_choice" == "1" ]]; then
            # Install in existing container
            read -p "Enter container name: " container_name
            
            # Check if container exists
            if ! sudo lxc-info -n "$container_name" &>/dev/null; then
                error "Container '$container_name' does not exist"
                return 1
            fi
            
            # Check if running
            local state=$(sudo lxc-info -n "$container_name" 2>/dev/null | grep "State:" | awk '{print $2}')
            if [[ "$state" != "RUNNING" ]]; then
                info "Starting container '$container_name'..."
                sudo lxc-start -n "$container_name"
                sleep 3
            fi
            
        else
            # Create new container
            read -p "Enter name for new container (default: datastore): " container_name
            container_name="${container_name:-datastore}"
            
            # Check if already exists
            if sudo lxc-ls | grep -q "^$container_name$"; then
                warning "Container '$container_name' already exists"
                read -p "Use existing container? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    return 1
                fi
            else
                # Create new container
                create_basic_container "$container_name"
            fi
        fi
    fi
    
    # Install PostgreSQL in the container
    info "Installing PostgreSQL $PG_VERSION in container '$container_name'..."
    
    # Ensure network connectivity
    info "Checking network connectivity..."
    if ! sudo lxc-attach -n "$container_name" -- ping -c 1 8.8.8.8 &>/dev/null; then
        warning "Network connectivity issue detected, configuring DNS..."
        sudo lxc-attach -n "$container_name" -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
        sudo lxc-attach -n "$container_name" -- bash -c "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
        sleep 2
    fi
    
    # Create and run setup script
    cat <<SCRIPT | sudo tee /var/lib/lxc/$container_name/rootfs/tmp/setup-postgresql.sh > /dev/null
#!/bin/bash
set -e

echo "Installing PostgreSQL $PG_VERSION..."

# Update package list
apt-get update -qq

# Add PostgreSQL APT repository if not using default version
if [[ "$PG_VERSION" != "14" ]]; then
    echo "Adding PostgreSQL APT repository..."
    apt-get install -y -qq wget ca-certificates gnupg lsb-release
    mkdir -p /etc/apt/keyrings
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg
    chmod 644 /etc/apt/keyrings/postgresql.gpg
    echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    apt-get update -qq
fi

# Install PostgreSQL
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $PG_PACKAGE postgresql-client-$PG_VERSION

# Wait for PostgreSQL to start
sleep 5

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
cd /tmp
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VERSION/main/postgresql.conf
echo 'host all all 10.0.3.0/24 md5' >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf

# Restart PostgreSQL
systemctl restart postgresql

echo "PostgreSQL $PG_VERSION installation complete!"
SCRIPT
    
    sudo chmod +x /var/lib/lxc/$container_name/rootfs/tmp/setup-postgresql.sh
    sudo lxc-attach -n "$container_name" -- /tmp/setup-postgresql.sh
    
    # Get container IP
    local container_ip=$(sudo lxc-info -n "$container_name" -iH | head -1)
    
    log "PostgreSQL $PG_VERSION installed successfully!"
    log "Container: $container_name"
    log "Connection: psql -h $container_ip -U postgres (password: postgres)"
    
    read -p "Press Enter to continue..."
}

# Setup Redis in new or existing container
setup_redis() {
    check_sudo
    info "Redis Cache Setup"
    
    # Check for existing containers
    echo ""
    local container_count=$(sudo lxc-ls | wc -w)
    local container_name=""
    
    if [[ $container_count -eq 0 ]]; then
        # No containers exist, must create new one
        warning "No containers found on this system"
        echo ""
        read -p "Enter name for new Redis container (default: cache): " container_name
        container_name="${container_name:-cache}"
        
        # Create the container
        create_basic_container "$container_name"
        if [[ $? -ne 0 ]]; then
            error "Failed to create container"
            return 1
        fi
    else
        # Containers exist, show them and ask what to do
        info "Available containers:"
        sudo lxc-ls -f | grep -E "NAME|RUNNING"
        
        echo ""
        echo -e "${CYAN}Installation target:${NC}"
        echo "  1) Install in existing container"
        echo "  2) Create new container"
        echo ""
        read -p "Enter choice [1-2]: " target_choice
        
        if [[ "$target_choice" == "1" ]]; then
            # Install in existing container
            read -p "Enter container name: " container_name
            
            # Check if container exists
            if ! sudo lxc-info -n "$container_name" &>/dev/null; then
                error "Container '$container_name' does not exist"
                return 1
            fi
            
            # Check if running
            local state=$(sudo lxc-info -n "$container_name" 2>/dev/null | grep "State:" | awk '{print $2}')
            if [[ "$state" != "RUNNING" ]]; then
                info "Starting container '$container_name'..."
                sudo lxc-start -n "$container_name"
                sleep 3
            fi
            
        else
            # Create new container
            read -p "Enter name for new container (default: cache): " container_name
            container_name="${container_name:-cache}"
            
            # Check if already exists
            if sudo lxc-ls | grep -q "^$container_name$"; then
                warning "Container '$container_name' already exists"
                read -p "Use existing container? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    return 1
                fi
            else
                # Create new container
                create_basic_container "$container_name"
            fi
        fi
    fi
    
    # Install Redis in the container
    info "Installing Redis in container '$container_name'..."
    
    # Ensure network connectivity
    info "Checking network connectivity..."
    if ! sudo lxc-attach -n "$container_name" -- ping -c 1 8.8.8.8 &>/dev/null; then
        warning "Network connectivity issue detected, configuring DNS..."
        sudo lxc-attach -n "$container_name" -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
        sudo lxc-attach -n "$container_name" -- bash -c "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
        sleep 2
    fi
    
    # Create and run setup script
    cat <<SCRIPT | sudo tee /var/lib/lxc/$container_name/rootfs/tmp/setup-redis.sh > /dev/null
#!/bin/bash
set -e

echo "Installing Redis..."

# Update package list
apt-get update -qq

# Install Redis
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq redis-server redis-tools

# Configure Redis
echo "Configuring Redis..."
sed -i "s/bind 127.0.0.1/bind 0.0.0.0/" /etc/redis/redis.conf
sed -i "s/^protected-mode yes/protected-mode no/" /etc/redis/redis.conf

# Restart Redis
systemctl restart redis-server

echo "Redis installation complete!"
SCRIPT
    
    sudo chmod +x /var/lib/lxc/$container_name/rootfs/tmp/setup-redis.sh
    sudo lxc-attach -n "$container_name" -- /tmp/setup-redis.sh
    
    # Get container IP
    local container_ip=$(sudo lxc-info -n "$container_name" -iH | head -1)
    
    log "Redis installed successfully!"
    log "Container: $container_name"
    log "Connection: redis-cli -h $container_ip"
    
    read -p "Press Enter to continue..."
}

# Helper function to create a basic container
create_basic_container() {
    local container_name="$1"
    
    log "Creating container '$container_name'..."
    sudo lxc-create -n "$container_name" -t ubuntu -- -r jammy
    
    # Configure with next available IP
    # Extract all IPs, handle multiple IPs per container (separated by comma)
    LAST_IP=$(sudo lxc-ls -f | awk '/10.0.3/ {print $5}' | tr ',' '\n' | grep '10.0.3' | cut -d. -f4 | cut -d/ -f1 | sort -n | tail -1)
    # If no containers exist, start at .2 (since .1 is the gateway)
    if [[ -z "$LAST_IP" ]] || [[ "$LAST_IP" -eq "1" ]]; then
        NEXT_IP=2
    else
        NEXT_IP=$((LAST_IP + 1))
    fi
    
    info "Assigning IP: 10.0.3.$NEXT_IP"
    
    # Create mount directory
    sudo mkdir -p "/srv/apps/$container_name"
    
    cat <<EOF | sudo tee /var/lib/lxc/$container_name/config > /dev/null
# Container
lxc.include = /usr/share/lxc/config/ubuntu.common.conf
lxc.arch = linux64

# Network
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.ipv4.address = 10.0.3.$NEXT_IP/24
lxc.net.0.ipv4.gateway = 10.0.3.1

# Mounts
lxc.mount.entry = /srv/apps/$container_name opt/app none bind,create=dir 0 0

# System
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1

# Root filesystem
lxc.rootfs.path = dir:/var/lib/lxc/$container_name/rootfs
EOF
    
    # Start container
    info "Starting container..."
    sudo lxc-start -n "$container_name"
    sleep 5
    
    # Configure DNS in container
    info "Configuring DNS..."
    sudo lxc-attach -n "$container_name" -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
    sudo lxc-attach -n "$container_name" -- bash -c "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
    
    # Wait for network to be ready
    info "Waiting for network connectivity..."
    for i in {1..10}; do
        if sudo lxc-attach -n "$container_name" -- ping -c 1 8.8.8.8 &>/dev/null; then
            break
        fi
        sleep 2
    done
    
    # Test DNS resolution
    if ! sudo lxc-attach -n "$container_name" -- ping -c 1 google.com &>/dev/null; then
        warning "DNS resolution may not be working properly"
    fi
    
    log "Container '$container_name' created with IP 10.0.3.$NEXT_IP"
}

# Legacy function for combined database setup (kept for compatibility)
setup_database_legacy() {
    check_sudo
    info "Setting up database container..."
    
    # Check if already exists
    if sudo lxc-ls | grep -q "^datastore$"; then
        warning "Database container 'datastore' already exists"
        read -p "Recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Stopping and destroying existing container..."
            sudo lxc-stop -n datastore 2>/dev/null || true
            sudo lxc-destroy -n datastore
        else
            return
        fi
    fi
    
    # Ask for PostgreSQL version
    echo -e "\n${CYAN}Select PostgreSQL version:${NC}"
    echo "  1) PostgreSQL 14 (Default, Ubuntu 22.04 standard)"
    echo "  2) PostgreSQL 15 (Latest stable)"
    echo "  3) PostgreSQL 16 (Cutting edge)"
    echo "  4) PostgreSQL 13 (Legacy support)"
    echo ""
    read -p "Enter choice [1-4] (default: 1): " pg_choice
    
    # Set PostgreSQL version based on choice
    case "${pg_choice:-1}" in
        1)
            PG_VERSION="14"
            PG_PACKAGE="postgresql"
            info "Using PostgreSQL 14 (Ubuntu default)"
            ;;
        2)
            PG_VERSION="15"
            PG_PACKAGE="postgresql-15"
            info "Using PostgreSQL 15"
            ;;
        3)
            PG_VERSION="16"
            PG_PACKAGE="postgresql-16"
            info "Using PostgreSQL 16"
            ;;
        4)
            PG_VERSION="13"
            PG_PACKAGE="postgresql-13"
            info "Using PostgreSQL 13"
            ;;
        *)
            PG_VERSION="14"
            PG_PACKAGE="postgresql"
            warning "Invalid choice, using PostgreSQL 14"
            ;;
    esac
    
    # Create container
    log "Creating database container..."
    sudo lxc-create -n datastore -t ubuntu -- -r jammy
    
    # Create mount directories on host
    info "Creating mount directories..."
    sudo mkdir -p /srv/shared/database
    sudo mkdir -p /srv/shared/redis
    sudo chmod 755 /srv/shared
    sudo chmod 755 /srv/shared/database
    sudo chmod 755 /srv/shared/redis
    
    # Configure container
    info "Configuring container..."
    cat <<EOF | sudo tee /var/lib/lxc/datastore/config > /dev/null
# Container
lxc.include = /usr/share/lxc/config/ubuntu.common.conf
lxc.arch = linux64

# Network
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.ipv4.address = 10.0.3.2/24
lxc.net.0.ipv4.gateway = 10.0.3.1

# Mounts
lxc.mount.entry = /srv/shared/database var/lib/postgresql none bind,create=dir 0 0
lxc.mount.entry = /srv/shared/redis var/lib/redis none bind,create=dir 0 0

# System
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1

# Root filesystem
lxc.rootfs.path = dir:/var/lib/lxc/datastore/rootfs
EOF
    
    # Start container with comprehensive logging
    log "Starting container..."
    
    # Create log directory
    sudo mkdir -p /srv/logs/lxc
    local log_file="/srv/logs/lxc/datastore-$(date +%Y%m%d-%H%M%S).log"
    
    # Try to start with debug logging
    if ! sudo lxc-start -n datastore -l DEBUG -o "$log_file"; then
        error "Failed to start container - Initial attempt"
    fi
    
    # Wait for container to be fully ready
    local count=0
    local is_running=false
    while [[ $count -lt 10 ]]; do
        local state=$(sudo lxc-info -n datastore 2>/dev/null | grep "State:" | awk '{print $2}')
        if [[ "$state" == "RUNNING" ]]; then
            log "Container is running"
            is_running=true
            break
        fi
        sleep 1
        count=$((count + 1))
    done
    
    if [[ "$is_running" != "true" ]]; then
        error "Container failed to reach RUNNING state"
        echo ""
        warning "=== DIAGNOSTIC INFORMATION ==="
        
        # Show container info
        info "Container Status:"
        sudo lxc-info -n datastore 2>&1 || echo "  Unable to get container info"
        echo ""
        
        # Check configuration
        info "Container Configuration:"
        if [[ -f /var/lib/lxc/datastore/config ]]; then
            grep -E "^(lxc.net|lxc.rootfs|lxc.mount)" /var/lib/lxc/datastore/config | head -10
        else
            echo "  Config file not found!"
        fi
        echo ""
        
        # Check network
        info "Network Status:"
        if ip link show lxcbr0 &>/dev/null; then
            echo "  ✓ Bridge lxcbr0 exists"
            ip addr show lxcbr0 | grep inet | head -2
        else
            echo "  ✗ Bridge lxcbr0 not found!"
        fi
        echo ""
        
        # Check AppArmor
        info "AppArmor Status:"
        if command -v aa-status &>/dev/null; then
            if sudo aa-status 2>/dev/null | grep -q "lxc-container-default"; then
                echo "  AppArmor profile: lxc-container-default"
                echo "  Try: sudo aa-complain /usr/bin/lxc-start"
            else
                echo "  No LXC AppArmor profile found"
            fi
        else
            echo "  AppArmor not installed"
        fi
        echo ""
        
        # Check storage
        info "Storage:"
        df -h /var/lib/lxc | tail -1
        echo ""
        
        # Check mount points
        info "Mount Points:"
        if [[ -d /srv/shared/database ]]; then
            echo "  ✓ /srv/shared/database exists"
        else
            echo "  ✗ /srv/shared/database missing"
        fi
        if [[ -d /srv/shared/redis ]]; then
            echo "  ✓ /srv/shared/redis exists"
        else
            echo "  ✗ /srv/shared/redis missing"
        fi
        echo ""
        
        # Show last lines of debug log
        if [[ -f "$log_file" ]]; then
            error "Last 30 lines of debug log ($log_file):"
            echo "----------------------------------------"
            tail -30 "$log_file"
            echo "----------------------------------------"
        fi
        echo ""
        
        # Try to identify specific error
        warning "Possible issues detected:"
        if [[ -f "$log_file" ]]; then
            if grep -q "Permission denied" "$log_file"; then
                echo "  • Permission issues - check AppArmor or file permissions"
            fi
            if grep -q "No such file or directory" "$log_file"; then
                echo "  • Missing files or directories - check mount points"
            fi
            if grep -q "Address already in use" "$log_file"; then
                echo "  • Network conflict - IP address may be in use"
            fi
            if grep -q "No space left" "$log_file"; then
                echo "  • Disk space issue - check available storage"
            fi
        fi
        
        # Offer solutions
        echo ""
        info "Suggested fixes:"
        echo "  1. Disable AppArmor: sudo aa-complain /usr/bin/lxc-start"
        echo "  2. Check logs: less $log_file"
        echo "  3. Remove and recreate: sudo lxc-destroy -n datastore"
        echo "  4. Check LXC service: sudo systemctl status lxc"
        echo ""
        
        read -p "Try to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Container setup aborted. Log saved to: $log_file"
            return 1
        fi
    fi
    
    sleep 2
    
    # Create setup script
    info "Creating database setup script..."
    cat <<SCRIPT | sudo tee /var/lib/lxc/datastore/rootfs/tmp/setup-database.sh > /dev/null
#!/bin/bash
set -e

echo "Starting database container setup..."

# Update package list
echo "Updating package repositories..."
apt-get update -qq

# Add PostgreSQL APT repository if not using default version
if [[ "$PG_VERSION" != "14" ]]; then
    echo "Adding PostgreSQL APT repository for version $PG_VERSION..."
    apt-get install -y -qq wget ca-certificates gnupg lsb-release
    # Create keyrings directory
    mkdir -p /etc/apt/keyrings
    # Download and add PostgreSQL signing key
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/keyrings/postgresql.gpg
    chmod 644 /etc/apt/keyrings/postgresql.gpg
    # Add repository
    echo "deb [signed-by=/etc/apt/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    apt-get update -qq
fi

# Install PostgreSQL and Redis
echo "Installing PostgreSQL $PG_VERSION and Redis..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $PG_PACKAGE redis-server

# Wait for PostgreSQL to start
sleep 5

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
cd /tmp
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/$PG_VERSION/main/postgresql.conf
echo 'host all all 10.0.3.0/24 md5' >> /etc/postgresql/$PG_VERSION/main/pg_hba.conf

# Configure Redis
echo "Configuring Redis..."
sed -i "s/bind 127.0.0.1/bind 0.0.0.0/" /etc/redis/redis.conf
sed -i "s/^protected-mode yes/protected-mode no/" /etc/redis/redis.conf

# Restart services
echo "Restarting services..."
systemctl restart postgresql redis-server

echo "Database setup complete!"
SCRIPT

    # Make script executable
    sudo chmod +x /var/lib/lxc/datastore/rootfs/tmp/setup-database.sh
    
    # Execute the setup script inside the container
    info "Running database setup script (this may take a few minutes)..."
    sudo lxc-attach -n datastore -- /tmp/setup-database.sh
    
    log "Database container setup complete!"
    log "PostgreSQL $PG_VERSION: 10.0.3.2:5432 (user: postgres, pass: postgres)"
    log "Redis: 10.0.3.2:6379"
    
    read -p "Press Enter to continue..."
}

# Setup application container
setup_application() {
    check_sudo
    read -p "Enter application name: " app_name
    
    if [[ -z "$app_name" ]]; then
        error "Application name cannot be empty"
        return
    fi
    
    # Check if already exists
    if sudo lxc-ls | grep -q "^$app_name$"; then
        warning "Container '$app_name' already exists"
        read -p "Recreate it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
        sudo lxc-stop -n "$app_name" 2>/dev/null || true
        sudo lxc-destroy -n "$app_name"
    fi
    
    info "Creating application container '$app_name'..."
    
    # Create container
    sudo lxc-create -n "$app_name" -t ubuntu -- -r jammy
    
    # Configure with next available IP
    # Extract all IPs, handle multiple IPs per container (separated by comma)
    LAST_IP=$(sudo lxc-ls -f | awk '/10.0.3/ {print $5}' | tr ',' '\n' | grep '10.0.3' | cut -d. -f4 | cut -d/ -f1 | sort -n | tail -1)
    # If no containers exist, start at .2 (since .1 is the gateway)
    if [[ -z "$LAST_IP" ]] || [[ "$LAST_IP" -eq "1" ]]; then
        NEXT_IP=2
    else
        NEXT_IP=$((LAST_IP + 1))
    fi
    
    info "Assigning IP: 10.0.3.$NEXT_IP"
    
    # Create mount directory on host
    sudo mkdir -p "/srv/apps/$app_name"
    sudo chmod 755 "/srv/apps/$app_name"
    
    cat <<EOF | sudo tee /var/lib/lxc/$app_name/config > /dev/null
# Container
lxc.include = /usr/share/lxc/config/ubuntu.common.conf
lxc.arch = linux64

# Network
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.ipv4.address = 10.0.3.$NEXT_IP/24
lxc.net.0.ipv4.gateway = 10.0.3.1

# Mounts
lxc.mount.entry = /srv/apps/$app_name opt/app none bind,create=dir 0 0

# System
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1

# Root filesystem
lxc.rootfs.path = dir:/var/lib/lxc/$app_name/rootfs
EOF
    
    # Start container with logging
    log "Starting container..."
    
    # Create log directory
    sudo mkdir -p /srv/logs/lxc
    local log_file="/srv/logs/lxc/${app_name}-$(date +%Y%m%d-%H%M%S).log"
    
    # Try to start with debug logging
    if ! sudo lxc-start -n "$app_name" -l DEBUG -o "$log_file"; then
        error "Failed to start container - check $log_file for details"
    fi
    
    # Wait for container to be ready
    local count=0
    local is_running=false
    while [[ $count -lt 10 ]]; do
        local state=$(sudo lxc-info -n "$app_name" 2>/dev/null | grep "State:" | awk '{print $2}')
        if [[ "$state" == "RUNNING" ]]; then
            log "Container is running"
            is_running=true
            break
        fi
        sleep 1
        count=$((count + 1))
    done
    
    if [[ "$is_running" != "true" ]]; then
        error "Container failed to start. Debug log: $log_file"
        tail -20 "$log_file"
        return 1
    fi
    
    sleep 2
    
    # Configure DNS in container
    info "Configuring DNS..."
    sudo lxc-attach -n "$app_name" -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
    sudo lxc-attach -n "$app_name" -- bash -c "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
    
    # Wait for network to be ready
    info "Waiting for network connectivity..."
    for i in {1..10}; do
        if sudo lxc-attach -n "$app_name" -- ping -c 1 8.8.8.8 &>/dev/null; then
            break
        fi
        sleep 2
    done
    
    # Create setup script
    info "Creating application setup script..."
    cat <<SCRIPT | sudo tee /var/lib/lxc/$app_name/rootfs/tmp/setup-app.sh > /dev/null
#!/bin/bash
set -e

echo "Starting application container setup..."

# Update package list
echo "Updating package repositories..."
apt-get update -qq

# Install development tools and runtime dependencies
echo "Installing Python, Nginx, and other dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \\
    python3 python3-pip python3-venv python3-dev \\
    nginx supervisor \\
    build-essential git curl wget \\
    postgresql-client redis-tools \\
    nodejs npm

# Install commonly used Python packages globally
echo "Installing common Python packages..."
pip3 install --quiet \\
    gunicorn uvicorn \\
    django flask fastapi \\
    celery redis \\
    psycopg2-binary sqlalchemy \\
    requests python-dotenv

# Configure Nginx
echo "Configuring Nginx..."
rm -f /etc/nginx/sites-enabled/default
systemctl enable nginx

# Configure Supervisor
echo "Configuring Supervisor..."
systemctl enable supervisor

# Create app directory structure
mkdir -p /opt/app
chown -R ubuntu:ubuntu /opt/app 2>/dev/null || true

echo "Application container setup complete!"
SCRIPT

    # Make script executable
    sudo chmod +x /var/lib/lxc/$app_name/rootfs/tmp/setup-app.sh
    
    # Execute the setup script inside the container
    info "Running application setup script (this may take a few minutes)..."
    sudo lxc-attach -n "$app_name" -- /tmp/setup-app.sh
    
    log "Application container '$app_name' created successfully!"
    log "IP Address: 10.0.3.$NEXT_IP"
    log "App directory: /srv/apps/$app_name"
    
    read -p "Press Enter to continue..."
}

# Deploy Django sample
deploy_django_sample() {
    check_sudo
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║        Deploy Django+Celery Sample Application               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Container names for sample app - dedicated containers
    local DJANGO_CONTAINER="sample-django-app"
    local DATASTORE_CONTAINER="sample-datastore"
    
    info "This will deploy a Django+Celery sample app with:"
    echo "  • Django container: $DJANGO_CONTAINER"
    echo "  • Database container: $DATASTORE_CONTAINER (PostgreSQL + Redis)"
    echo "  • Automatic port forwarding setup"
    echo ""
    
    read -p "Continue? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        info "Deployment cancelled"
        return
    fi
    
    # Step 1: Handle sample-datastore container
    if sudo lxc-ls | grep -q "^${DATASTORE_CONTAINER}$"; then
        warning "Sample datastore container '$DATASTORE_CONTAINER' already exists"
        read -p "Remove and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Removing existing container..."
            sudo lxc-stop -n "$DATASTORE_CONTAINER" 2>/dev/null || true
            sudo lxc-destroy -n "$DATASTORE_CONTAINER"
        else
            info "Using existing container"
            # Ensure it's running
            if ! sudo lxc-ls --running | grep -q "^${DATASTORE_CONTAINER}$"; then
                log "Starting $DATASTORE_CONTAINER container..."
                sudo lxc-start -n "$DATASTORE_CONTAINER"
                sleep 5
            fi
        fi
    fi
    
    # Create sample-datastore if it doesn't exist
    if ! sudo lxc-ls | grep -q "^${DATASTORE_CONTAINER}$"; then
        log "Creating sample datastore container..."
        
        # Use lxc-create (classic LXC)
        sudo lxc-create -n "$DATASTORE_CONTAINER" -t ubuntu -- -r jammy || error "Failed to create datastore container"
        
        # Configure container with static IP
        sudo bash -c "cat > /var/lib/lxc/$DATASTORE_CONTAINER/config" <<EOF
# Container
lxc.include = /usr/share/lxc/config/ubuntu.common.conf
lxc.arch = linux64

# Network
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.ipv4.address = 10.0.3.30/24
lxc.net.0.ipv4.gateway = 10.0.3.1

# System
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1

# Root filesystem
lxc.rootfs.path = dir:/var/lib/lxc/$DATASTORE_CONTAINER/rootfs
EOF
        
        # Start container
        log "Starting sample datastore container..."
        sudo lxc-start -n "$DATASTORE_CONTAINER"
        sleep 10  # Give it time to fully start
        
        # Wait for network to be ready
        local count=0
        while [[ $count -lt 10 ]]; do
            if sudo lxc-attach -n "$DATASTORE_CONTAINER" -- ip addr show 2>/dev/null | grep -q "10.0.3.30"; then
                log "Container network is ready"
                break
            fi
            sleep 2
            count=$((count + 1))
        done
        
        # Install PostgreSQL and Redis
        log "Installing PostgreSQL and Redis..."
        sudo lxc-attach -n "$DATASTORE_CONTAINER" -- bash -c "
            # Wait for apt to be ready
            while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
                echo 'Waiting for apt lock...'
                sleep 2
            done
            
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-contrib redis-server
            
            # Configure PostgreSQL to listen on all interfaces
            sed -i \"s/#listen_addresses = 'localhost'/listen_addresses = '*'/g\" /etc/postgresql/14/main/postgresql.conf
            echo 'host    all             all             10.0.3.0/24            md5' >> /etc/postgresql/14/main/pg_hba.conf
            
            # Configure Redis to listen on all interfaces
            sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/g' /etc/redis/redis.conf
            sed -i 's/protected-mode yes/protected-mode no/g' /etc/redis/redis.conf
            
            # Restart services
            systemctl restart postgresql
            systemctl restart redis-server
        " || warning "Some packages might already be installed"
        
        log "Sample datastore container created and configured"
    fi
    
    # Step 2: Handle sample-django-app container
    if sudo lxc-ls | grep -q "^${DJANGO_CONTAINER}$"; then
        warning "Django sample container '$DJANGO_CONTAINER' already exists"
        read -p "Remove and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Removing existing container..."
            sudo lxc-stop -n "$DJANGO_CONTAINER" 2>/dev/null || true
            sudo lxc-destroy -n "$DJANGO_CONTAINER"
        else
            info "Using existing container"
            # Ensure it's running
            if ! sudo lxc-ls --running | grep -q "^${DJANGO_CONTAINER}$"; then
                log "Starting $DJANGO_CONTAINER container..."
                sudo lxc-start -n "$DJANGO_CONTAINER"
                sleep 5
            fi
        fi
    fi
    
    # Create sample-django-app if it doesn't exist
    if ! sudo lxc-ls | grep -q "^${DJANGO_CONTAINER}$"; then
        log "Creating Django application container..."
        
        # Use lxc-create (classic LXC)
        sudo lxc-create -n "$DJANGO_CONTAINER" -t ubuntu -- -r jammy || error "Failed to create Django container"
        
        # Configure container with static IP
        sudo bash -c "cat > /var/lib/lxc/$DJANGO_CONTAINER/config" <<EOF
# Container
lxc.include = /usr/share/lxc/config/ubuntu.common.conf
lxc.arch = linux64

# Network
lxc.net.0.type = veth
lxc.net.0.link = lxcbr0
lxc.net.0.flags = up
lxc.net.0.ipv4.address = 10.0.3.31/24
lxc.net.0.ipv4.gateway = 10.0.3.1

# System
lxc.apparmor.profile = generated
lxc.apparmor.allow_nesting = 1

# Root filesystem
lxc.rootfs.path = dir:/var/lib/lxc/$DJANGO_CONTAINER/rootfs
EOF
        
        # Start container
        log "Starting Django application container..."
        sudo lxc-start -n "$DJANGO_CONTAINER"
        sleep 10  # Give it time to fully start
        
        # Wait for network to be ready
        local count=0
        while [[ $count -lt 10 ]]; do
            if sudo lxc-attach -n "$DJANGO_CONTAINER" -- ip addr show 2>/dev/null | grep -q "10.0.3.31"; then
                log "Container network is ready"
                break
            fi
            sleep 2
            count=$((count + 1))
        done
    fi
    
    # Step 3: Setup database and user in datastore
    log "Setting up database..."
    sudo lxc-attach -n "$DATASTORE_CONTAINER" -- sudo -u postgres psql <<EOF 2>/dev/null || true
CREATE USER djangouser WITH PASSWORD 'djangopass123';
CREATE DATABASE djangosample OWNER djangouser;
GRANT ALL PRIVILEGES ON DATABASE djangosample TO djangouser;
EOF
    
    # Step 4: Deploy Django application
    if [[ -f /srv/lxc-compose/create-django-sample.sh ]]; then
        info "Deploying Django application to $DJANGO_CONTAINER..."
        
        # Run the deployment script with our container name and correct IPs
        sudo /srv/lxc-compose/create-django-sample.sh "$DJANGO_CONTAINER" \
            10.0.3.30 djangosample djangouser djangopass123 10.0.3.30
    else
        # Fallback: inline deployment if script is missing
        warning "Deployment script not found, using inline deployment..."
        
        # Install packages in Django container
        log "Installing Python and dependencies..."
        sudo lxc-attach -n "$DJANGO_CONTAINER" -- bash -c "
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y \
                python3 python3-pip python3-venv python3-dev \
                build-essential libpq-dev nginx supervisor git \
                redis-tools postgresql-client
        "
        
        # Create simple Django app
        log "Creating Django application..."
        sudo lxc exec "$DJANGO_CONTAINER" -- bash -c "
            # Create app directory
            mkdir -p /app
            cd /app
            
            # Create virtual environment
            python3 -m venv venv
            source venv/bin/activate
            
            # Install Django and dependencies
            pip install django psycopg2-binary redis celery gunicorn
            
            # Create Django project
            django-admin startproject myapp .
            
            # Configure settings for PostgreSQL
            cat >> myapp/settings.py <<'SETTINGS'

# Database configuration
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'djangosample',
        'USER': 'djangouser',
        'PASSWORD': 'djangopass123',
        'HOST': '10.0.3.30',
        'PORT': '5432',
    }
}

# Allow all hosts for development
ALLOWED_HOSTS = ['*']

# Celery configuration
CELERY_BROKER_URL = 'redis://10.0.3.30:6379/0'
CELERY_RESULT_BACKEND = 'redis://10.0.3.30:6379/0'
SETTINGS
            
            # Run migrations
            source venv/bin/activate
            python manage.py migrate
            python manage.py collectstatic --noinput || true
            
            # Create superuser (non-interactive)
            echo \"from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@example.com', 'admin123') if not User.objects.filter(username='admin').exists() else None\" | python manage.py shell
        "
        
        log "Django application deployed"
    fi
    
    # Step 5: Setup port forwarding automatically
    info "Setting up port forwarding..."
    
    # Django app ports
    sudo lxc-compose port add 8080 "$DJANGO_CONTAINER" 80 -d "Django Nginx" 2>/dev/null || true
    sudo lxc-compose port add 8000 "$DJANGO_CONTAINER" 8000 -d "Django Dev Server" 2>/dev/null || true
    
    # Database ports
    sudo lxc-compose port add 5432 "$DATASTORE_CONTAINER" 5432 -d "PostgreSQL" 2>/dev/null || true
    sudo lxc-compose port add 6379 "$DATASTORE_CONTAINER" 6379 -d "Redis" 2>/dev/null || true
    
    # Step 6: Start services
    log "Starting Django services..."
    sudo lxc-attach -n "$DJANGO_CONTAINER" -- bash -c "
        cd /app
        source venv/bin/activate
        nohup python manage.py runserver 0.0.0.0:8000 > /tmp/django.log 2>&1 &
    " 2>/dev/null || true
    
    # Get host IP for access information
    local HOST_IP=$(ip -4 addr show | grep -v 127.0.0.1 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            Django Sample Application Deployed! ✓              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Access your Django application:"
    echo "  • Django Dev Server: http://$HOST_IP:8000"
    echo "  • Django Admin: http://$HOST_IP:8000/admin"
    echo "  • Username: admin"
    echo "  • Password: admin123"
    echo ""
    echo "Database access:"
    echo "  • PostgreSQL: $HOST_IP:5432 (user: djangouser, db: djangosample)"
    echo "  • Redis: $HOST_IP:6379"
    echo ""
    echo "Containers created:"
    echo "  • $DJANGO_CONTAINER (10.0.3.31) - Django application"
    echo "  • $DATASTORE_CONTAINER (10.0.3.30) - PostgreSQL + Redis"
    echo ""
    echo "Manage with:"
    echo "  • sudo lxc-attach -n $DJANGO_CONTAINER"
    echo "  • lxc-compose port list"
    echo ""
    
    read -p "Press Enter to continue..."
}

# List containers
list_containers() {
    echo -e "\n${BOLD}LXC Containers${NC}\n"
    sudo lxc-ls --fancy
    echo ""
    sleep 2
}

# System update
system_update() {
    check_sudo
    info "Updating LXC Compose..."
    
    cd /srv/lxc-compose
    
    # Check for local changes
    if git status --porcelain | grep -q .; then
        warning "Local modifications detected:"
        git status --short
        echo ""
        read -p "Reset local changes and update? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git reset --hard HEAD
            git clean -fd
        else
            info "Update cancelled"
            return
        fi
    fi
    
    # Pull updates
    info "Fetching updates..."
    git fetch origin main
    
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)
    
    if [[ "$LOCAL" == "$REMOTE" ]]; then
        log "Already up to date!"
    else
        git pull origin main
        log "Successfully updated!"
        
        # Show recent changes
        echo -e "\n${BOLD}Recent changes:${NC}"
        git log --oneline -5
    fi
}

# System diagnostics
system_diagnostics() {
    check_sudo
    info "Running system diagnostics..."
    
    if [[ -f /srv/lxc-compose/cli/doctor.py ]]; then
        read -p "Attempt to fix issues automatically? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            python3 /srv/lxc-compose/cli/doctor.py --fix
        else
            python3 /srv/lxc-compose/cli/doctor.py
        fi
    else
        # Fallback to basic diagnostics
        info "Running basic system checks..."
        
        # Check LXC
        if command -v lxc-ls &>/dev/null; then
            log "LXC is installed"
        else
            error "LXC is not installed"
        fi
        
        # Check network bridge
        if ip link show lxcbr0 &>/dev/null; then
            log "Network bridge configured"
        else
            error "Network bridge not found"
        fi
        
        # Check Python modules
        if python3 -c "import click, yaml" 2>/dev/null; then
            log "Python modules installed"
        else
            warning "Some Python modules missing"
        fi
    fi
    
    sleep 2
}

# Clean update (from recovery menu)
clean_update() {
    check_sudo
    warning "This will reset all local changes and force update!"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    cd /srv/lxc-compose
    git reset --hard HEAD
    git clean -fd
    git pull origin main
    
    log "Clean update complete!"
    sleep 2
}

# Fix hanging installations
fix_hanging_install() {
    check_sudo
    info "Checking for hanging processes..."
    
    # Kill hanging snap processes
    if pgrep -f "snap install" > /dev/null; then
        warning "Found hanging snap install process"
        pkill -f "snap install" || true
        log "Killed hanging snap processes"
    fi
    
    # Restart snapd
    info "Restarting snapd service..."
    systemctl restart snapd || true
    
    # Clean snap locks
    rm -f /var/lib/snapd/state.lock 2>/dev/null || true
    
    log "Fixed hanging installations"
    sleep 2
}

# Reset network configuration
reset_network() {
    check_sudo
    info "Resetting LXC network configuration..."
    
    # Recreate bridge
    ip link delete lxcbr0 2>/dev/null || true
    ip link add name lxcbr0 type bridge
    ip addr add 10.0.3.1/24 dev lxcbr0
    ip link set lxcbr0 up
    
    # Restart services
    systemctl restart lxc-net 2>/dev/null || true
    
    log "Network configuration reset"
    sleep 2
}

# Fix permissions
fix_permissions() {
    check_sudo
    info "Fixing directory permissions..."
    
    OWNER_USER=${SUDO_USER:-ubuntu}
    chown -R $OWNER_USER:$OWNER_USER /srv/
    
    log "Permissions fixed"
    sleep 1
}

# Reinstall Python dependencies
reinstall_python_deps() {
    check_sudo
    info "Reinstalling Python dependencies..."
    
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    if [[ $(echo "$PYTHON_VERSION >= 3.11" | bc -l) -eq 1 ]]; then
        PIP_FLAGS="--break-system-packages"
    else
        PIP_FLAGS=""
    fi
    
    for package in click yaml jinja2 tabulate colorama requests; do
        pip3 install $PIP_FLAGS $package || apt-get install -y python3-${package//_/-} || true
    done
    
    log "Python dependencies reinstalled"
    sleep 2
}

# Full recovery
full_recovery() {
    check_sudo
    warning "This will perform a full system recovery!"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return
    fi
    
    info "Starting full recovery..."
    
    fix_hanging_install
    reset_network
    fix_permissions
    reinstall_python_deps
    clean_update
    
    log "Full recovery complete!"
    sleep 3
}

# Container operations
start_container() {
    echo -e "\n${CYAN}Stopped containers:${NC}"
    sudo lxc-ls -f | grep "STOPPED" || echo "No stopped containers"
    echo ""
    read -p "Enter container name to start: " name
    if [[ -z "$name" ]]; then
        return
    fi
    sudo lxc-start -n "$name"
    log "Container '$name' started"
    sleep 2
}

stop_container() {
    echo -e "\n${CYAN}Running containers:${NC}"
    sudo lxc-ls -f | grep "RUNNING" || echo "No running containers"
    echo ""
    read -p "Enter container name to stop: " name
    if [[ -z "$name" ]]; then
        return
    fi
    sudo lxc-stop -n "$name"
    log "Container '$name' stopped"
    sleep 2
}

restart_container() {
    echo -e "\n${CYAN}All containers:${NC}"
    sudo lxc-ls -f | head -10 || echo "No containers"
    echo ""
    read -p "Enter container name to restart: " name
    if [[ -z "$name" ]]; then
        return
    fi
    sudo lxc-stop -n "$name"
    sudo lxc-start -n "$name"
    log "Container '$name' restarted"
    sleep 2
}

view_logs() {
    echo -e "\n${CYAN}All containers:${NC}"
    sudo lxc-ls -f | head -10 || echo "No containers"
    echo ""
    read -p "Enter container name to view logs: " name
    if [[ -z "$name" ]]; then
        return
    fi
    
    echo -e "\n${CYAN}Container Logs for '$name':${NC}"
    echo "----------------------------------------"
    
    # Show system logs from the container
    echo -e "\n${YELLOW}Recent System Logs:${NC}"
    sudo lxc-attach -n "$name" -- journalctl -n 50 --no-pager 2>/dev/null || \
        sudo lxc-attach -n "$name" -- tail -50 /var/log/syslog 2>/dev/null || \
        echo "System logs not available"
    
    # Show application logs if they exist
    if sudo lxc-attach -n "$name" -- test -d /var/log/supervisor; then
        echo -e "\n${YELLOW}Supervisor Logs:${NC}"
        sudo lxc-attach -n "$name" -- tail -20 /var/log/supervisor/supervisord.log 2>/dev/null || true
    fi
    
    # For PostgreSQL containers
    if sudo lxc-attach -n "$name" -- test -d /var/log/postgresql; then
        echo -e "\n${YELLOW}PostgreSQL Logs:${NC}"
        sudo lxc-attach -n "$name" -- tail -20 /var/log/postgresql/*.log 2>/dev/null || true
    fi
    
    # For Redis containers
    if sudo lxc-attach -n "$name" -- test -f /var/log/redis/redis-server.log; then
        echo -e "\n${YELLOW}Redis Logs:${NC}"
        sudo lxc-attach -n "$name" -- tail -20 /var/log/redis/redis-server.log 2>/dev/null || true
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

exec_command() {
    echo -e "\n${CYAN}Running containers:${NC}"
    sudo lxc-ls -f | grep "RUNNING" || echo "No running containers"
    echo ""
    read -p "Enter container name: " name
    if [[ -z "$name" ]]; then
        return
    fi
    read -p "Enter command: " cmd
    if [[ -z "$cmd" ]]; then
        return
    fi
    sudo lxc-attach -n "$name" -- $cmd
    sleep 2
}

attach_shell() {
    echo -e "\n${CYAN}Running containers:${NC}"
    sudo lxc-ls -f | grep "RUNNING" || echo "No running containers"
    echo ""
    read -p "Enter container name to attach: " name
    if [[ -z "$name" ]]; then
        return
    fi
    info "Attaching to container '$name'. Use Ctrl+A, Q to detach."
    sleep 2
    sudo lxc-attach -n "$name"
}

container_info() {
    echo -e "\n${CYAN}All containers:${NC}"
    sudo lxc-ls -f | head -10 || echo "No containers"
    echo ""
    read -p "Enter container name for info: " name
    if [[ -z "$name" ]]; then
        return
    fi
    sudo lxc-info -n "$name"
    echo ""
    read -p "Press Enter to continue..."
}

container_console() {
    echo -e "\n${CYAN}All containers:${NC}"
    sudo lxc-ls -f | head -10 || echo "No containers"
    echo ""
    read -p "Enter container name for console access: " name
    if [[ -z "$name" ]]; then
        return
    fi
    info "Connecting to container console (TTY)..."
    info "Default login: ubuntu / ubuntu"
    info "Use Ctrl+A, Q to exit the console"
    sleep 3
    sudo lxc-console -n "$name" -t 0
}

destroy_container() {
    echo -e "\n${CYAN}All containers:${NC}"
    sudo lxc-ls -f | head -10 || echo "No containers"
    echo ""
    read -p "Enter container name to destroy: " name
    if [[ -z "$name" ]]; then
        return
    fi
    warning "This will permanently destroy container '$name'"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo lxc-stop -n "$name" 2>/dev/null || true
        sudo lxc-destroy -n "$name"
        log "Container '$name' destroyed"
    fi
    sleep 2
}

# Web interface management
web_interface_menu() {
    clear
    display_header
    echo -e "\n${BOLD}Web Interface Management${NC}\n"
    
    # Check status using same patterns as other functions
    local pid=""
    for pattern in "python3.*app.py" "python.*app.py" "lxc-compose-manager/app.py" "flask.*app.py"; do
        pid=$(pgrep -f "$pattern" 2>/dev/null | head -1 || true)
        if [[ -n "$pid" ]]; then
            break
        fi
    done
    
    if [[ -n "$pid" ]]; then
        echo -e "  Status: ${GREEN}● Running${NC}"
        echo -e "  PID: $pid"
    else
        echo -e "  Status: ${RED}○ Stopped${NC}"
    fi
    
    # Get IP
    IP=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1 || echo "localhost")
    echo -e "  URL: http://$IP:5000"
    echo ""
    
    echo -e "  ${CYAN}1)${NC} Start Web Interface"
    echo -e "  ${CYAN}2)${NC} Stop Web Interface"
    echo -e "  ${CYAN}3)${NC} Restart Web Interface"
    echo -e "  ${CYAN}4)${NC} View Logs"
    echo -e "  ${CYAN}5)${NC} Install/Update Dependencies"
    echo ""
    echo -e "  ${CYAN}0)${NC} Back to Main Menu"
    echo ""
    
    read -p "Select option: " choice
    
    case $choice in
        1) start_web_interface; web_interface_menu ;;
        2) stop_web_interface; web_interface_menu ;;
        3) restart_web_interface; web_interface_menu ;;
        4) view_web_logs; web_interface_menu ;;
        5) install_web_dependencies; web_interface_menu ;;
        0) return ;;
        *) warning "Invalid option"; sleep 2; web_interface_menu ;;
    esac
}

# Start web interface
start_web_interface() {
    info "Starting web interface..."
    
    # Check if already running using same patterns as stop function
    local pid=""
    for pattern in "python3.*app.py" "python.*app.py" "lxc-compose-manager/app.py" "flask.*app.py"; do
        pid=$(pgrep -f "$pattern" 2>/dev/null | head -1 || true)
        if [[ -n "$pid" ]]; then
            break
        fi
    done
    
    if [[ -n "$pid" ]]; then
        warning "Web interface is already running"
        info "PID: $pid"
        IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
        echo -e "  Access at: ${GREEN}http://$IP:5000${NC}"
        sleep 2
        return 0
    fi
    
    # Check if directory exists
    if [[ ! -d /srv/lxc-compose/lxc-compose-manager ]]; then
        error "Web interface not found at /srv/lxc-compose/lxc-compose-manager"
        read -p "Install it now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_web_dependencies
        else
            return
        fi
    fi
    
    # Ensure log directory exists
    mkdir -p /srv/logs
    
    # Start the Flask app
    info "Starting Flask application..."
    pushd /srv/lxc-compose/lxc-compose-manager > /dev/null 2>&1
    nohup python3 app.py > /srv/logs/manager.log 2>&1 &
    local new_pid=$!
    popd > /dev/null 2>&1
    
    # Give it time to start
    sleep 3
    
    # Check if started by looking for the process
    local pid=""
    for pattern in "python3.*app.py" "python.*app.py" "lxc-compose-manager/app.py"; do
        pid=$(pgrep -f "$pattern" 2>/dev/null | head -1 || true)
        if [[ -n "$pid" ]]; then
            break
        fi
    done
    
    if [[ -n "$pid" ]]; then
        log "Web interface started successfully"
        info "PID: $pid"
        IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
        echo -e "  Access at: ${GREEN}http://$IP:5000${NC}"
        sleep 2
        return 0
    else
        error "Failed to start web interface"
        echo "Check logs at: /srv/logs/manager.log"
        # Show last few lines of log for debugging
        if [[ -f /srv/logs/manager.log ]]; then
            echo "Recent log entries:"
            tail -10 /srv/logs/manager.log
        fi
        return 1
    fi
}

# Stop web interface
stop_web_interface() {
    info "Stopping web interface..."
    
    # Find the PID of the web interface process
    local pid=""
    
    # Check multiple patterns for the running process
    for pattern in "python3.*app.py" "python.*app.py" "lxc-compose-manager/app.py" "flask.*app.py"; do
        pid=$(pgrep -f "$pattern" 2>/dev/null | head -1 || true)
        if [[ -n "$pid" ]]; then
            break
        fi
    done
    
    if [[ -n "$pid" ]]; then
        info "Found web interface process (PID: $pid)"
        
        # Try graceful termination first
        kill $pid 2>/dev/null || true
        
        # Wait for process to stop
        local count=0
        while [[ $count -lt 5 ]]; do
            if ! kill -0 $pid 2>/dev/null; then
                log "Web interface stopped"
                return 0
            fi
            sleep 1
            count=$((count + 1))
        done
        
        # Force kill if still running
        warning "Process didn't stop gracefully, forcing..."
        kill -9 $pid 2>/dev/null || true
        sleep 1
        
        if ! kill -0 $pid 2>/dev/null; then
            log "Web interface stopped (forced)"
            return 0
        else
            error "Failed to stop web interface (PID: $pid)"
            return 1
        fi
    else
        warning "Web interface is not running"
        return 0
    fi
}

# Restart web interface
restart_web_interface() {
    info "Restarting web interface..."
    
    # Stop the interface (ignore errors as it might not be running)
    stop_web_interface || true
    
    # Wait a moment
    sleep 2
    
    # Start the interface
    start_web_interface
}

# View web logs
view_web_logs() {
    info "Showing last 50 lines of web interface logs..."
    echo ""
    
    if [[ -f /srv/logs/manager.log ]]; then
        tail -50 /srv/logs/manager.log
    else
        warning "No logs found at /srv/logs/manager.log"
    fi
    
    echo ""
    sleep 2
}

# Install web dependencies
install_web_dependencies() {
    info "Installing web interface dependencies..."
    
    # Ensure directory exists
    mkdir -p /srv/lxc-compose/lxc-compose-manager
    
    # Check for requirements.txt
    if [[ -f /srv/lxc-compose/lxc-compose-manager/requirements.txt ]]; then
        cd /srv/lxc-compose/lxc-compose-manager
        
        # Detect Python version for pip flags
        PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
        if [[ $(echo "$PYTHON_VERSION >= 3.11" | bc -l) -eq 1 ]]; then
            PIP_FLAGS="--break-system-packages"
        else
            PIP_FLAGS=""
        fi
        
        pip3 install $PIP_FLAGS -r requirements.txt
        log "Dependencies installed"
    else
        warning "requirements.txt not found"
        info "Installing basic Flask dependencies..."
        
        for package in flask flask-socketio flask-cors eventlet; do
            pip3 install $PIP_FLAGS $package || true
        done
    fi
    
    # Ensure log directory exists
    mkdir -p /srv/logs
    touch /srv/logs/manager.log
    
    log "Web interface ready"
}

# Show documentation
show_documentation() {
    clear
    display_header
    echo -e "\n${BOLD}LXC Compose Documentation${NC}\n"
    
    echo "Quick Start Guide:"
    echo "  1. Setup database: Option 1 from main menu"
    echo "  2. Setup application: Option 2 from main menu"
    echo "  3. Deploy sample app: Option 3 from main menu"
    echo ""
    echo "Container IPs:"
    echo "  - Database: 10.0.3.2 (PostgreSQL & Redis)"
    echo "  - Applications: 10.0.3.11+"
    echo ""
    echo "Directories:"
    echo "  - Apps: /srv/apps/<app-name>"
    echo "  - Shared: /srv/shared"
    echo "  - Logs: /srv/logs"
    echo ""
    echo "Commands:"
    echo "  - lxc-compose up/down/restart"
    echo "  - lxc-compose logs <container>"
    echo "  - lxc-compose exec <container> <command>"
    echo ""
    echo "For more info: https://github.com/unomena/lxc-compose"
    
    sleep 3
}

# Handle command-line arguments
handle_args() {
    case "${1:-}" in
        setup-db|database)
            setup_database
            ;;
        setup-app|application)
            setup_application
            ;;
        django|sample)
            deploy_django_sample
            ;;
        update)
            system_update
            ;;
        doctor|diagnostics)
            system_diagnostics
            ;;
        recover|recovery)
            full_recovery
            ;;
        clean-update)
            clean_update
            ;;
        web|webui|web-interface)
            web_interface_menu
            ;;
        web-start)
            check_sudo
            start_web_interface
            ;;
        web-stop)
            check_sudo
            stop_web_interface
            ;;
        web-restart)
            check_sudo
            restart_web_interface
            ;;
        web-install)
            check_sudo
            install_web_dependencies
            ;;
        help|--help|-h)
            show_documentation
            ;;
        "")
            # No arguments, show interactive menu
            return 0
            ;;
        *)
            error "Unknown command: $1"
            info "Use 'lxc-compose wizard help' for available commands"
            exit 1
            ;;
    esac
    exit 0
}

# Main execution
main() {
    # Handle command-line arguments if provided
    handle_args "$@"
    
    # Interactive menu loop
    while true; do
        display_header
        display_menu
        
        read -p "Select option: " choice
        
        case $choice in
            1) setup_postgresql ;;
            2) setup_redis ;;
            3) setup_application ;;
            4) deploy_django_sample ;;
            5) list_containers ;;
            6) container_management_menu ;;
            7) port_forwarding_menu ;;
            8) system_update ;;
            9) system_diagnostics ;;
            10) recovery_menu ;;
            11) web_interface_menu ;;
            12) show_documentation ;;
            0) 
                echo -e "\n${GREEN}Thank you for using LXC Compose!${NC}\n"
                exit 0
                ;;
            *)
                warning "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Run main function
main "$@"