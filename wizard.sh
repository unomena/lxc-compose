#!/bin/bash

#############################################################################
# LXC Compose Setup Wizard
# Interactive configuration for database, cache, and application containers
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
error() { echo -e "${RED}[✗]${NC} $1" >&2; exit 1; }
warning() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
question() { echo -e "${CYAN}[?]${NC} $1"; }

# Default values
DEFAULT_DATASTORE_IP="10.0.3.2"
DEFAULT_APP_IP_START="10.0.3.11"
POSTGRES_VERSIONS=("14" "15" "16")
REDIS_VERSIONS=("6" "7")

# Check if LXC Compose is installed
check_installation() {
    if [[ ! -d /srv/lxc-compose ]]; then
        error "LXC Compose is not installed. Please run: curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash"
    fi
    
    if [[ ! -f /srv/lxc-compose/scripts/create-container.sh ]]; then
        error "LXC Compose scripts not found. Please reinstall."
    fi
    
    log "LXC Compose installation verified"
}

# Display welcome message
welcome() {
    clear
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║           LXC Compose Setup Wizard                           ║"
    echo "║     Configure Database, Cache, and Application Containers    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    info "This wizard will help you set up your containerized environment"
    echo ""
}

# Ask yes/no question
ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local response
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -p "$(echo -e "${CYAN}[?]${NC} $prompt")" response
    response=${response:-$default}
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Get user input with default
get_input() {
    local prompt="$1"
    local default="$2"
    local response
    
    read -p "$(echo -e "${CYAN}[?]${NC} $prompt [$default]: ")" response
    echo "${response:-$default}"
}

# Select from options
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local choice
    
    echo -e "${CYAN}[?]${NC} $prompt"
    select opt in "${options[@]}"; do
        if [[ -n "$opt" ]]; then
            echo "$opt"
            return
        fi
    done
}

