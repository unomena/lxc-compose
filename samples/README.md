# LXC Compose Sample Configurations

Production-ready sample applications demonstrating LXC Compose configuration best practices. All samples follow the reference project structure from https://github.com/euan/sample-lxc-compose-app.

## 🚀 Production Resilience Features (v2.1+)

All samples now include enhanced production resilience:
- **Automatic Service Recovery**: Supervisor and all services auto-start after container restart
- **Environment Variable Inheritance**: Services automatically inherit from .env files via load-env.sh wrapper
- **OS-Aware Configuration**: Supervisor configs placed correctly (Ubuntu: /etc/supervisor/conf.d/, Alpine: /etc/supervisor.d/)
- **Port Forwarding Persistence**: UPF rules automatically update when containers get new IPs
- **Database Auto-Start**: PostgreSQL, MySQL, MongoDB configured to start automatically
- **"Pull the Plug" Resilience**: Complete recovery after system restart - no manual intervention needed

## Available Samples

### 1. Django Minimal (`django-minimal/`)
**Ultra-lightweight Django + PostgreSQL in a single Alpine container**

- **Container Size**: ~150MB total
- **Stack**: Django 5.0 + PostgreSQL 16 + WhiteNoise
- **Features**:
  - Single Alpine Linux container (3MB base)
  - PostgreSQL and Django in one container
  - WhiteNoise for static file serving
  - Auto-creates superuser (admin/admin123)
  - Environment-based configuration
  - Production-ready settings

**Access**:
- Web: http://localhost:8000
- Admin: http://localhost:8000/admin
- PostgreSQL: localhost:5432 (optional)

### 2. Flask Application (`flask-app/`)
**Microservice architecture with Flask and Redis**

- **Container Size**: ~200MB total
- **Stack**: Flask + Gunicorn + Redis + Nginx
- **Features**:
  - Flask with Gunicorn WSGI server
  - Redis for caching and session storage
  - Nginx reverse proxy
  - Visit counter with Redis backend
  - RESTful API endpoints
  - Health check endpoint
  - Supervisor process management

**Access**:
- Web: http://localhost:5000
- API: http://localhost:5000/api
- Health: http://localhost:5000/health

### 3. Node.js Application (`nodejs-app/`)
**Express.js with MongoDB and PM2**

- **Container Size**: ~300MB total
- **Stack**: Express.js + MongoDB + PM2 + Nginx
- **Features**:
  - Express.js web framework
  - MongoDB for data persistence
  - PM2 process manager with auto-restart
  - Nginx reverse proxy with caching
  - RESTful API with CRUD operations
  - Environment-based configuration
  - Automatic database seeding

**Access**:
- Web: http://localhost:3000
- API: http://localhost:3000/api
- MongoDB: localhost:27017 (if exposed)

## Configuration Format

All samples follow the same configuration format:

```yaml
version: '1.0'

containers:
  container-name:
    image: ubuntu:jammy     # Base OS image (ubuntu:22.04, images:alpine/3.19, etc.)
    
    depends_on:             # Container dependencies
      - other-container
    
    mounts:                 # Directory mounts
      - .:/app              # Mount current dir to /app
    
    exposed_ports:          # Exposed ports
      - 8000                # Port accessible from host
    
    packages:               # APT packages to install
      - python3
      - nginx
    
    services:               # Service definitions
      service-name:
        command: /path/to/command
        directory: /app
        autostart: true
        environment:
          KEY: value
    
    post_install:          # Post-installation commands
      - name: "Setup task"
        command: |
          echo "Running setup"
```

## Key Principles

1. **No Dynamic Generation**: All source files must exist in the project directory before running `lxc-compose up`. No files are generated on the fly.

2. **Mount-based Development**: The entire project directory is mounted into the container, allowing for live code changes during development.

3. **Dictionary Format**: Containers are defined as a dictionary (not a list) with container names as keys.

4. **Service Management**: Services are managed by Supervisor with automatic recovery:
   - Auto-starts on container boot (systemd/OpenRC integration)
   - Environment variables inherited automatically via load-env.sh
   - OS-aware configuration placement

5. **Environment Variables**: Configuration through .env files - the single source of truth:
   - No duplication in lxc-compose.yml
   - Automatically propagated to all services
   - Supports variable expansion in YAML

