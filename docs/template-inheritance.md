# Template Inheritance and GitHub Fetching

## Overview

LXC Compose uses a powerful template inheritance system that fetches configurations directly from GitHub, eliminating the need for local installation of templates and services.

## Architecture

### Three-Layer Inheritance Model

```
┌─────────────────┐
│   Your Config   │ ← Highest Priority (your lxc-compose.yml)
├─────────────────┤
│ Library Services│ ← Pre-configured services (nginx, postgresql, etc.)
├─────────────────┤
│    Templates    │ ← Base OS configuration (alpine, ubuntu, debian)
└─────────────────┘
```

Each layer inherits from the one below and can override any setting.

## GitHub-Based Fetching (NEW!)

### How It Works

When you run `lxc-compose up`, the system:

1. **Reads your configuration** from `lxc-compose.yml`
2. **Fetches the template** from GitHub: `library/templates/{template-name}.yml`
3. **Fetches included services** from GitHub: `library/services/{os}/{version}/{service}/`
4. **Merges configurations** in order: Template → Services → Your Config
5. **Creates the container** with the final merged configuration

### No Installation Required

Unlike traditional approaches, you don't need to install templates or services locally:

```bash
# Just run - templates and services are fetched automatically
lxc-compose up
```

### Using Custom Repositories

You can use your own fork or custom repository:

```bash
# Use your fork
export LXC_COMPOSE_REPO=https://github.com/yourusername/lxc-compose
export LXC_COMPOSE_BRANCH=my-custom-templates
lxc-compose up

# Use a specific version
export LXC_COMPOSE_BRANCH=v1.0.0
lxc-compose up
```

## Templates

Templates define the base operating system and initial configuration.

### Available Templates

| Template | Alias | Description | Size |
|----------|-------|-------------|------|
| `alpine-3.19` | `alpine` | Minimal Alpine Linux | ~150MB |
| `ubuntu-24.04` | `ubuntu-lts`, `ubuntu-noble` | Ubuntu 24.04 LTS | ~500MB |
| `ubuntu-22.04` | `ubuntu-jammy` | Ubuntu 22.04 LTS | ~500MB |
| `ubuntu-minimal-24.04` | `ubuntu-minimal-lts` | Minimal Ubuntu 24.04 | ~300MB |
| `ubuntu-minimal-22.04` | `ubuntu-minimal-jammy` | Minimal Ubuntu 22.04 | ~300MB |
| `debian-12` | `debian-bookworm` | Debian 12 Bookworm | ~400MB |
| `debian-11` | `debian-bullseye` | Debian 11 Bullseye | ~400MB |

### Template Configuration

Templates provide:
- Base OS image
- Initial packages
- Environment variables
- System initialization commands

Example template (`library/templates/alpine-3.19.yml`):
```yaml
template:
  image: images:alpine/3.19
  base_packages:
    - alpine-base
    - bash
    - curl
    - ca-certificates
  environment:
    PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    LANG: C.UTF-8
  init_commands:
    - name: "Update package index"
      command: "apk update"
    - name: "Install base packages"
      command: "apk add --no-cache bash curl ca-certificates"
```

## Library Services

Pre-configured services that can be included in your containers.

### Available Services

Services are available for each base OS:

| Service | Purpose | Ports | Tested |
|---------|---------|-------|--------|
| `postgresql` | PostgreSQL database | 5432 | ✅ |
| `mysql` | MySQL database | 3306 | ✅ |
| `mongodb` | MongoDB NoSQL database | 27017 | ✅ |
| `redis` | Redis cache/message broker | 6379 | ✅ |
| `memcached` | Memcached cache | 11211 | ✅ |
| `nginx` | Nginx web server | 80, 443 | ✅ |
| `haproxy` | HAProxy load balancer | 80, 443, 8404 | ✅ |
| `rabbitmq` | RabbitMQ message queue | 5672, 15672 | ✅ |
| `elasticsearch` | Elasticsearch search engine | 9200, 9300 | ✅ |
| `grafana` | Grafana monitoring | 3000 | ✅ |
| `prometheus` | Prometheus monitoring | 9090 | ✅ |

### Service Configuration

Services provide:
- Required packages
- Exposed ports
- Configuration files
- Initialization scripts
- Health check tests

Example service (`library/services/alpine/3.19/nginx/lxc-compose.yml`):
```yaml
containers:
  nginx-alpine-3-19:
    template: alpine-3.19
    exposed_ports:
      - 80
      - 443
    packages:
      - nginx
    mounts:
      - ./html:/usr/share/nginx/html
      - ./conf.d:/etc/nginx/conf.d
    tests:
      external:
        - nginx:/tests/nginx.sh
    post_install:
      - name: "Setup Nginx"
        command: |
          mkdir -p /run/nginx
          mkdir -p /usr/share/nginx/html
          # Create default index.html
          if [ ! -f /usr/share/nginx/html/index.html ]; then
            echo "<h1>Welcome to nginx!</h1>" > /usr/share/nginx/html/index.html
          fi
          nginx
```

## Usage Examples

### Basic Template Usage

```yaml
version: '1.0'
containers:
  myapp:
    template: alpine-3.19  # Uses Alpine Linux base
```

### Including Services

