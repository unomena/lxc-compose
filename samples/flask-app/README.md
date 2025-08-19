# Flask Application Sample

A simple Flask application demonstrating the LXC Compose format that matches the reference Django project.

## Structure

```
flask-app/
├── lxc-compose.yml    # Container configuration
├── requirements.txt   # Python dependencies
├── app.py            # Flask application
└── README.md         # This file
```

## Features

- Flask web application with Redis integration
- Nginx reverse proxy
- Supervisor for process management
- Visit counter using Redis
- API endpoints

## Usage

1. Navigate to this directory:
   ```bash
   cd sample-configs/flask-app
   ```

2. Start the containers:
   ```bash
   lxc-compose up
   ```

3. Access the application:
   - Flask app: http://localhost:5000
   - Via Nginx: http://localhost:8080

## Endpoints

- `/` - Home page with visit counter
- `/api/status` - JSON status endpoint
- `/api/increment` - Increment API counter

## Container Structure

- **flask-redis**: Redis server for caching and counters
- **flask-app**: Flask application with Nginx

## Notes

- Source files must exist before running `lxc-compose up`
- The entire directory is mounted into the container
- Virtual environment is created inside the container
- Logs are stored in `/var/log/flask/`