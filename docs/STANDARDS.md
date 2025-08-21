# LXC Compose Standards

Comprehensive standards and best practices for LXC Compose projects.

## Table of Contents

- [Container Naming](#container-naming)
- [Base Images](#base-images)
- [Directory Structure](#directory-structure)
- [Configuration Standards](#configuration-standards)
- [Services Configuration](#services-configuration)
- [Package Management](#package-management)
- [Environment Variables](#environment-variables)
- [Mount Standards](#mount-standards)
- [Networking Standards](#networking-standards)
- [Testing Standards](#testing-standards)
- [Security Standards](#security-standards)
- [Documentation Standards](#documentation-standards)
- [Version Control](#version-control)

## Container Naming

### Naming Conventions

- **Use lowercase**: All container names must be lowercase
- **Use hyphens**: Separate words with hyphens, not underscores
- **Be descriptive**: Names should clearly indicate purpose
- **Keep it short**: Maximum 20 characters recommended
- **Use prefixes**: Group related containers with common prefix

### Examples

```yaml
# Good naming
containers:
  myapp-web:        # Clear role
  myapp-db:         # Related to myapp
  myapp-cache:      # Obvious purpose
  myapp-worker:     # Descriptive function

# Bad naming
containers:
  container1:       # Not descriptive
  my_app_server:    # Uses underscores
  ProductionWebServerInstance:  # Too long, mixed case
  ws:              # Too abbreviated
```

### Multi-Container Applications

Use consistent prefixing for related containers:

```yaml
containers:
  # E-commerce application
  shop-frontend:
  shop-api:
  shop-database:
  shop-cache:
  shop-queue:
  shop-worker:
```

## Base Images

### Image Selection Guide

| Template | Base Size | With Packages | Primary Use Cases |
|----------|-----------|---------------|-------------------|
| alpine | ~5MB | ~150MB | Databases, caches, minimal services |
| ubuntu-minimal | ~100MB | ~300MB | Applications, balanced size/compatibility |
| ubuntu | ~500MB | ~1GB+ | Development, complex requirements |

### Alpine Linux (~150MB)

**When to use:**
- Database servers (PostgreSQL, MySQL, MariaDB)
- Cache servers (Redis, Memcached)
- Message queues (RabbitMQ, Kafka)
- Minimal microservices
- Static file servers

**Advantages:**
- Minimal attack surface
- Fast container startup
- Low memory footprint
- Efficient storage usage

**Example:**
```yaml
containers:
  datastore:
    template: alpine
    release: "3.19"
    packages:
      - postgresql
      - redis
```

### Ubuntu Minimal (~300MB)

**When to use:**
- Python applications
- Node.js applications
- Ruby applications
- Go applications
- Java microservices

**Advantages:**
- Good compatibility
- Reasonable size
- Full apt package availability
- Better library support than Alpine

**Example:**
```yaml
containers:
  app:
    template: ubuntu-minimal
    release: lts
    packages:
      - python3
      - python3-pip
      - nginx
```

### Ubuntu Full (~500MB+)

**When to use:**
- Development environments
- Complex applications
- Legacy applications
- When debugging tools needed
- Full desktop environments

**Advantages:**
- Complete Ubuntu experience
- All packages available
- Best compatibility
- Full debugging tools

**Example:**
```yaml
containers:
  dev:
    template: ubuntu
    release: jammy
    packages:
      - build-essential
      - git
      - vim
      - curl
```

## Directory Structure

### Standard Project Layout

```
project/
├── lxc-compose.yml         # Main configuration
├── lxc-compose.dev.yml     # Development overrides
├── lxc-compose.prod.yml    # Production configuration
├── .env                    # Environment variables
├── .env.example            # Example environment file
├── Makefile               # Build automation
├── README.md              # Project documentation
├── LICENSE                # License file
├── .gitignore             # Version control ignores
│
├── config/                # Configuration files
│   ├── nginx/
│   │   ├── nginx.conf
│   │   └── sites/
│   ├── supervisor/
│   │   └── supervisord.conf
│   ├── database/
│   │   ├── postgresql.conf
│   │   └── redis.conf
│   └── app/
│       └── settings.py
│
├── src/                   # Application source code
│   ├── app/
│   ├── lib/
│   └── static/
│
├── scripts/               # Utility scripts
│   ├── backup.sh
│   ├── deploy.sh
│   └── migrate.sh
│
├── tests/                 # Test suites
│   ├── unit/
│   ├── integration/
│   ├── internal/
│   │   ├── health_check.sh
│   │   └── service_test.sh
│   ├── external/
│   │   ├── api_test.sh
│   │   └── web_test.sh
│   └── port_forwarding/
│       └── security_test.sh
│
├── data/                  # Persistent data (gitignored)
│   ├── postgres/
│   ├── redis/
│   └── uploads/
│
├── logs/                  # Application logs (gitignored)
│   ├── app/
│   ├── nginx/
│   └── database/
│
└── docs/                  # Documentation
    ├── architecture.md
    ├── api.md
    └── deployment.md
```

### Directory Purposes

- **config/**: All configuration files, organized by service
- **src/**: Application source code
- **scripts/**: Automation and utility scripts
- **tests/**: All test files, organized by type
- **data/**: Persistent data (excluded from version control)
- **logs/**: Log files (excluded from version control)
- **docs/**: Project documentation

## Configuration Standards

### YAML File Organization

```yaml
# 1. Version declaration
version: "1.0"

# 2. Container definitions
containers:
  container-name:
    # Base configuration
    template: ubuntu-minimal
    release: lts
    
    # Dependencies
    depends_on:
      - other-container
    
    # Packages
    packages:
      - package1
      - package2
    
    # Networking
    exposed_ports:
      - 80
      - 443
    
    # Mounts
    mounts:
      - ./src:/app
      - ./config:/config
    
    # Services
    services:
      service-name:
        command: /path/to/command
    
    # Logs
    logs:
      - app:/var/log/app.log
    
    # Tests
    tests:
      internal:
        - health:/tests/health.sh
    
    # Post-install
    post_install:
      - name: "Setup"
        command: |
          echo "Setup commands"
```

### Configuration File Naming

- `lxc-compose.yml` - Default/development configuration
- `lxc-compose.dev.yml` - Development overrides
- `lxc-compose.test.yml` - Testing configuration
- `lxc-compose.staging.yml` - Staging environment
- `lxc-compose.prod.yml` - Production configuration

## Services Configuration

### Service Definition Standards

Services should be defined inline in `lxc-compose.yml` using the `services:` section:

```yaml
services:
  # Web server
  web:
    command: /app/venv/bin/gunicorn app:application
    directory: /app
    user: www-data
    autostart: true
    autorestart: true
    startsecs: 10
    stopwaitsecs: 30
    stdout_logfile: /var/log/app/gunicorn.log
    stderr_logfile: /var/log/app/gunicorn_error.log
    environment: |
      PORT=8000
      WORKERS=4
  
  # Background worker
  worker:
    command: /app/venv/bin/celery -A app worker
    directory: /app
    user: www-data
    autostart: true
    autorestart: true
    stopwaitsecs: 600  # Allow time for job completion
    stdout_logfile: /var/log/app/worker.log
    stderr_logfile: /var/log/app/worker_error.log
  
  # Scheduler
  scheduler:
    command: /app/venv/bin/celery -A app beat
    directory: /app
    user: www-data
    autostart: true
    autorestart: true
    stdout_logfile: /var/log/app/scheduler.log
```

### Service Types

#### Application Services (via Supervisor)
- Django/Flask applications
- Celery workers
- Celery beat schedulers
- Custom application daemons

#### System Services (run directly)
- PostgreSQL (`pg_ctl`)
- Redis (`redis-server --daemonize yes`)
- Nginx (`service nginx start`)
- MongoDB (`mongod`)

**Important**: System services should NOT be managed by Supervisor. They should run as daemons.

### Service Naming Conventions

- Use descriptive names: `web`, `api`, `worker`, `scheduler`
- Avoid generic names: `app`, `service`, `process`
- Use lowercase with no separators
- Keep names under 15 characters

### Service User Management

```yaml
post_install:
  - name: "Create service user"
    command: |
      useradd -r -s /bin/false www-data || true
      chown -R www-data:www-data /app
```

## Package Management

### Package Organization

```yaml
packages:
  # System packages first
  - curl
  - git
  - supervisor
  
  # Runtime packages
  - python3
  - python3-pip
  - python3-venv
  
  # Application packages
  - nginx
  - postgresql-client
  - redis-tools
  
  # Development packages last
  - build-essential
  - python3-dev
```

### Package Selection Guidelines

1. **Minimize packages**: Only install what's needed
2. **Group related**: Keep related packages together
3. **Document purpose**: Comment why packages are needed
4. **Version pinning**: Use specific versions in production
5. **Security updates**: Regularly update packages

### Language-Specific Standards

#### Python Applications
```yaml
packages:
  - python3
  - python3-pip
  - python3-venv
  - python3-dev
  - build-essential  # For compiled packages
  - libpq-dev        # For psycopg2
```

#### Node.js Applications
```yaml
packages:
  - nodejs
  - npm
  - build-essential  # For native modules
```

#### Ruby Applications
```yaml
packages:
  - ruby
  - ruby-dev
  - bundler
  - build-essential
```

## Environment Variables

### Environment File Structure

```env
# .env file

# Application Settings
APP_ENV=development
APP_DEBUG=true
APP_URL=http://localhost

# Database Configuration
DB_HOST=myapp-database
DB_PORT=5432
DB_NAME=myapp
DB_USER=appuser
DB_PASSWORD=secure_password_here

# Redis Configuration
REDIS_HOST=myapp-cache
REDIS_PORT=6379
REDIS_PASSWORD=redis_password_here

# Security
SECRET_KEY=your-secret-key-here
API_KEY=your-api-key-here

# External Services
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USER=mail@example.com
MAIL_PASSWORD=mail_password_here

# Feature Flags
ENABLE_FEATURE_X=true
ENABLE_FEATURE_Y=false

# Admin
ADMIN_USER=admin
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=admin123
```

### Environment Variable Naming

- Use UPPERCASE with underscores
- Prefix with application name for clarity
- Group related variables
- Document each variable's purpose

### Security Best Practices

1. Never commit `.env` files with real credentials
2. Provide `.env.example` with dummy values
3. Use strong, unique passwords
4. Rotate credentials regularly
5. Use different credentials per environment

## Mount Standards

### Mount Organization

```yaml
mounts:
  # Application code
  - ./src:/app
  
  # Configuration files
  - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf
  - ./config/supervisor:/etc/supervisor/conf.d
  
  # Data volumes
  - ./data/postgres:/var/lib/postgresql/data
  - ./data/uploads:/app/uploads
  
  # Log volumes
  - ./logs:/var/log/app
```

### Mount Types

1. **Code Mounts**: Development only, not for production
2. **Config Mounts**: Specific configuration files
3. **Data Mounts**: Persistent data storage
4. **Log Mounts**: Centralized logging

### Mount Best Practices

- Use relative paths for portability
- Mount specific files, not entire directories when possible
- Set proper permissions in post_install
- Document what each mount is for
- Minimize mounts in production

## Networking Standards

### Port Allocation

```yaml
# Standard port ranges
exposed_ports:
  # Web servers
  - 80    # HTTP
  - 443   # HTTPS
  
  # Application servers
  - 3000  # Node.js
  - 5000  # Flask
  - 8000  # Django
  - 8080  # Alternative HTTP
  
  # Databases (only if external access needed)
  - 5432  # PostgreSQL
  - 3306  # MySQL
  - 27017 # MongoDB
  
  # Caching (only if external access needed)
  - 6379  # Redis
  - 11211 # Memcached
```

### Internal Communication

```yaml
# Use container names for internal communication
environment:
  DATABASE_URL: postgresql://user:pass@myapp-db:5432/dbname
  REDIS_URL: redis://myapp-cache:6379/0
  API_ENDPOINT: http://myapp-api:8000
```

### Security Guidelines

1. Only expose necessary ports
2. Use HTTPS for external traffic
3. Keep databases internal
4. Use reverse proxy for applications
5. Implement rate limiting

**Note**: Don't expose application ports (like 8000 for Django) if nginx is proxying.

## Testing Standards

### Test Organization

```bash
tests/
├── unit/              # Unit tests (language-specific)
├── integration/       # Integration tests
├── internal/         # Container internal tests
│   ├── health_check.sh
│   ├── service_test.sh
│   └── config_test.sh
├── external/         # External connectivity tests
│   ├── api_test.sh
│   ├── web_test.sh
│   └── ssl_test.sh
└── port_forwarding/  # Security tests
    ├── iptables_test.sh
    └── security_audit.sh
```

### Test Configuration

```yaml
tests:
  internal:
    - health:/app/tests/health_check.sh
    - services:/app/tests/service_test.sh
  external:
    - api:/app/tests/api_test.sh
    - web:/app/tests/web_test.sh
  port_forwarding:
    - security:/app/tests/security_test.sh
```

### Test Requirements

1. All containers must have health checks
2. External endpoints must be tested
3. Port forwarding must be verified
4. Tests must be idempotent
5. Tests must exit with proper codes

### Health Check Example

```bash
#!/bin/bash
# health_check.sh

# Check service is running
pgrep -x "nginx" > /dev/null || exit 1

# Check port is listening
netstat -tln | grep ":80 " > /dev/null || exit 1

# Check application responds
curl -f http://localhost/health > /dev/null || exit 1

exit 0
```

## Security Standards

### Container Security

```yaml
# Run as non-root user
services:
  app:
    user: www-data
    
post_install:
  - name: "Create non-root user"
    command: |
      useradd -r -s /bin/false appuser
      chown -R appuser:appuser /app
```

### Secret Management

1. Use environment variables for secrets
2. Never hardcode passwords
3. Use `.env` files (gitignored)
4. Rotate credentials regularly
5. Use strong passwords
6. Implement least privilege

### Network Security

```yaml
# Minimal port exposure
containers:
  database:
    # No exposed_ports - internal only
  
  app:
    exposed_ports: [443]  # HTTPS only
```

## Documentation Standards

### Required Documentation

1. **README.md**: Project overview, setup, usage
2. **ARCHITECTURE.md**: System design, components
3. **API.md**: API endpoints, examples
4. **DEPLOYMENT.md**: Deployment procedures
5. **CONTRIBUTING.md**: Contribution guidelines
6. **CHANGELOG.md**: Version history

### README Structure

```markdown
# Project Name

Brief description

## Features

- Feature 1
- Feature 2

## Requirements

- LXC Compose
- Ubuntu 22.04+

## Quick Start

```bash
git clone <repo>
cd project
lxc-compose up
```

## Configuration

Describe configuration options

## Usage

Usage examples

## Testing

```bash
lxc-compose test
```

## Deployment

Deployment instructions

## License

License information
```

## Version Control

### .gitignore Template

```gitignore
# Environment
.env
.env.local
.env.*.local

# Data
data/
*.db
*.sqlite

# Logs
logs/
*.log

# Temporary
tmp/
temp/
*.tmp
*.swp
*.swo
*~

# IDE
.vscode/
.idea/
*.sublime-*

# OS
.DS_Store
Thumbs.db

# Python
__pycache__/
*.py[cod]
*$py.class
.venv/
venv/
*.egg-info/

# Node
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Build
build/
dist/
*.tar.gz
*.zip
```

### Commit Message Format

```
type(scope): subject

body

footer
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Testing
- `chore`: Maintenance

## Python Project Standards

### Virtual Environment

Always use virtual environments:

```yaml
post_install:
  - name: "Setup Python environment"
    command: |
      cd /app
      python3 -m venv venv
      ./venv/bin/pip install --upgrade pip setuptools wheel
      ./venv/bin/pip install -r requirements.txt
```

### Running Python Commands

Use explicit venv paths:

```yaml
# Good
./venv/bin/python manage.py migrate

# Bad (relies on activation)
source venv/bin/activate && python manage.py migrate
```

### Django-Specific Standards

```yaml
post_install:
  - name: "Django setup"
    command: |
      cd /app
      ./venv/bin/python manage.py migrate
      ./venv/bin/python manage.py collectstatic --noinput
      ./venv/bin/python manage.py createsuperuser --noinput \
        --username ${ADMIN_USER} --email ${ADMIN_EMAIL} || true
```

## Configuration File Examples

### supervisord.conf

Basic supervisor configuration:

```ini
[unix_http_server]
file=/run/supervisord.sock

[supervisord]
logfile=/var/log/supervisord.log
loglevel=info
pidfile=/run/supervisord.pid
nodaemon=false

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///run/supervisord.sock

[include]
files = /etc/supervisor.d/*.ini
```

### nginx.conf

Standard proxy configuration:

```nginx
server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
    
    location /static/ {
        alias /app/static/;
        expires 30d;
    }
    
    location /media/ {
        alias /app/media/;
        expires 30d;
    }
}
```

### redis.conf

Standard Redis configuration:

```conf
bind 0.0.0.0
protected-mode no
port 6379
dir /var/lib/redis
logfile /var/log/redis/redis.log
pidfile /run/redis/redis.pid
daemonize no
```

## Best Practices Summary

1. **Container Separation**: Separate datastores from application containers
2. **Minimal Images**: Use Alpine where possible, Ubuntu Minimal when needed
3. **Service Generation**: Define services in YAML, let LXC Compose generate configs
4. **Environment Variables**: All configuration through .env files
5. **Health Checks**: Always verify service availability before dependent operations
6. **Logging**: Consistent log file locations and rotation settings
7. **Security**: Never expose unnecessary ports or hardcode credentials
8. **Documentation**: Always include a README with setup and usage instructions
9. **Testing**: Comprehensive test coverage with internal, external, and security tests
10. **Version Control**: Keep sensitive data out of repository