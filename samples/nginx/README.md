# Simple Nginx Web Server

Minimal Nginx setup following Docker's official nginx image conventions.

## Quick Start

```bash
lxc-compose up
```

## Features

- Serves static content from `/usr/share/nginx/html`
- Custom config support via `/etc/nginx/conf.d`
- Ports 80 and 443 exposed

## Directory Structure

```
nginx/
├── html/          # Web content (mounted to /usr/share/nginx/html)
│   └── index.html # Your static files
└── conf.d/        # Additional nginx configs (mounted to /etc/nginx/conf.d)
    └── site.conf  # Custom site configuration
```

## Examples

### Custom Site Configuration

Create `conf.d/mysite.conf`:
```nginx
server {
    listen 80;
    server_name myapp.local;
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Reverse Proxy Configuration

Create `conf.d/proxy.conf`:
```nginx
server {
    listen 80;
    server_name api.local;
    
    location / {
        proxy_pass http://backend-container:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Connect

```bash
# Get container IP
lxc list nginx

# Test with curl
curl http://<container-ip>

# View logs
lxc exec nginx -- tail -f /var/log/nginx/access.log
```