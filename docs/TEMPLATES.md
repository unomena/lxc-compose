# Template System Documentation

## Overview

The LXC Compose template system allows you to extend base operating system configurations, similar to Docker's FROM directive but with more flexibility. Templates provide pre-configured base images with common packages, environment variables, and initialization commands.

## Using Templates

### Basic Usage

Instead of specifying an `image:` directly, use `template:` to inherit from a base configuration:

```yaml
containers:
  myapp:
    template: ubuntu-24.04  # Extends Ubuntu 24.04 template
    packages:
      - nginx
    exposed_ports:
      - 80
```

### Template vs Image

You must use EITHER `template:` OR `image:`, never both:

```yaml
# ✅ Good - using template
containers:
  app1:
    template: alpine-3.19
    
# ✅ Good - using image directly  
containers:
  app2:
    image: ubuntu:24.04
    
# ❌ Bad - can't use both
containers:
  app3:
    template: alpine-3.19
    image: ubuntu:24.04  # This will cause an error
```

## Available Templates

### Base Templates

| Template | Image | Size | Best For |
|----------|-------|------|----------|
| `alpine-3.19` | `images:alpine/3.19` | ~150MB | Databases, caching, microservices |
| `ubuntu-24.04` | `ubuntu:24.04` | ~500MB | Complex apps, latest LTS |
| `ubuntu-22.04` | `ubuntu:22.04` | ~500MB | Stable production systems |
| `ubuntu-minimal-24.04` | `ubuntu-minimal:24.04` | ~300MB | Simple apps, microservices |
| `ubuntu-minimal-22.04` | `ubuntu-minimal:22.04` | ~300MB | Python/Node.js apps |
| `debian-12` | `images:debian/12` | ~400MB | Production databases |
| `debian-11` | `images:debian/11` | ~400MB | Legacy systems |

### Template Aliases

For convenience, these aliases point to specific versions:

| Alias | Points To | Description |
|-------|-----------|-------------|
| `alpine` | `alpine-3.19` | Current Alpine |
| `ubuntu-lts` | `ubuntu-24.04` | Latest Ubuntu LTS |
| `ubuntu-noble` | `ubuntu-24.04` | Ubuntu Noble |
| `ubuntu-jammy` | `ubuntu-22.04` | Ubuntu Jammy |
| `ubuntu-minimal-lts` | `ubuntu-minimal-24.04` | Latest minimal LTS |
| `debian-bookworm` | `debian-12` | Debian 12 |
| `debian-bullseye` | `debian-11` | Debian 11 |

## Template Inheritance

When you use a template, your container inherits:

1. **Base image** - The underlying LXC image
2. **Base packages** - Common packages for that distro
3. **Environment variables** - Default environment setup
4. **Init commands** - Initialization steps for the OS

### Inheritance Order

Template attributes are applied BEFORE your container configuration:

```yaml
# Template provides:
# - image: ubuntu:24.04
# - base_packages: [curl, wget, ca-certificates]
# - init_commands: [apt-get update]

containers:
  myapp:
    template: ubuntu-24.04
    packages:
      - nginx  # Added AFTER base_packages
    post_install:
      - name: "Setup"
        command: "echo 'hello'"  # Runs AFTER init_commands
```

Results in:
1. Image: `ubuntu:24.04`
2. Packages installed: `curl, wget, ca-certificates, nginx`
3. Commands run: `apt-get update` then `echo 'hello'`

## Example Configurations

### Web Application

```yaml
containers:
  webapp:
    template: ubuntu-lts
    packages:
      - nginx
      - python3
      - python3-pip
    exposed_ports:
      - 80
      - 443
    post_install:
      - name: "Install app"
        command: |
          pip3 install -r requirements.txt
```

### Database Server

```yaml
containers:
  database:
    template: debian-bookworm
    packages:
      - postgresql
    exposed_ports:
      - 5432
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
```

### Redis Cache

```yaml
containers:
  cache:
    template: alpine  # Minimal footprint
    packages:
      - redis
    exposed_ports:
      - 6379
```

### Microservice

```yaml
containers:
  api:
    template: ubuntu-minimal-lts
    packages:
      - python3
      - python3-pip
    exposed_ports:
      - 8000
    post_install:
      - name: "Install FastAPI"
        command: |
          pip3 install fastapi uvicorn
```

## Creating Custom Templates

Templates are stored in `/srv/lxc-compose/templates/` (or `templates/` in development).

### Base Template Structure

```yaml
# templates/mytemplate.yml
version: '1.0'

template:
  name: mytemplate
  description: My custom template
  image: ubuntu:24.04  # Base LXC image
  
  base_packages:
    - curl
    - wget
    - vim
  
  environment:
    LANG: C.UTF-8
    DEBIAN_FRONTEND: noninteractive
  
  init_commands:
    - name: "Update packages"
      command: "apt-get update"
    - name: "Install essentials"
      command: "apt-get install -y curl wget"
```

### Alias Template Structure

```yaml
# templates/myalias.yml
version: '1.0'

alias:
  name: myalias
  description: Alias to another template
  template: mytemplate  # Points to actual template
```

## Template Best Practices

1. **Use appropriate base** - Alpine for small services, Ubuntu for complex apps
2. **Don't override unnecessarily** - Let templates handle base configuration
3. **Environment variables** - Use templates for common env vars
4. **Package layering** - Templates install base packages, containers add specific ones
5. **Init vs post_install** - Templates init the OS, containers setup the application

## Migration Guide

### From Image to Template

Before (using image):
```yaml
containers:
  app:
    image: ubuntu:24.04
    packages:
      - curl
      - wget
      - nginx
```

After (using template):
```yaml
containers:
  app:
    template: ubuntu-24.04  # curl, wget included in template
    packages:
      - nginx  # Only app-specific packages
```

### Benefits of Templates

1. **Consistency** - All containers using same template get same base setup
2. **Simplification** - Don't repeat common packages and setup
3. **Maintenance** - Update template to update all containers using it
4. **Best practices** - Templates encode OS-specific best practices

## Troubleshooting

### Template Not Found

```
Error: Template not found: my-template
```

Check:
- Template file exists in `/srv/lxc-compose/templates/`
- File is named `my-template.yml`
- File has valid YAML syntax

### Package Conflicts

If template and container specify conflicting packages:
- Container packages are added to template packages
- Duplicates are automatically removed
- Container version takes precedence if specified

### Command Order Issues

Remember:
1. Template init_commands run first
2. Container post_install runs second
3. Use container environment to override template environment