# Create datastore container
create_datastore() {
    local container_name="$1"
    local container_ip="$2"
    local install_postgres="$3"
    local install_redis="$4"
    local postgres_version="${5:-}"
    local redis_version="${6:-}"
    
    log "Creating datastore container '$container_name' at IP $container_ip..."
    
    # Create the container
    /srv/lxc-compose/scripts/create-container.sh "$container_name" "$container_ip" database
    
    # Start the container
    log "Starting container..."
    sudo lxc-start -n "$container_name"
    sleep 5
    
    # Configure DNS
    log "Configuring container network..."
    sudo lxc-attach -n "$container_name" -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
    sudo lxc-attach -n "$container_name" -- bash -c "echo 'nameserver 1.1.1.1' >> /etc/resolv.conf"
    
    # Update and install base packages
    log "Updating container packages..."
    sudo lxc-attach -n "$container_name" -- apt-get update
    sudo lxc-attach -n "$container_name" -- DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    sudo lxc-attach -n "$container_name" -- DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl wget vim htop sudo systemd systemd-sysv ca-certificates gnupg lsb-release
    
    # Install PostgreSQL if requested
    if [[ "$install_postgres" == "true" ]]; then
        log "Installing PostgreSQL${postgres_version:+ version $postgres_version}..."
        
        if [[ -n "$postgres_version" ]] && [[ "$postgres_version" != "default" ]]; then
            # Install specific version from PostgreSQL repo
            sudo lxc-attach -n "$container_name" -- bash -c "
                curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
                echo 'deb http://apt.postgresql.org/pub/repos/apt \$(lsb_release -cs)-pgdg main' > /etc/apt/sources.list.d/pgdg.list
                apt-get update
                DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql-$postgres_version postgresql-client-$postgres_version postgresql-contrib-$postgres_version
            "
            local pg_version="$postgres_version"
        else
            # Install default Ubuntu version
            sudo lxc-attach -n "$container_name" -- DEBIAN_FRONTEND=noninteractive apt-get install -y \
                postgresql postgresql-client postgresql-contrib
            local pg_version=$(sudo lxc-attach -n "$container_name" -- ls /etc/postgresql/ | head -1)
        fi
        
        # Configure PostgreSQL
        log "Configuring PostgreSQL..."
        sudo lxc-attach -n "$container_name" -- bash -c "
            echo \"listen_addresses = '*'\" >> /etc/postgresql/$pg_version/main/postgresql.conf
            echo \"host all all 10.0.3.0/24 md5\" >> /etc/postgresql/$pg_version/main/pg_hba.conf
            systemctl restart postgresql
        "
        
        log "PostgreSQL $pg_version installed and configured"
    fi
    
    # Install Redis if requested
    if [[ "$install_redis" == "true" ]]; then
        log "Installing Redis${redis_version:+ version $redis_version}..."
        
        if [[ -n "$redis_version" ]] && [[ "$redis_version" != "default" ]]; then
            # Install specific version from Redis repo
            sudo lxc-attach -n "$container_name" -- bash -c "
                curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/redis.gpg
                echo 'deb https://packages.redis.io/deb \$(lsb_release -cs) main' > /etc/apt/sources.list.d/redis.list
                apt-get update
                DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server=$redis_version* redis-tools=$redis_version*
            " || {
                warning "Specific Redis version not available, installing default"
                sudo lxc-attach -n "$container_name" -- DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server redis-tools
            }
        else
            # Install default Ubuntu version
            sudo lxc-attach -n "$container_name" -- DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server redis-tools
        fi
        
        # Configure Redis
        log "Configuring Redis..."
        sudo lxc-attach -n "$container_name" -- bash -c "
            sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis/redis.conf
            sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
            systemctl restart redis-server
        "
        
        log "Redis installed and configured"
    fi
    
    # Show status
    log "Datastore container '$container_name' created successfully!"
    info "Container IP: $container_ip"
    
    if [[ "$install_postgres" == "true" ]]; then
        info "PostgreSQL: $container_ip:5432"
        info "Create database: sudo lxc-attach -n $container_name -- sudo -u postgres createdb dbname"
        info "Create user: sudo lxc-attach -n $container_name -- sudo -u postgres createuser username"
    fi
    
    if [[ "$install_redis" == "true" ]]; then
        info "Redis: $container_ip:6379"
        info "Test Redis: sudo lxc-attach -n $container_name -- redis-cli ping"
    fi
}

# Create application container
create_app_container() {
    local container_name="$1"
    local container_ip="$2"
    
    log "Creating application container '$container_name' at IP $container_ip..."
    
    # Create the container
    /srv/lxc-compose/scripts/create-container.sh "$container_name" "$container_ip" app
    
    # Start the container
    log "Starting container..."
    sudo lxc-start -n "$container_name"
    sleep 5
    
    # Configure DNS
    log "Configuring container network..."
    sudo lxc-attach -n "$container_name" -- bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
    
    # Run setup script if it exists
    log "Setting up application environment..."
    if sudo lxc-attach -n "$container_name" -- test -f /srv/app/setup-container-internal.sh; then
        sudo lxc-attach -n "$container_name" -- /srv/app/setup-container-internal.sh app
    else
        # Manual setup if script doesn't exist
        sudo lxc-attach -n "$container_name" -- bash -c "
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip python3-venv nginx supervisor
        "
    fi
    
    log "Application container '$container_name' created successfully!"
    info "Container IP: $container_ip"
}

