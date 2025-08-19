# Node.js Application Sample

A Node.js application with MongoDB following the reference project format.

## Structure

```
nodejs-app/
├── lxc-compose.yml    # Container configuration
├── package.json       # Node.js dependencies
├── server.js         # Express server
└── README.md         # This file
```

## Features

- Express.js web server
- MongoDB integration
- Visit tracking
- Nginx reverse proxy
- Supervisor for process management

## Usage

1. Navigate to this directory:
   ```bash
   cd sample-configs/nodejs-app
   ```

2. Start the containers:
   ```bash
   lxc-compose up
   ```

3. Access the application:
   - Node.js app: http://localhost:3000
   - Via Nginx: http://localhost:8080

## API Endpoints

- `/` - Home page with visit counter
- `/api/status` - JSON status endpoint
- `/api/visits` - Recent visits (last 10)

## Container Structure

- **nodejs-mongo**: MongoDB database server
- **nodejs-app**: Node.js application with Nginx

## Environment Variables

- `NODE_ENV`: Node environment (default: development)
- `PORT`: Application port (default: 3000)
- `MONGO_URL`: MongoDB connection URL

## Notes

- Source files must exist before running `lxc-compose up`
- Node.js is installed during container setup
- Dependencies are installed from package.json
- Logs are stored in `/var/log/nodejs/`