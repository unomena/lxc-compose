# LXC Compose Documentation Server

A self-hosted documentation server that automatically clones, builds, and serves the LXC Compose documentation using MkDocs and Nginx.

## Overview

This sample demonstrates how to:
- Clone a Git repository during container initialization
- Build documentation using MkDocs
- Serve static documentation with Nginx
- Auto-rebuild documentation when the repository updates
- Run multiple services (Nginx + auto-updater) in a single container

## Features

- **Automatic Setup**: Clones the LXC Compose repository and builds docs on first run
- **Auto-Updates**: Checks for repository updates every 5 minutes and rebuilds
- **Dual Serving**: Serves built documentation on port 80, optional dev server on port 8000
- **Health Monitoring**: Built-in health checks and comprehensive tests
- **Minimal Footprint**: Uses Alpine Linux (~200MB total with Python)

## Quick Start

### Deploy the Documentation Server

```bash
# From the samples/docs-server directory
lxc-compose up

# Wait for initialization (about 30-60 seconds)
lxc-compose logs lxc-docs build

# Access the documentation
open http://localhost
```

### Check Status

```bash
# View container status
lxc-compose list

# Run health checks
lxc-compose test

# View logs
lxc-compose logs lxc-docs nginx --follow
```

## Architecture

```
┌─────────────────────────────────────┐
│         Alpine Container            │
│                                     │
│  ┌─────────────────────────────┐   │
│  │   Git Repository (cloned)    │   │
│  │  github.com/unomena/lxc-     │   │
│  │         compose              │   │
│  └──────────┬──────────────────┘   │
│             │                       │
│  ┌──────────▼──────────────────┐   │
│  │    MkDocs Builder           │   │
│  │  (Python venv + MkDocs)     │   │
│  └──────────┬──────────────────┘   │
│             │                       │
│  ┌──────────▼──────────────────┐   │
│  │   Static Site Output        │   │
│  │   /opt/lxc-compose/docs/    │   │
│  │         site/               │   │
│  └──────────┬──────────────────┘   │
│             │                       │
│  ┌──────────▼──────────────────┐   │
│  │      Nginx Web Server       │   │
│  │       (Port 80)             │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │    Auto-Update Service      │   │
│  │  (Checks every 5 minutes)   │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Configuration Details

### Services

1. **Nginx**: Serves the built documentation on port 80
2. **Auto-updater**: Checks for repository updates and rebuilds docs

### Directory Structure

Project structure:
```
samples/docs-server/
├── lxc-compose.yml        # Container configuration
├── config/
│   └── lxc-docs/         # Container-specific configs
│       ├── nginx/
│       │   └── default.conf  # Nginx configuration
│       └── scripts/
│           ├── init-docs.sh       # Initialization script
│           ├── rebuild-docs.sh    # Auto-rebuild script
│           ├── manual-rebuild.sh  # Manual rebuild trigger
│           └── start-dev.sh       # Start MkDocs dev server
└── tests/
    ├── internal_tests.sh  # Internal health checks
    ├── external_tests.sh  # External connectivity tests
    └── port_tests.sh      # Port forwarding tests
```

Inside the container:
```
/opt/lxc-compose/          # Cloned repository
├── docs/                  # Documentation source
│   ├── .venv/            # Python virtual environment
│   ├── site/             # Built documentation (served by Nginx)
│   └── mkdocs.yml        # MkDocs configuration
/docs/scripts/             # Mounted helper scripts
├── rebuild-docs.sh        # Auto-rebuild script
├── manual-rebuild.sh      # Manual rebuild trigger
└── start-dev.sh          # Start MkDocs dev server
/etc/nginx/http.d/
└── default.conf          # Mounted Nginx configuration
```

### Endpoints

- `http://localhost/` - Main documentation
- `http://localhost/health` - Health check endpoint
- `http://localhost/api/info` - API information (JSON)
- `http://localhost:8000/` - MkDocs dev server (if started)

## Configuration

The documentation server uses environment variables configured in `.env`:

```env
# Repository settings
REPO_URL=https://github.com/unomena/lxc-compose.git
REPO_BRANCH=main

# Update settings
UPDATE_INTERVAL=300     # Check for updates every 5 minutes
AUTO_UPDATE=true       # Enable automatic updates

# Server ports
HTTP_PORT=80           # Nginx port
DEV_PORT=8000         # MkDocs dev server port

# Build settings
BUILD_CLEAN=true      # Use --clean flag when building
```