```yaml
version: '1.0'
containers:
  myapp:
    template: ubuntu-minimal-24.04
    includes:
      - nginx       # Adds nginx web server
      - postgresql  # Adds PostgreSQL database
      - redis       # Adds Redis cache
```

### Full Example with Overrides

```yaml
version: '1.0'
containers:
  webapp:
    template: alpine-3.19
    includes:
      - nginx
      - redis
    
    # Override/add packages
    packages:
      - python3
      - py3-pip
    
    # Additional ports
    exposed_ports:
      - 8000  # For Python app
    
    # Mount application code
    mounts:
      - ./app:/app
      - ./static:/usr/share/nginx/html/static
    
    # Define services
    services:
      app:
        command: python3 /app/main.py
        directory: /app
        environment:
          FLASK_APP: main.py
    
    # Custom setup
    post_install:
      - name: "Install Python dependencies"
        command: |
          cd /app && pip3 install -r requirements.txt
    
    # Health checks
    tests:
      internal:
        - app_health:/app/tests/health.sh
      external:
        - api_check:/tests/api.sh
```

## Inheritance Rules

### Merging Behavior

Different configuration fields have different merging strategies:

| Field | Strategy | Example |
|-------|----------|---------|
| `packages` | Append & deduplicate | Base: `[curl]`, Include: `[wget]`, Result: `[curl, wget]` |
| `environment` | Override by key | Base: `{A: "1"}`, Include: `{A: "2", B: "3"}`, Result: `{A: "2", B: "3"}` |
| `exposed_ports` | Append & deduplicate | Base: `[80]`, Include: `[443]`, Result: `[80, 443]` |
| `mounts` | Append | All mounts from all layers are included |
| `services` | Override by key | Later definitions override earlier ones |
| `post_install` | Append in order | Template → Services → Your config |
| `tests` | Merge by type | All tests are preserved with library path metadata |

### Command Execution Order

Commands are executed in this order:

1. **Template init commands** - Base OS setup
2. **Service setup commands** - For each included service
3. **Your post_install commands** - Custom setup

Each command is labeled with its source:
- `[Template] Update package index`
- `[nginx] Setup Nginx`
- `[redis] Setup Redis`
- `[Local] Install my app`

## Creating Custom Templates

You can create custom templates in your fork:

1. Fork the repository
2. Create `library/templates/my-template.yml`:

```yaml
template:
  image: images:ubuntu/24.04
  base_packages:
    - curl
    - vim
    - git
  environment:
    MY_ENV: "custom"
  init_commands:
    - name: "Custom setup"
      command: "echo 'My custom template'"
```

3. Use your fork:

```bash
export LXC_COMPOSE_REPO=https://github.com/yourusername/lxc-compose
lxc-compose up
```

## Creating Custom Services

Add services to your fork:

1. Create `library/services/{os}/{version}/{service}/lxc-compose.yml`
2. Define the service configuration
3. Add tests in `tests/` subdirectory
4. Use in your configurations

Example structure:
```
library/services/
└── alpine/
    └── 3.19/
        └── myservice/
            ├── lxc-compose.yml
            └── tests/
                └── test.sh
```

## Troubleshooting

### Template Not Found

If you see "Template not found on GitHub":
- Check your internet connection
- Verify the template name is correct
- Check if using a custom repo: `echo $LXC_COMPOSE_REPO`
- Try using local fallback by installing locally

### Service Not Found

If a service isn't found:
- Verify it exists for your chosen template's OS
- Check the service name spelling
- Ensure the template/service compatibility

### Debugging Inheritance

To see what configuration is being used:

```bash
# Check which handler is being used
lxc-compose up  # Shows "Using GitHub templates from..."

# Set custom repo for testing
export LXC_COMPOSE_REPO=https://github.com/yourusername/lxc-compose
export LXC_COMPOSE_BRANCH=dev

# Force local mode (if installed)
# The system will fallback to local if GitHub fails
```

## Best Practices

1. **Start with minimal templates** - Use Alpine or Ubuntu-minimal for smaller containers
2. **Use includes for standard services** - Don't reinvent PostgreSQL or Redis setup
3. **Override only what you need** - Let the library handle standard configurations
4. **Test inheritance** - Use `lxc-compose test` to verify services work together
5. **Version control your configs** - Keep your `lxc-compose.yml` in git
6. **Use environment variables** - Keep secrets in `.env` files, not in configs

## Migration from v1.x

If upgrading from older versions:

1. **Directory structure changed**:
   - Old: `templates/` and `library/{os}/{version}/{service}/`
   - New: `library/templates/` and `library/services/{os}/{version}/{service}/`

2. **GitHub fetching is now default**:
   - Templates and services are fetched from GitHub automatically
   - Local installation at `/srv/lxc-compose/` is now optional

3. **No breaking changes in YAML**:
   - Your existing `lxc-compose.yml` files work without changes
   - The same template names and service names are supported

## Performance Considerations

- **First run**: Fetches templates/services from GitHub (requires internet)
- **No caching**: Always fetches latest version (ensures up-to-date)
- **Network requirement**: Internet needed for template/service fetching
- **Fallback**: Automatically uses local files if GitHub unavailable

## Security

- **Read-only fetching**: Only downloads configurations, no execution
- **HTTPS only**: All GitHub fetching uses secure connections
- **No credentials**: Public repository access only
- **Local validation**: Configurations are validated before use