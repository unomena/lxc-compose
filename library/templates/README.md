# LXC Compose Templates

Base image templates for LXC Compose containers. These define the standard configurations for different operating system bases.

## Available Base Templates

### Alpine Linux
- **alpine-3.19.yml** - Alpine Linux 3.19 (minimal, ~150MB)
  - Image: `images:alpine/3.19`
  - Best for: Databases, caching, lightweight services
  - Package manager: `apk`

### Ubuntu
- **ubuntu-24.04.yml** - Ubuntu 24.04 LTS Noble (full-featured, ~500MB) **[LATEST LTS]**
  - Image: `ubuntu:24.04`
  - Best for: Complex applications, services requiring systemd
  - Package manager: `apt`

- **ubuntu-22.04.yml** - Ubuntu 22.04 LTS Jammy (full-featured, ~500MB)
  - Image: `ubuntu:22.04`
  - Best for: Stable production systems
  - Package manager: `apt`

### Ubuntu Minimal
- **ubuntu-minimal-24.04.yml** - Ubuntu Minimal 24.04 (lightweight, ~300MB) **[LATEST]**
  - Image: `ubuntu-minimal:24.04`
  - Best for: Simple applications, microservices
  - Package manager: `apt` (limited packages)

- **ubuntu-minimal-22.04.yml** - Ubuntu Minimal 22.04 (lightweight, ~300MB)
  - Image: `ubuntu-minimal:22.04`
  - Best for: Python/Node.js apps
  - Package manager: `apt` (limited packages)

### Debian
- **debian-12.yml** - Debian 12 Bookworm (stable, ~400MB) **[LATEST STABLE]**
  - Image: `images:debian/12`
  - Best for: Production servers requiring stability
  - Package manager: `apt`

- **debian-11.yml** - Debian 11 Bullseye (stable, ~400MB)
  - Image: `images:debian/11`
  - Best for: Legacy production systems
  - Package manager: `apt`

## Template Aliases

For convenience, the following aliases are available:

| Alias | Points To | Description |
|-------|-----------|-------------|
| alpine | alpine-3.19 | Current Alpine version |
| ubuntu-lts | ubuntu-24.04 | Latest Ubuntu LTS |
| ubuntu-noble | ubuntu-24.04 | Ubuntu 24.04 Noble |
| ubuntu-jammy | ubuntu-22.04 | Ubuntu 22.04 Jammy |
| ubuntu-minimal-lts | ubuntu-minimal-24.04 | Latest Ubuntu Minimal LTS |
| ubuntu-minimal-noble | ubuntu-minimal-24.04 | Ubuntu Minimal Noble |
| ubuntu-minimal-jammy | ubuntu-minimal-22.04 | Ubuntu Minimal Jammy |
| debian-bookworm | debian-12 | Debian 12 Bookworm |
| debian-bullseye | debian-11 | Debian 11 Bullseye |

## Usage in lxc-compose.yml

Templates are referenced via the `image` field:

```yaml
containers:
  myapp:
    # Using specific versions
    image: images:alpine/3.19      # Alpine Linux 3.19
    image: ubuntu:24.04             # Ubuntu 24.04 LTS
    image: ubuntu-minimal:24.04     # Ubuntu Minimal 24.04
    image: images:debian/12         # Debian 12
    
    # Using aliases (resolved to specific versions)
    image: alpine                   # → alpine-3.19
    image: ubuntu-lts               # → ubuntu-24.04
    image: ubuntu-noble             # → ubuntu-24.04
    image: debian-bookworm          # → debian-12
```

## Template Structure

Each base template defines:
- Base image reference
- Common packages to install
- Package manager commands
- Environment variables
- Initialization commands
- Developer notes and tips

Alias templates simply point to a base template:
```yaml
alias:
  name: ubuntu-lts
  description: Ubuntu LTS - Latest Long Term Support version
  template: ubuntu-24.04
```

## Choosing a Template

### Alpine Linux (images:alpine/3.19)
✅ **Pros:**
- Smallest size (~150MB)
- Fast container creation
- Good security defaults
- Minimal attack surface

❌ **Cons:**
- Uses musl libc (compatibility issues)
- Limited package availability
- Different command names (adduser vs useradd)

**Use for:** Redis, PostgreSQL, Nginx, simple services

### Ubuntu 24.04 LTS (ubuntu:24.04)
✅ **Pros:**
- Latest LTS with 5 years support
- Full package ecosystem
- systemd support
- Wide compatibility

❌ **Cons:**
- Larger size (~500MB)
- More overhead
- Slower container creation

**Use for:** Complex apps, production systems, services needing systemd

### Ubuntu 22.04 LTS (ubuntu:22.04)
✅ **Pros:**
- Proven stability
- Full package ecosystem
- systemd support
- Wide compatibility

❌ **Cons:**
- Larger size (~500MB)
- Not the latest LTS

**Use for:** Existing production systems, legacy compatibility

### Ubuntu Minimal (ubuntu-minimal:24.04 or 22.04)
✅ **Pros:**
- Ubuntu compatibility
- Smaller than full Ubuntu (~300MB)
- APT package manager
- Good for apps

❌ **Cons:**
- No systemd by default
- Fewer pre-installed tools
- May need extra packages

**Use for:** Web apps, Python/Node.js apps, microservices

### Debian 12 (images:debian/12)
✅ **Pros:**
- Rock-solid stability
- Latest stable Debian
- systemd support
- Long-term support until 2028

❌ **Cons:**
- Conservative package versions
- Some package name differences

**Use for:** Production databases, critical services

### Debian 11 (images:debian/11)
✅ **Pros:**
- Proven stability
- systemd support
- Long-term support until 2026

❌ **Cons:**
- Older package versions
- Will reach EOL sooner

**Use for:** Legacy systems, conservative environments

## Package Manager Commands

### Alpine
```bash
apk update
apk add package-name
apk del package-name
```

### Ubuntu/Debian
```bash
apt-get update
apt-get install package-name
apt-get remove package-name
```

## Common Package Name Differences

| Service | Alpine | Ubuntu/Debian |
|---------|--------|---------------|
| PostgreSQL | postgresql15 | postgresql |
| MySQL | mariadb | mysql-server (Ubuntu) / default-mysql-server (Debian) |
| Redis | redis | redis-server |
| Nginx | nginx | nginx |
| Python | python3, py3-pip | python3, python3-pip |
| Node.js | nodejs, npm | nodejs, npm |
| Build tools | build-base | build-essential |

## Notes

- **Alpine** uses OpenRC for init, not systemd
- **Ubuntu 24.04** is the current LTS (Long Term Support) release
- **Ubuntu Minimal** doesn't include systemd by default
- **Debian** tends to have more conservative package versions than Ubuntu
- Images prefixed with `images:` are custom LXC images
- Standard images like `ubuntu:24.04` use official LXC repositories