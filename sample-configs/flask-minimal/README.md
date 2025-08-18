# Flask Minimal Sample

Ultra-lightweight Flask application using Alpine Linux.

## Quick Start

```bash
# Start the container
lxc-compose up

# Access the application
http://localhost:5000
```

## Features

- Alpine Linux base (~3MB)
- Python 3 + Flask
- Total container size: ~60MB
- Auto-creates sample app if none exists

## API Endpoints

- `/` - Home page
- `/api/hello` - JSON API example

## Customization

Place your own `app.py` in this directory before running `lxc-compose up` to use your own Flask application.