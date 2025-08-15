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
    echo "║                    LXC Compose Wizard                        ║"
    echo "║                 Container Orchestration System               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Display main menu
display_menu() {
    echo -e "\n${BOLD}Main Menu${NC}\n"
    echo -e "  ${CYAN}1)${NC} Setup Database Container (PostgreSQL + Redis)"
    echo -e "  ${CYAN}2)${NC} Setup Application Container"
    echo -e "  ${CYAN}3)${NC} Deploy Django Sample App"
    echo ""
    echo -e "  ${CYAN}4)${NC} List Containers"
    echo -e "  ${CYAN}5)${NC} Container Management ${YELLOW}▶${NC}"
    echo ""
    echo -e "  ${CYAN}6)${NC} System Update"
    echo -e "  ${CYAN}7)${NC} System Diagnostics (Doctor)"
    echo -e "  ${CYAN}8)${NC} Recovery Tools ${YELLOW}▶${NC}"
    echo ""
    echo -e "  ${CYAN}9)${NC} Web Interface ${YELLOW}▶${NC}"
    echo -e "  ${CYAN}10)${NC} Documentation"
    echo ""
    echo -e "  ${CYAN}0)${NC} Exit"
    echo ""
}

# Container management submenu
container_management_menu() {
    clear
    display_header
    echo -e "\n${BOLD}Container Management${NC}\n"
    echo -e "  ${CYAN}1)${NC} Start Container"
    echo -e "  ${CYAN}2)${NC} Stop Container"
    echo -e "  ${CYAN}3)${NC} Restart Container"
    echo -e "  ${CYAN}4)${NC} View Container Logs"
    echo -e "  ${CYAN}5)${NC} Execute Command in Container"
    echo -e "  ${CYAN}6)${NC} Attach to Container Shell"
    echo -e "  ${CYAN}7)${NC} Container Information"
    echo -e "  ${CYAN}8)${NC} Destroy Container"
    echo ""
    echo -e "  ${CYAN}0)${NC} Back to Main Menu"
    echo ""
    
    read -p "Select option: " choice
    
    case $choice in
        1) start_container ;;
        2) stop_container ;;
        3) restart_container ;;
        4) view_logs ;;
        5) exec_command ;;
        6) attach_shell ;;
        7) container_info ;;
        8) destroy_container ;;
        0) return ;;
        *) warning "Invalid option"; sleep 2; container_management_menu ;;
    esac
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

# Setup database container
setup_database() {
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
    
    # Create container
    log "Creating database container..."
    sudo lxc-create -n datastore -t ubuntu -- -r jammy
    
    # Configure container
    info "Configuring container..."
    cat <<EOF | sudo tee /var/lib/lxc/datastore/config > /dev/null
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
EOF
    
    # Start container
    log "Starting container..."
    sudo lxc-start -n datastore
    sleep 5
    
    # Install PostgreSQL and Redis
    info "Installing PostgreSQL and Redis..."
    sudo lxc-attach -n datastore -- apt-get update
    sudo lxc-attach -n datastore -- apt-get install -y postgresql redis-server
    
    # Configure PostgreSQL
    info "Configuring PostgreSQL..."
    sudo lxc-attach -n datastore -- sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
    sudo lxc-attach -n datastore -- sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/14/main/postgresql.conf
    sudo lxc-attach -n datastore -- sh -c "echo 'host all all 10.0.3.0/24 md5' >> /etc/postgresql/14/main/pg_hba.conf"
    
    # Configure Redis
    info "Configuring Redis..."
    sudo lxc-attach -n datastore -- sed -i "s/bind 127.0.0.1/bind 0.0.0.0/" /etc/redis/redis.conf
    
    # Restart services
    sudo lxc-attach -n datastore -- systemctl restart postgresql redis-server
    
    log "Database container setup complete!"
    log "PostgreSQL: 10.0.3.2:5432 (user: postgres, pass: postgres)"
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
    LAST_IP=$(sudo lxc-ls -f | awk '/10.0.3/ {print $5}' | cut -d. -f4 | cut -d/ -f1 | sort -n | tail -1)
    NEXT_IP=$((LAST_IP + 1))
    
    info "Assigning IP: 10.0.3.$NEXT_IP"
    
    cat <<EOF | sudo tee /var/lib/lxc/$app_name/config > /dev/null
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
EOF
    
    # Start and configure
    sudo lxc-start -n "$app_name"
    sleep 5
    
    info "Installing Python and dependencies..."
    sudo lxc-attach -n "$app_name" -- apt-get update
    sudo lxc-attach -n "$app_name" -- apt-get install -y python3 python3-pip python3-venv nginx supervisor
    
    log "Application container '$app_name' created successfully!"
    log "IP Address: 10.0.3.$NEXT_IP"
    log "App directory: /srv/apps/$app_name"
    
    read -p "Press Enter to continue..."
}

