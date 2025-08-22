# Python3 Library Service

A comprehensive Python 3 development environment available for all base templates.

## What's Included

### Core Python Components
- **Python 3** - Latest Python 3.x from the distribution
- **pip** - Python package installer
- **venv** - Virtual environment support
- **setuptools** - Package development tools
- **wheel** - Built package format

### Build Tools
- **GCC/G++** - C/C++ compilers for building extensions
- **make** - Build automation
- **Build essentials** - Complete compilation toolchain
- **Development headers** - For compiling Python C extensions

### Database Libraries
- **PostgreSQL** development libraries (for psycopg2)
- **MySQL/MariaDB** development libraries (for mysqlclient)
- **SQLite** development libraries

### Common Libraries
Pre-installed development libraries for popular Python packages:
- SSL/TLS support (for requests, urllib3)
- Image processing (PIL/Pillow support)
- XML/XSLT processing
- Compression libraries
- Scientific computing (Ubuntu/Debian only)

### Python Tools
Pre-installed Python development tools:
- **virtualenv** - Virtual environment management
- **pipenv** - Python dependency management
- **poetry** - Modern dependency management
- **black** - Code formatter
- **flake8** - Linting
- **pytest** - Testing framework
- **ipython** - Enhanced Python shell
- **requests** - HTTP library
- **python-dotenv** - Environment variable management

## Usage

### Basic Usage

```yaml
version: '1.0'
containers:
  myapp:
    template: alpine-3.19
    includes:
      - python3  # Include Python 3 environment
```

### With Other Services

```yaml
version: '1.0'
containers:
  webapp:
    template: ubuntu-24.04
    includes:
      - python3      # Python environment
      - postgresql   # Database
      - nginx        # Web server
      - redis        # Cache
```

### Django Example

```yaml
version: '1.0'
containers:
  django-app:
    template: ubuntu-minimal-24.04
    includes:
      - python3
      - postgresql
    
    mounts:
      - ./app:/app
    
    exposed_ports:
      - 8000
    
    post_install:
      - name: "Setup Django"
        command: |
          cd /app
          python3 -m venv venv
          ./venv/bin/pip install -r requirements.txt
          ./venv/bin/python manage.py migrate
    
    services:
      django:
        command: /app/venv/bin/python /app/manage.py runserver 0.0.0.0:8000
```

### Flask Example

```yaml
version: '1.0'
containers:
  flask-app:
    template: alpine-3.19
    includes:
      - python3
      - redis
    
    mounts:
      - ./app:/app
    
    exposed_ports:
      - 5000
    
    post_install:
      - name: "Setup Flask"
        command: |
          cd /app
          python3 -m venv venv
          ./venv/bin/pip install flask redis
    
    services:
      flask:
        command: /app/venv/bin/python /app/app.py
```

### FastAPI Example

```yaml
version: '1.0'
containers:
  fastapi-app:
    template: debian-12
    includes:
      - python3
      - postgresql
    
    exposed_ports:
      - 8000
    
    post_install:
      - name: "Setup FastAPI"
        command: |
          pip install fastapi uvicorn sqlalchemy
    
    services:
      api:
        command: uvicorn main:app --host 0.0.0.0 --port 8000
```

## Available In

The Python3 service is available for all base templates:

| Template | Python Version | Notes |
|----------|---------------|-------|
| `alpine-3.19` | Python 3.11+ | Minimal size, musl libc |
| `ubuntu-24.04` | Python 3.12 | Full Ubuntu, includes scientific libs |
| `ubuntu-22.04` | Python 3.10 | LTS Ubuntu |
| `ubuntu-minimal-24.04` | Python 3.12 | Reduced Ubuntu |
| `ubuntu-minimal-22.04` | Python 3.10 | Reduced Ubuntu LTS |
| `debian-12` | Python 3.11 | Stable Debian |
| `debian-11` | Python 3.9 | Older stable Debian |

## Environment Variables

The service sets these environment variables:

- `PYTHONUNBUFFERED=1` - Ensures output is not buffered
- `PYTHONDONTWRITEBYTECODE=1` - Prevents .pyc file creation
- `PIP_NO_CACHE_DIR=1` - Reduces container size
- `PIP_DISABLE_PIP_VERSION_CHECK=1` - Speeds up pip operations

## Directories Created

- `/app` - Default application directory
- `/var/log/python` - Python application logs
- `/opt/venv/default` - Default virtual environment (Ubuntu/Debian)

## Tips

### Creating Virtual Environments

```bash
# Standard venv
python3 -m venv myenv
source myenv/bin/activate

# Using virtualenv
virtualenv myenv
source myenv/bin/activate

# Using pipenv
pipenv install
pipenv shell

# Using poetry
poetry new myproject
poetry install
```

### Installing Packages

```bash
# System-wide (not recommended)
pip install package

# In virtual environment (recommended)
python3 -m venv venv
./venv/bin/pip install package

# From requirements file
./venv/bin/pip install -r requirements.txt
```

### Compiling C Extensions

All necessary headers and compilers are pre-installed:

```bash
# These will compile successfully
pip install psycopg2
pip install mysqlclient
pip install pillow
pip install numpy
pip install scipy
```

## Differences Between Base Images

### Alpine
- **Pros**: Smallest size (~150MB base)
- **Cons**: Uses musl libc, some packages may need compilation
- **Best for**: Microservices, simple APIs

### Ubuntu
- **Pros**: Most compatible, extensive package repository
- **Cons**: Larger size (~500MB base)
- **Best for**: Complex applications, scientific computing

### Ubuntu Minimal
- **Pros**: Balance of compatibility and size (~300MB base)
- **Cons**: Some packages may need installation
- **Best for**: Production web applications

### Debian
- **Pros**: Very stable, good compatibility
- **Cons**: Older package versions
- **Best for**: Long-running production services

## Testing

Each Python3 service includes tests that verify:
- Python installation and version
- pip functionality
- Virtual environment creation
- Module imports
- Package installation capability

Run tests with:
```bash
lxc-compose test <container-name> internal
```

## Migration from Manual Setup

Before (manual Python setup):
```yaml
packages:
  - python3
  - python3-pip
  - python3-venv
  - python3-dev
  - build-essential
  - libpq-dev
  # ... many more

post_install:
  - name: "Install Python"
    command: |
      apt-get update
      apt-get install -y python3...
      pip install --upgrade pip
      # ... lots of setup
```

After (using Python3 service):
```yaml
includes:
  - python3  # That's it!
```

## Troubleshooting

### Alpine pip issues
If pip is not found on Alpine, it will be automatically installed via ensurepip.

### Compilation errors
All necessary development headers are included. If a package fails to compile, check if it requires additional system libraries.

### Virtual environment issues
Virtual environment support is included and tested. If issues occur, try using the full path to the venv's Python interpreter.

### Import errors
Common modules are pre-installed. For additional packages, install them in your post_install section.