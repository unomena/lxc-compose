# LXC Compose Templates

Base image templates for LXC Compose containers. These define the standard configurations for different operating system bases.

## Available Templates

### Alpine Linux
- **alpine-3.19.yml** - Alpine Linux 3.19 (minimal, ~150MB)
  - Best for: Databases, caching, lightweight services
  - Package manager: `apk`
  - Examples: PostgreSQL, Redis, Nginx, HAProxy, Memcached

### Ubuntu
- **ubuntu-22.04.yml** - Ubuntu 22.04 LTS (full-featured, ~500MB)
  - Best for: Complex applications, services requiring systemd
  - Package manager: `apt`
  - Examples: MySQL, MongoDB, Elasticsearch, Grafana, RabbitMQ

- **ubuntu-minimal-lts.yml** - Ubuntu Minimal LTS (lightweight, ~300MB)
  - Best for: Simple applications, Python/Node.js apps
  - Package manager: `apt` (limited packages)
  - Examples: Django, Flask, Node.js applications

## Template Structure

Each template defines:
- Base image reference
- Common packages to install
- Package manager commands
- Environment variables
- Initialization commands
- Developer notes and tips

## Usage in lxc-compose.yml

Templates are referenced via the `image` field:

```yaml
containers:
  myapp:
    image: images:alpine/3.19      # Alpine Linux
    # or
    image: ubuntu:22.04             # Ubuntu 22.04
    # or  
    image: ubuntu-minimal:lts       # Ubuntu Minimal
```

## Choosing a Template

### Alpine Linux (images:alpine/3.19)
✅ Pros:
- Smallest size (~150MB)
- Fast container creation
- Good security defaults
- Minimal attack surface

❌ Cons:
- Uses musl libc (compatibility issues)
- Limited package availability
- Different command names (adduser vs useradd)

**Use for**: Redis, PostgreSQL, Nginx, simple services

### Ubuntu 22.04 (ubuntu:22.04)
✅ Pros:
- Full package ecosystem
- systemd support
- Wide compatibility
- Familiar environment

❌ Cons:
- Larger size (~500MB)
- More overhead
- Slower container creation

**Use for**: Complex apps, Java apps, services needing systemd

### Ubuntu Minimal (ubuntu-minimal:lts)
✅ Pros:
- Ubuntu compatibility
- Smaller than full Ubuntu
- APT package manager
- Good for apps

❌ Cons:
- No systemd by default
- Fewer pre-installed tools
- May need extra packages

**Use for**: Web apps, Python/Node.js apps, microservices

## Package Manager Commands

### Alpine
```bash
apk update
apk add package-name
apk del package-name
```

### Ubuntu/Ubuntu Minimal
```bash
apt-get update
apt-get install package-name
apt-get remove package-name
```

## Common Package Names

| Service | Alpine | Ubuntu |
|---------|--------|--------|
| PostgreSQL | postgresql15 | postgresql |
| MySQL | mariadb | mysql-server |
| Redis | redis | redis-server |
| Nginx | nginx | nginx |
| Python | python3, py3-pip | python3, python3-pip |
| Node.js | nodejs, npm | nodejs, npm |
| Build tools | build-base | build-essential |