# Deploy Django sample
deploy_django_sample() {
    check_sudo
    
    if [[ -f /srv/lxc-compose/create-django-sample.sh ]]; then
        info "Deploying Django sample application..."
        sudo /srv/lxc-compose/create-django-sample.sh
    else
        error "Django sample script not found"
        info "Please ensure LXC Compose is properly installed"
    fi
    
    sleep 2
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
    
    if [[ -f /srv/lxc-compose/srv/lxc-compose/cli/doctor.py ]]; then
        read -p "Attempt to fix issues automatically? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            python3 /srv/lxc-compose/srv/lxc-compose/cli/doctor.py --fix
        else
            python3 /srv/lxc-compose/srv/lxc-compose/cli/doctor.py
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
    read -p "Enter container name: " name
    sudo lxc-start -n "$name"
    log "Container '$name' started"
    sleep 2
}

stop_container() {
    read -p "Enter container name: " name
    sudo lxc-stop -n "$name"
    log "Container '$name' stopped"
    sleep 2
}

restart_container() {
    read -p "Enter container name: " name
    sudo lxc-stop -n "$name"
    sudo lxc-start -n "$name"
    log "Container '$name' restarted"
    sleep 2
}

view_logs() {
    read -p "Enter container name: " name
    sudo lxc-console -n "$name" -t 0
}

exec_command() {
    read -p "Enter container name: " name
    read -p "Enter command: " cmd
    sudo lxc-attach -n "$name" -- $cmd
    sleep 2
}

attach_shell() {
    read -p "Enter container name: " name
    info "Attaching to container '$name'. Use Ctrl+A, Q to detach."
    sleep 2
    sudo lxc-attach -n "$name"
}

container_info() {
    read -p "Enter container name: " name
    sudo lxc-info -n "$name"
    sleep 2
}

destroy_container() {
    read -p "Enter container name: " name
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
    
    # Check status
    if pgrep -f "app.py" > /dev/null || pgrep -f "lxc-compose-manager" > /dev/null; then
        echo -e "  Status: ${GREEN}● Running${NC}"
        PID=$(pgrep -f "app.py" || pgrep -f "lxc-compose-manager")
        echo -e "  PID: $PID"
    else
        echo -e "  Status: ${RED}○ Stopped${NC}"
    fi
    
    # Get IP
    IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
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
        1) start_web_interface ;;
        2) stop_web_interface ;;
        3) restart_web_interface ;;
        4) view_web_logs ;;
        5) install_web_dependencies ;;
        0) return ;;
        *) warning "Invalid option"; sleep 2; web_interface_menu ;;
    esac
    
    sleep 2
    web_interface_menu  # Return to menu after action
}

# Start web interface
start_web_interface() {
    info "Starting web interface..."
    
    # Check if already running
    if pgrep -f "app.py" > /dev/null || pgrep -f "lxc-compose-manager" > /dev/null; then
        warning "Web interface is already running"
        PID=$(pgrep -f "app.py" || pgrep -f "lxc-compose-manager")
        info "PID: $PID"
        IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
        echo -e "  Access at: ${GREEN}http://$IP:5000${NC}"
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
    
    # Start the Flask app
    cd /srv/lxc-compose/lxc-compose-manager
    nohup python3 app.py > /srv/logs/manager.log 2>&1 &
    sleep 3
    
    # Check if started
    if pgrep -f "app.py" > /dev/null; then
        log "Web interface started successfully"
        IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
        echo -e "  Access at: ${GREEN}http://$IP:5000${NC}"
    else
        error "Failed to start web interface"
        echo "Check logs at: /srv/logs/manager.log"
    fi
}

# Stop web interface
stop_web_interface() {
    info "Stopping web interface..."
    
    # Check if running
    local was_running=false
    if pgrep -f "app.py" > /dev/null || pgrep -f "lxc-compose-manager" > /dev/null; then
        was_running=true
        
        # Try to kill both patterns
        pkill -f "app.py" 2>/dev/null || true
        pkill -f "lxc-compose-manager" 2>/dev/null || true
        
        # Give it time to stop
        sleep 2
        
        # Check if stopped
        if ! pgrep -f "app.py" > /dev/null && ! pgrep -f "lxc-compose-manager" > /dev/null; then
            log "Web interface stopped"
            return 0
        else
            # Try harder with SIGKILL
            pkill -9 -f "app.py" 2>/dev/null || true
            pkill -9 -f "lxc-compose-manager" 2>/dev/null || true
            sleep 1
            
            if ! pgrep -f "app.py" > /dev/null && ! pgrep -f "lxc-compose-manager" > /dev/null; then
                log "Web interface stopped (forced)"
                return 0
            else
                error "Failed to stop web interface"
                return 1
            fi
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
            1) setup_database ;;
            2) setup_application ;;
            3) deploy_django_sample ;;
            4) list_containers ;;
            5) container_management_menu ;;
            6) system_update ;;
            7) system_diagnostics ;;
            8) recovery_menu ;;
            9) web_interface_menu ;;
            10) show_documentation ;;
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