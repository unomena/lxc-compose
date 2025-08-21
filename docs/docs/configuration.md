# Configuration Reference

Complete reference for `lxc-compose.yml` configuration files.

## Table of Contents

- [Basic Structure](#basic-structure)
- [Container Configuration](#container-configuration)
- [Templates and Releases](#templates-and-releases)
- [Package Management](#package-management)
- [Mount Configuration](#mount-configuration)
- [Network Configuration](#network-configuration)
- [Service Definitions](#service-definitions)
- [Post-Install Commands](#post-install-commands)
- [Environment Variables](#environment-variables)
- [Container Dependencies](#container-dependencies)
- [Test Configuration](#test-configuration)
- [Log Configuration](#log-configuration)
- [Complete Example](#complete-example)

## Basic Structure

```yaml
version: "1.0"  # Required version string

containers:     # Container definitions
  container-name:
    # Container configuration
```

## Container Configuration

### Complete Container Options

```yaml
containers:
  container-name:
    # Base image configuration
    template: ubuntu              # Required: Base template
    release: jammy               # Required: Release version
    
    # Package management
    packages:                    # Optional: Packages to install
      - package1
      - package2
    
    # Networking
    exposed_ports:               # Optional: Ports accessible from host
      - 80
      - 443
    
    # File system
    mounts:                      # Optional: Directory/file mounts
      - source:target
      - ./local:/container
    
    # Dependencies
    depends_on:                  # Optional: Container dependencies
      - other-container
    
    # Services (Supervisor)
    services:                    # Optional: Service definitions
      service-name:
        command: /path/to/command
        # ... service options
    
    # Initialization
    post_install:                # Optional: Post-install commands
      - name: "Step name"
        command: |
          command to run
    
    # Logging
    logs:                        # Optional: Log definitions
      - name:/path/to/log
    
    # Testing
    tests:                       # Optional: Test configurations
      internal:
        - type:/path/to/test.sh
      external:
        - type:/path/to/test.sh
      port_forwarding:
        - type:/path/to/test.sh
```

## Templates and Releases

### Available Templates

| Template | Base Size | With Packages | Use Cases |
|----------|-----------|---------------|-----------|
| alpine | ~5MB | ~150MB | Databases, caches, minimal services |
| ubuntu-minimal | ~100MB | ~300MB | Applications, balanced size |
| ubuntu | ~500MB | ~1GB+ | Development, complex apps |

### Template Examples

```yaml
# Alpine - for databases and caches
template: alpine
release: "3.19"

# Ubuntu Minimal - for applications
template: ubuntu-minimal
release: lts

# Ubuntu Full - for development
template: ubuntu
release: jammy
```

## Package Management

Packages are installed based on the container's package manager:

```yaml
packages:
  # Alpine uses apk
  - postgresql
  - redis
  
  # Ubuntu uses apt
  - python3
  - python3-pip
  - nginx
```

## Mount Configuration

### Mount Formats

```yaml
# String format
mounts:
  - "./src:/app"
  - "/host/path:/container/path"

# Object format
mounts:
  - source: ./src
    target: /app
```

## Network Configuration

### Exposed Ports

Only exposed ports are accessible from the host:

```yaml
exposed_ports:
  - 80     # HTTP
  - 443    # HTTPS
  - 8080   # Alternative HTTP
```

## Service Definitions

Services are managed by Supervisor:

```yaml
services:
  web:
    command: /app/venv/bin/python app.py
    directory: /app
    user: www-data
    autostart: true
    autorestart: true
    stdout_logfile: /var/log/app.log
    stderr_logfile: /var/log/app_error.log
```

## Post-Install Commands

Commands run after container creation:

```yaml
post_install:
  - name: "Setup database"
    command: |
      createdb myapp
      createuser myuser
  
  - name: "Install dependencies"
    command: |
      cd /app
      pip install -r requirements.txt
```

## Environment Variables

### Using .env Files

Create `.env` file in project root:

```env
DB_HOST=myapp-database
DB_PORT=5432
DB_NAME=myapp
DB_USER=appuser
DB_PASSWORD=secure_password
```

### Variable Expansion

```yaml
mounts:
  - ${DATA_DIR:-./data}:/var/lib/data

post_install:
  - name: "Create database"
    command: |
      createdb ${DB_NAME}
```

## Container Dependencies

```yaml
containers:
  database:
    template: alpine
    release: "3.19"
  
  app:
    template: ubuntu-minimal
    release: lts
    depends_on:
      - database  # Start after database
```

## Test Configuration

```yaml
tests:
  internal:           # Tests run inside container
    - health:/app/tests/internal_test.sh
  
  external:          # Tests run from host
    - connectivity:/app/tests/external_test.sh
  
  port_forwarding:   # iptables verification
    - security:/app/tests/port_test.sh
```

## Log Configuration

```yaml
logs:
  - app:/var/log/app.log
  - nginx:/var/log/nginx/access.log
  - error:/var/log/app/error.log
```

## Complete Example

```yaml
version: "1.0"

containers:
  # Database container
  myapp-db:
    template: alpine
    release: "3.19"
    packages:
      - postgresql
      - redis
    mounts:
      - ./data:/var/lib/postgresql/data
    post_install:
      - name: "Setup PostgreSQL"
        command: |
          su postgres -c "initdb -D /var/lib/postgresql/data"
          su postgres -c "pg_ctl start -D /var/lib/postgresql/data"
          su postgres -c "createdb ${DB_NAME}"

  # Application container
  myapp-web:
    template: ubuntu-minimal
    release: lts
    depends_on:
      - myapp-db
    packages:
      - python3
      - python3-pip
      - nginx
    exposed_ports:
      - 80
      - 443
    mounts:
      - .:/app
    services:
      app:
        command: /app/venv/bin/gunicorn app:application
        directory: /app
        user: www-data
        autostart: true
        autorestart: true
        stdout_logfile: /var/log/app.log
    logs:
      - app:/var/log/app.log
      - nginx:/var/log/nginx/access.log
    tests:
      internal:
        - health:/app/tests/health.sh
    post_install:
      - name: "Setup Python environment"
        command: |
          cd /app
          python3 -m venv venv
          ./venv/bin/pip install -r requirements.txt
```

## See Also

- [Commands Reference](commands.md)
- [Testing Guide](testing.md)
- [Networking Guide](networking.md)
- [Standards Guide](standards.md)