# LXC Compose

Docker Compose-like orchestration for Linux Containers (LXC).

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/unomena/lxc-compose/main/get.sh | bash

# Run setup wizard
lxc-compose wizard

# Or use CLI directly
lxc-compose up
lxc-compose down
lxc-compose logs
```

## Features

- 🚀 Simple container orchestration
- 🔧 Interactive setup wizard
- 🌐 Web management interface
- 📦 Pre-configured templates
- 🔄 Automatic updates
- 🏥 Built-in diagnostics and recovery

## Architecture

```
/srv/
├── lxc-compose/         # System files
├── apps/               # Application containers
├── shared/             # Shared resources
└── logs/              # Centralized logging
```

## Commands

### Wizard (Primary Interface)

```bash
lxc-compose wizard              # Interactive menu
lxc-compose wizard setup-db     # Setup database
lxc-compose wizard setup-app    # Setup application
lxc-compose wizard update       # Update system
lxc-compose wizard doctor       # Run diagnostics
lxc-compose wizard recover      # Recovery tools
```

### CLI Commands

```bash
lxc-compose up                  # Start containers
lxc-compose down                # Stop containers
lxc-compose restart <name>      # Restart container
lxc-compose logs <name>         # View logs
lxc-compose exec <name> <cmd>   # Execute command
lxc-compose list                # List containers
```

## Documentation

See the [docs](docs/) directory for detailed documentation.

## License

MIT License - See LICENSE file for details.
