# Flask Minimal Sample - Alpine Single Container

An ultra-minimal Flask application with Redis in a single Alpine Linux container.

## Features

- **Single Alpine container** (~100MB total)
- Redis cache and Flask in one container
- Environment-based configuration
- Auto-starts with Supervisor
- Visit counter using Redis
- API endpoints

## Structure

```
flask-app/
├── lxc-compose.yml     # Container configuration
├── requirements.txt    # Python dependencies
├── app.py              # Flask application
├── startup.sh          # Container startup script
├── config/             # Configuration files
│   ├── supervisord.conf        # Main supervisor config
│   └── supervisor.d/           # Service configs
│       ├── redis.ini           # Redis service
│       └── flask.ini           # Flask service
├── .env                # Environment variables
└── README.md           # This file
```

## Usage

1. Navigate to this directory:
   ```bash
   cd ~/lxc-samples/flask-app
   ```

2. Start the container:
   ```bash
   lxc-compose up
   ```

3. Access the application:
   - Flask app: http://localhost:5000
   - Redis: localhost:6379 (optional external access)

## Container Details

- **Base**: Alpine Linux 3.19 (~3MB base)
- **Services** (managed by Supervisor):
  - Redis (running locally)
  - Flask development server
- **Process management**: Supervisor for automatic restarts
- **Total size**: ~100MB (vs ~400MB+ for Ubuntu-based setup)

## Environment Variables

The application uses environment variables for configuration:
- `FLASK_APP`: Flask application file (default: app.py)
- `FLASK_ENV`: Flask environment (default: development)
- `REDIS_HOST`: Redis host (default: localhost)
- `REDIS_PORT`: Redis port (default: 6379)
- `DEBUG`: Debug mode (default: True)

## Benefits of Single Container

- **Simpler deployment**: Only one container to manage
- **Lower resource usage**: Single Alpine container uses minimal RAM/disk
- **Faster startup**: No inter-container networking needed
- **Perfect for development**: Everything in one place

## Notes

- Alpine uses musl libc which may have compatibility issues with some Python packages
- Redis data is stored in `/var/lib/redis` inside the container
- Virtual environment is created at `/app/venv`
- Both Redis and Flask run in the same container managed by Supervisor
- Python packages are installed in a virtual environment for isolation

## Troubleshooting

Check Supervisor status:
```bash
# View all managed processes
lxc exec sample-flask-app -- supervisorctl status

# Restart a specific service
lxc exec sample-flask-app -- supervisorctl restart flask
lxc exec sample-flask-app -- supervisorctl restart redis
```

If Redis doesn't start:
```bash
# Check Redis logs
lxc exec sample-flask-app -- tail -f /var/log/redis/redis.log

# Check Supervisor logs
lxc exec sample-flask-app -- tail -f /var/log/supervisord.log
```

If Flask doesn't connect to Redis:
```bash
# Check Flask logs
lxc exec sample-flask-app -- tail -f /var/log/flask.log

# Test Redis connection
lxc exec sample-flask-app -- redis-cli ping
```

## API Endpoints

- `/` - Home page with visit counter
- `/api/status` - JSON status endpoint
- `/api/increment` - Increment API counter