## Customization

### Use a Different Repository

Edit the `.env` file:

```env
REPO_URL=https://github.com/YOUR-ORG/YOUR-REPO.git
REPO_BRANCH=develop
```

### Change Update Interval

Modify in `.env`:

```env
UPDATE_INTERVAL=600    # 10 minutes
# or disable auto-updates:
AUTO_UPDATE=false
```

### Add Authentication

Add basic authentication to Nginx:

```yaml
post_install:
  - name: "Setup authentication"
    command: |
      apk add apache2-utils
      htpasswd -bc /etc/nginx/.htpasswd admin yourpassword
      # Then add to nginx config:
      # auth_basic "Documentation";
      # auth_basic_user_file /etc/nginx/.htpasswd;
```

## Manual Operations

### Rebuild Documentation Manually

```bash
# From host
lxc exec lxc-docs -- /docs/scripts/manual-rebuild.sh

# Or inside container
lxc exec lxc-docs -- /bin/sh
/docs/scripts/manual-rebuild.sh
```

### Start Development Server

```bash
# Inside container
lxc exec lxc-docs -- /docs/scripts/start-dev.sh

# Access at http://localhost:8000
```

### Update Repository

```bash
lxc exec lxc-docs -- sh -c "cd /opt/lxc-compose && git pull"
lxc exec lxc-docs -- /docs/scripts/manual-rebuild.sh
```

## Testing

The container includes comprehensive tests:

### Run All Tests
```bash
lxc-compose test
```

### Run Specific Tests
```bash
# Internal tests (services, build verification)
lxc-compose test lxc-docs internal

# External tests (HTTP endpoints, content)
lxc-compose test lxc-docs external

# Port forwarding tests (iptables rules)
lxc-compose test lxc-docs port_forwarding
```

### Test Coverage

- **Internal Tests**: Service status, repository clone, documentation build, Python environment
- **External Tests**: HTTP endpoints, content verification, API responses, performance
- **Port Tests**: iptables DNAT rules, security verification

## Troubleshooting

### Documentation Not Building

Check the build logs:
```bash
lxc-compose logs lxc-docs build
lxc exec lxc-docs -- cat /var/log/build.log
```

### Nginx Not Serving

Check Nginx status:
```bash
lxc exec lxc-docs -- nginx -t
lxc-compose logs lxc-docs nginx-error
```

### Repository Clone Failed

Check network and manually clone:
```bash
lxc exec lxc-docs -- ping github.com
lxc exec lxc-docs -- sh -c "cd /opt && git clone https://github.com/unomena/lxc-compose.git"
```

### Auto-Update Not Working

Check the update service:
```bash
lxc exec lxc-docs -- supervisorctl status mkdocs-watch
lxc-compose logs lxc-docs mkdocs
```

## Performance

- **Container Size**: ~200MB (Alpine + Python + Nginx)
- **Build Time**: 30-60 seconds initial build
- **Memory Usage**: ~100-150MB running
- **CPU Usage**: Minimal (spike during build)

## Security Notes

- Documentation is served publicly on port 80
- No authentication by default (add if needed)
- Repository is cloned via HTTPS (read-only)
- Auto-updater only pulls from main branch

## Use Cases

This pattern is perfect for:
- **Documentation hosting**: Serve project documentation
- **Static site hosting**: Build and serve any static site generator
- **CI/CD artifacts**: Serve build artifacts or reports
- **Internal wikis**: Host team documentation
- **API documentation**: Serve Swagger/OpenAPI docs

## Extending This Example

Ideas for enhancement:
1. Add SSL/TLS with Let's Encrypt
2. Implement webhook-based updates instead of polling
3. Add search functionality with MkDocs plugins
4. Create multiple documentation versions (tags/branches)
5. Add PDF generation for offline viewing
6. Implement caching with Nginx
7. Add monitoring and metrics

## See Also

- [LXC Compose Documentation](https://github.com/unomena/lxc-compose)
- [MkDocs Documentation](https://www.mkdocs.org/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Alpine Linux](https://alpinelinux.org/)