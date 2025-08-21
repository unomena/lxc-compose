#!/bin/sh
# Start MkDocs development server

# Use environment variables with defaults
DEV_PORT=${DEV_PORT:-8000}

echo "Starting MkDocs development server on port ${DEV_PORT}..."
cd /opt/lxc-compose
/opt/lxc-compose/docs/.venv/bin/mkdocs serve --config-file docs/mkdocs.yml --dev-addr 0.0.0.0:${DEV_PORT} --livereload