6. **Production Resilience**: All samples demonstrate "pull the plug" recovery:
   - Services auto-recover after restart
   - Port forwarding persists through lifecycle
   - Databases auto-start on boot

## Quick Start

### Running a Sample

1. **Choose and navigate to a sample**:
   ```bash
   cd sample-configs/django-minimal
   # or: cd sample-configs/flask-app
   # or: cd sample-configs/nodejs-app
   ```

2. **Review the configuration**:
   ```bash
   cat lxc-compose.yml
   ls -la  # View all project files
   ```

3. **Start the application**:
   ```bash
   lxc-compose up
   # Or run in background:
   lxc-compose up -d
   ```

4. **Monitor status**:
   ```bash
   lxc-compose list
   # Output:
   # NAME              STATUS    IP           PORTS
   # django-minimal    RUNNING   10.0.3.11    8000:8000, 5432:5432
   ```

5. **View logs**:
   ```bash
   lxc-compose logs
   # Or follow logs:
   lxc-compose logs -f
   ```

6. **Stop the application**:
   ```bash
   lxc-compose down
   ```

7. **Clean up (remove containers)**:
   ```bash
   lxc-compose destroy
   ```

### Customizing Samples

1. **Copy the sample to your workspace**:
   ```bash
   cp -r sample-configs/django-minimal ~/myproject
   cd ~/myproject
   ```

2. **Modify the configuration**:
   ```bash
   # Edit container name to avoid conflicts
   sed -i 's/django-minimal/myproject/g' lxc-compose.yml
   ```

3. **Add your code**:
   - Place your application files in the directory
   - Update `requirements.txt` or `package.json`
   - Modify `post_install` commands as needed

4. **Run your customized version**:
   ```bash
   lxc-compose up
   ```

## Directory Structure

Each sample follows this structure:
```
sample-name/
├── lxc-compose.yml    # Container configuration
├── requirements.txt   # Python dependencies (Python projects)
├── package.json       # Node dependencies (Node projects)
├── src/              # Source code directory (if applicable)
├── *.py/*.js         # Application files
└── README.md         # Sample documentation
```

## Requirements

- LXC/LXD installed and configured
- lxc-compose CLI installed
- Network bridge configured (usually lxcbr0)
- Sufficient permissions to create containers

## Performance Comparison

| Sample | Base Image | Container Size | Memory Usage | Startup Time |
|--------|------------|----------------|--------------|-------------|
| Django Minimal | Alpine 3.19 | ~150MB | ~100MB | ~15 seconds |
| Flask App | Alpine 3.19 | ~200MB | ~80MB | ~10 seconds |
| Node.js App | Ubuntu 22.04 | ~300MB | ~150MB | ~20 seconds |

## Best Practices Demonstrated

### 1. Container Optimization
- Use Alpine Linux for minimal footprint
- Combine related services in single container when appropriate
- Install only required packages
- Clean package caches in `post_install`

### 2. Configuration Management
- Environment variables for all settings
- Separate development and production configs
- No hardcoded passwords in code
- Use `.env` files for local development

### 3. Service Management
- Supervisor for multi-process containers
- Systemd for system services
- Auto-restart on failures
- Proper PID file management

### 4. Development Workflow
- Mount entire directory for live reloading
- Keep source files in version control
- No dynamic file generation
- Clear separation of code and config

## Troubleshooting

### Container won't start
```bash
# Check container status
lxc list

# View container logs
lxc console <container-name>

# Check lxc-compose logs
lxc-compose logs
```

### Port already in use
```bash
# Find process using port
sudo lsof -i :8000

# Change port in lxc-compose.yml
ports:
  - "8001:8000"  # Use different host port
```

### Permission issues
```bash
# Ensure LXD group membership
sudo usermod -aG lxd $USER
newgrp lxd

# Check LXD status
lxc list
```

## Security Notes

⚠️ **Development Only**: Default credentials are for development. Always change them in production:
- Django: admin/admin123
- PostgreSQL: postgres/postgres
- MongoDB: No auth (bind to localhost)

## Contributing

To add a new sample:
1. Create directory in `sample-configs/`
2. Add `lxc-compose.yml` following dictionary format
3. Include all source files (no generation)
4. Add README.md with setup instructions
5. Test with `lxc-compose up`
6. Submit pull request

## License

All samples are provided as-is for educational purposes. Modify freely for your needs.