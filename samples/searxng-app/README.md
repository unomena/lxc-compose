# SearXNG Sample Application

A privacy-respecting metasearch engine that aggregates results from multiple search engines without storing your searches.

## Features

- Privacy-focused search engine
- No user tracking or profiling
- Aggregates results from 70+ search engines
- Self-hosted solution
- Image proxy for enhanced privacy
- Customizable search preferences
- Redis caching for improved performance

## Architecture

This sample uses a single Ubuntu Minimal container with:
- **SearXNG**: The metasearch engine application
- **uWSGI**: Python application server
- **Nginx**: Web server and reverse proxy
- **Redis**: In-memory cache for search results
- **Supervisor**: Process management for SearXNG

## Quick Start

1. **Configure environment variables**:
   ```bash
   cp .env.example .env
   # Edit .env and set a secure SEARXNG_SECRET
   # Generate one with: openssl rand -hex 16
   ```

2. **Start the container**:
   ```bash
   lxc-compose up
   ```

3. **Access SearXNG**:
   - Open http://localhost in your browser
   - The container IP will be displayed during startup

## Configuration

### Environment Variables (.env)

- `SEARXNG_SECRET`: Secret key for cookies (required, generate with `openssl rand -hex 16`)
- `SEARXNG_INSTANCE_NAME`: Name displayed in the UI
- `SEARXNG_IMAGE_PROXY`: Enable image proxying for privacy (true/false)
- `SEARXNG_LIMITER`: Enable rate limiting (true/false)
- `DEBUG`: Debug mode (set to False in production)

### Search Engines

Edit `config/sample-searxng-app/settings.yml` to:
- Enable/disable specific search engines
- Configure search preferences
- Set default languages and regions
- Customize UI themes

### Security Settings

The default configuration includes:
- Image proxy enabled for privacy
- Security headers configured in Nginx
- Rate limiting available
- No user tracking

## Customization

### Adding Search Engines

Edit the `engines` section in `settings.yml`:
```yaml
engines:
  - name: custom_engine
    engine: xpath
    shortcut: ce
    disabled: false
    # ... engine-specific settings
```

### Changing Themes

Modify the `ui` section:
```yaml
ui:
  default_theme: simple  # or 'oscar'
  theme_args:
    simple_style: auto  # 'light', 'dark', or 'auto'
```

### Performance Tuning

Adjust uWSGI workers in `config/sample-searxng-app/uwsgi.ini`:
```ini
processes = 4  # Increase for more concurrent searches
threads = 2    # Threads per process
```

## Monitoring

View logs using:
```bash
# SearXNG application logs
lxc-compose logs sample-searxng-app searxng -f

# uWSGI logs
lxc-compose logs sample-searxng-app uwsgi -f

# Nginx access logs
lxc-compose logs sample-searxng-app nginx-access -f

# Redis logs
lxc-compose logs sample-searxng-app redis -f
```

## Troubleshooting

### SearXNG not responding
1. Check if uWSGI is running:
   ```bash
   lxc-compose exec sample-searxng-app supervisorctl status
   ```

2. Test SearXNG directly:
   ```bash
   lxc-compose exec sample-searxng-app curl http://127.0.0.1:8888
   ```

### Search engines blocked
- Some search engines may block/rate-limit your IP
- Check logs for specific engine errors
- Disable problematic engines in settings.yml

### Redis connection issues
1. Verify Redis is running:
   ```bash
   lxc-compose exec sample-searxng-app redis-cli ping
   ```

2. Check Redis logs:
   ```bash
   lxc-compose logs sample-searxng-app redis
   ```

## Production Considerations

1. **Security**:
   - Always set a strong `SEARXNG_SECRET`
   - Consider enabling `SEARXNG_LIMITER` to prevent abuse
   - Use HTTPS in production (configure in Nginx)

2. **Performance**:
   - Increase uWSGI workers for high traffic
   - Configure Redis memory limits appropriately
   - Enable result caching in settings.yml

3. **Privacy**:
   - Enable image proxy (`SEARXNG_IMAGE_PROXY=true`)
   - Configure `hostname_replace` for additional privacy
   - Review and disable engines that don't respect privacy

## Resources

- [SearXNG Documentation](https://docs.searxng.org/)
- [SearXNG GitHub](https://github.com/searxng/searxng)
- [Public SearXNG Instances](https://searx.space/)
- [Configuration Reference](https://docs.searxng.org/admin/settings/index.html)