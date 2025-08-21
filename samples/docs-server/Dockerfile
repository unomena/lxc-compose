# Use Alpine for minimal size
FROM alpine:3.19

# Install required packages
RUN apk add --no-cache \
    git \
    python3 \
    py3-pip \
    nginx \
    supervisor \
    curl \
    make \
    bash

# Create directories
RUN mkdir -p /docs/scripts /docs/tests /opt

# Set working directory
WORKDIR /opt

# Clone the repository
RUN git clone https://github.com/unomena/lxc-compose.git

# Setup Python environment
WORKDIR /opt/lxc-compose/docs
RUN python3 -m venv .venv && \
    .venv/bin/pip install --upgrade pip setuptools wheel

# Copy requirements and install (if they exist in repo)
RUN if [ -f requirements.txt ]; then \
        .venv/bin/pip install -r requirements.txt; \
    else \
        .venv/bin/pip install mkdocs mkdocs-material pymdown-extensions; \
    fi

# Move markdown files to docs subdirectory where MkDocs expects them
RUN echo "=== Reorganizing documentation structure ===" && \
    mkdir -p docs && \
    mv *.md docs/ 2>/dev/null || true && \
    echo "=== Building docs ===" && \
    .venv/bin/mkdocs build --clean && \
    echo "=== Documentation built successfully ===" && \
    ls -la site/ | head -10

# Configure Nginx
RUN rm -f /etc/nginx/http.d/default.conf
COPY config/lxc-docs/nginx/default.conf /etc/nginx/http.d/default.conf

# Copy scripts
COPY config/lxc-docs/scripts/ /docs/scripts/
RUN chmod +x /docs/scripts/*.sh

# Create a simple supervisor config if not provided
RUN if [ ! -f /etc/supervisor.d/supervisord.conf ]; then \
    echo '[supervisord]' > /etc/supervisord.conf && \
    echo 'nodaemon=true' >> /etc/supervisord.conf && \
    echo '[program:nginx]' >> /etc/supervisord.conf && \
    echo 'command=nginx -g "daemon off;"' >> /etc/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisord.conf; \
    fi

# Expose ports
EXPOSE 80 8000

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]