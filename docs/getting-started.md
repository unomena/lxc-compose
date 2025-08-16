# Getting Started with LXC Compose

This guide will help you install LXC Compose and create your first multi-container application.

## Table of Contents
- [Installation](#installation)
- [Prerequisites](#prerequisites)
- [Your First Application](#first-app)
- [Basic Commands](#basic-commands)
- [Next Steps](#next-steps)

## Installation

### Quick Install (Recommended)

```bash
# Download and run the installer
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/install.sh | sudo bash

# Verify installation
lxc-compose --version
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/unomena/lxc-compose.git
cd lxc-compose

# Run the installer
sudo ./install.sh

# Or use the interactive wizard
sudo ./wizard.sh
```

### Post-Installation

After installation, LXC Compose will:
- Install LXC/LXD if not present
- Configure the bridge network (10.0.3.0/24)
- Set up the directory structure in `/srv/`
- Create command symlinks in `/usr/local/bin/`

## Prerequisites

### System Requirements

- **Operating System**: Ubuntu 22.04/24.04 or Debian 11/12
- **Architecture**: x86_64 (amd64)
- **Memory**: Minimum 2GB RAM (4GB+ recommended)
- **Storage**: 10GB+ free space for containers
- **Network**: Internet connection for downloading containers

### Required Permissions

LXC Compose requires sudo/root access to:
- Create and manage LXC containers
- Configure network bridges
- Modify `/etc/hosts` for hostname resolution
- Set up port forwarding rules

## Your First Application {#first-app}

Let's create a simple web application with a database.

### Step 1: Create Project Directory

```bash
mkdir myapp && cd myapp
```

### Step 2: Create lxc-compose.yml

Create a file named `lxc-compose.yml` with the following content:

```yaml
version: '1.0'

containers:
  # Database container
  myapp-db:
    template: ubuntu
    release: jammy
    
    # Port forwarding
    ports:
      - 5432:5432  # PostgreSQL
    
    # Packages to install
    packages:
      - postgresql
      - postgresql-contrib
    
    # Environment variables
    environment:
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: secret123
      POSTGRES_DB: myapp_db

  # Application container
  myapp-web:
    template: ubuntu
    release: jammy
    
    # Dependencies - starts after myapp-db
    depends_on:
      - myapp-db
    
    # Port forwarding
    ports:
      - 8080:80   # Nginx
      - 3000:3000 # Node.js app
    
    # Mount current directory into container
    mounts:
      - .:/app
    
    # Packages to install
    packages:
      - nodejs
      - npm
      - nginx
    
    # Environment variables
    environment:
      NODE_ENV: development
      DATABASE_URL: postgresql://myapp:secret123@myapp-db:5432/myapp_db
```

### Step 3: Start the Application

```bash
# Start all containers
lxc-compose up

# Or run in background (detached)
lxc-compose up -d
```

### Step 4: Verify Everything is Running

```bash
# Check container status
lxc-compose ps

# Output:
# Name                    State      IP
# --------------------------------------------------
# myapp-db               RUNNING    10.0.3.11
# myapp-web              RUNNING    10.0.3.12
```

### Step 5: Access Your Application

- **Web Application**: http://localhost:8080
- **PostgreSQL**: localhost:5432
- **Node.js App**: http://localhost:3000

### Step 6: Execute Commands in Containers

```bash
# Access the web container
lxc-compose exec myapp-web bash

# Run database commands
lxc-compose exec myapp-db psql -U myapp -d myapp_db

# Check nginx status
lxc-compose exec myapp-web systemctl status nginx
```

### Step 7: Stop the Application

```bash
# Stop all containers
lxc-compose down

# Stop and remove containers (careful!)
lxc-compose down -v
```

## Basic Commands

### Container Lifecycle

```bash
# Start containers
lxc-compose up              # Foreground with logs
lxc-compose up -d           # Background (detached)
lxc-compose up --build      # Rebuild containers

# Stop containers
lxc-compose down            # Stop containers
lxc-compose down -v         # Stop and remove

# Restart containers
lxc-compose restart         # Restart all
lxc-compose restart myapp-web  # Restart specific container
```

### Monitoring and Debugging

```bash
# List containers
lxc-compose ps              # Show status
lxc-compose list           # Detailed list

# View logs
lxc-compose logs           # All containers
lxc-compose logs myapp-web # Specific container
lxc-compose logs -f        # Follow logs

# Execute commands
lxc-compose exec myapp-web bash           # Interactive shell
lxc-compose exec myapp-web ls -la /app    # Run command
```

### Container Management

```bash
# Attach to container
lxc-compose attach myapp-web

# Stop specific container
lxc-compose stop myapp-web

# Start specific container
lxc-compose start myapp-web

# Remove specific container
lxc-compose rm myapp-web
```

## Container Naming Best Practices

### Use Project Namespaces

Container names must be globally unique. Always use project namespaces:

```yaml
# Good - namespaced
containers:
  myproject-db:
  myproject-cache:
  myproject-worker:
  myproject-web:

# Bad - will conflict with other projects
containers:
  db:
  redis:
  worker:
  web:
```

### Naming Patterns

Choose a consistent naming pattern:

```yaml
# Pattern 1: project-service
todoapp-db:
todoapp-api:
todoapp-frontend:

# Pattern 2: reverse domain
com-example-db:
com-example-api:
com-example-web:

# Pattern 3: environment prefix
prod-userservice-db:
prod-userservice-api:
staging-userservice-db:
```

## Working with Mounts

### Development Workflow

Mount your code directory for live updates:

```yaml
containers:
  myapp-dev:
    mounts:
      - .:/app                    # Current directory
      - ./config:/etc/myapp       # Config files
      - /var/log/host:/var/log    # Shared logs
```

Changes to files on the host are immediately visible in the container.

### Production Deployment

For production, consider cloning from git:

```bash
# Clone application on host
git clone https://github.com/user/myapp.git /srv/apps/myapp

# Mount in container
mounts:
  - /srv/apps/myapp:/app
```

## Environment Variables

### Setting Variables

```yaml
containers:
  myapp-web:
    environment:
      NODE_ENV: production
      API_KEY: "secret-key-123"
      DATABASE_URL: "postgresql://user:pass@myapp-db:5432/db"
```

### Using .env Files

Create a `.env` file in your project:

```bash
DEBUG=true
DATABASE_PASSWORD=secret123
API_KEY=your-api-key
```

Reference in your configuration:

```yaml
containers:
  myapp-web:
    environment:
      DEBUG: "${DEBUG}"
      DATABASE_PASSWORD: "${DATABASE_PASSWORD}"
      API_KEY: "${API_KEY}"
```

## Port Forwarding

### Basic Syntax

```yaml
ports:
  - 8080:80    # host:container
  - 3000:3000  # same port on both
```

### Multiple Services

```yaml
containers:
  myapp-services:
    ports:
      - 80:80      # Nginx
      - 443:443    # HTTPS
      - 3000:3000  # API
      - 5432:5432  # PostgreSQL
      - 6379:6379  # Redis
```

## Dependencies

### Sequential Startup

Containers start in dependency order:

```yaml
containers:
  myapp-db:
    # Starts first (no dependencies)
    
  myapp-cache:
    # Starts second
    depends_on:
      - myapp-db
      
  myapp-web:
    # Starts last
    depends_on:
      - myapp-db
      - myapp-cache
```

## Next Steps

Now that you have LXC Compose running:

1. **Explore Configuration**: Read the [Configuration Reference](configuration.md)
2. **Learn Advanced Features**: Check out [Advanced Topics](advanced/index.md)
3. **Deploy to Production**: See [Production Deployment](production.md)
4. **Migrate Existing Apps**: Follow [Docker Compose Migration](docker-compose-migration.md)
5. **Troubleshoot Issues**: Consult [Troubleshooting Guide](troubleshooting.md)

## Getting Help

- Run `lxc-compose --help` for command reference
- Check [examples/](https://github.com/unomena/lxc-compose/tree/main/examples) for sample configurations
- Report issues on [GitHub](https://github.com/unomena/lxc-compose/issues)