# Main wizard flow
main() {
    welcome
    check_installation
    
    # Configuration variables
    local setup_datastore
    local datastore_name="datastore"
    local datastore_ip="$DEFAULT_DATASTORE_IP"
    local separate_db_cache
    local install_postgres
    local install_redis
    local postgres_version=""
    local redis_version=""
    local setup_apps
    local num_apps
    
    # Ask about datastore
    if ask_yes_no "Do you want to set up a datastore container (database/cache)?"; then
        setup_datastore=true
        
        datastore_name=$(get_input "Enter datastore container name" "datastore")
        datastore_ip=$(get_input "Enter datastore container IP" "$DEFAULT_DATASTORE_IP")
        
        if ask_yes_no "Do you want to install PostgreSQL?"; then
            install_postgres=true
            if ask_yes_no "Do you want to choose a specific PostgreSQL version?" "n"; then
                postgres_version=$(select_option "Select PostgreSQL version:" "${POSTGRES_VERSIONS[@]}" "default")
            fi
        else
            install_postgres=false
        fi
        
        if ask_yes_no "Do you want to install Redis?"; then
            install_redis=true
            if ask_yes_no "Do you want to choose a specific Redis version?" "n"; then
                redis_version=$(select_option "Select Redis version:" "${REDIS_VERSIONS[@]}" "default")
            fi
        else
            install_redis=false
        fi
        
        if [[ "$install_postgres" == "true" ]] && [[ "$install_redis" == "true" ]]; then
            if ask_yes_no "Do you want PostgreSQL and Redis in separate containers?" "n"; then
                separate_db_cache=true
                warning "Separate containers for DB and cache not yet implemented. Using single datastore container."
                separate_db_cache=false
            else
                separate_db_cache=false
            fi
        fi
    else
        setup_datastore=false
    fi
    
    # Ask about application containers
    if ask_yes_no "Do you want to set up application containers?"; then
        setup_apps=true
        num_apps=$(get_input "How many application containers?" "1")
        
        # Validate number
        if ! [[ "$num_apps" =~ ^[0-9]+$ ]] || [[ "$num_apps" -lt 1 ]]; then
            warning "Invalid number, defaulting to 1"
            num_apps=1
        fi
    else
        setup_apps=false
    fi
    
    # Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    info "Configuration Summary:"
    echo "═══════════════════════════════════════════════════════════════"
    
    if [[ "$setup_datastore" == "true" ]]; then
        info "Datastore Container:"
        echo "  Name: $datastore_name"
        echo "  IP: $datastore_ip"
        [[ "$install_postgres" == "true" ]] && echo "  PostgreSQL: ${postgres_version:-default version}"
        [[ "$install_redis" == "true" ]] && echo "  Redis: ${redis_version:-default version}"
    fi
    
    if [[ "$setup_apps" == "true" ]]; then
        info "Application Containers: $num_apps"
    fi
    
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    if ! ask_yes_no "Proceed with this configuration?"; then
        warning "Setup cancelled"
        exit 0
    fi
    
    # Execute setup
    echo ""
    log "Starting container setup..."
    echo ""
    
    # Create datastore
    if [[ "$setup_datastore" == "true" ]]; then
        create_datastore "$datastore_name" "$datastore_ip" "$install_postgres" "$install_redis" "$postgres_version" "$redis_version"
        echo ""
    fi
    
    # Create application containers
    if [[ "$setup_apps" == "true" ]]; then
        local app_ip_base=11
        for ((i=1; i<=num_apps; i++)); do
            local app_name="app-$i"
            local app_ip="10.0.3.$app_ip_base"
            create_app_container "$app_name" "$app_ip"
            ((app_ip_base++))
            echo ""
        done
    fi
    
    # Final summary
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                Setup Complete! ✓                             ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Show running containers
    log "Running containers:"
    sudo lxc-ls --fancy
    echo ""
    
    # Show next steps
    info "Next steps:"
    if [[ "$setup_datastore" == "true" ]]; then
        echo "  - Configure database users and permissions"
        echo "  - Update application connection strings to use $datastore_ip"
    fi
    if [[ "$setup_apps" == "true" ]]; then
        echo "  - Deploy your application code to /srv/apps/app-*/code/"
        echo "  - Configure environment variables in /srv/apps/app-*/secrets.env"
    fi
    echo ""
    info "Use 'lxcc-list' to view all containers"
    info "Use 'lxcc-manage attach <container>' to enter a container"
}

# Run main function
main "$@"