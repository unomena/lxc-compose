#!/usr/bin/env python3
"""
Generate all service variants for all base images
"""

import os
import shutil
from pathlib import Path

# Define all base images
BASE_IMAGES = [
    ("alpine", "3.19", "images:alpine/3.19"),
    ("ubuntu", "22.04", "ubuntu:22.04"),
    ("ubuntu", "24.04", "ubuntu:24.04"),
    ("ubuntu-minimal", "22.04", "ubuntu-minimal:22.04"),
    ("ubuntu-minimal", "24.04", "ubuntu-minimal:24.04"),
    ("debian", "11", "debian:11"),
    ("debian", "12", "debian:12"),
]

# Define all services
SERVICES = [
    "postgresql",
    "mysql", 
    "mongodb",
    "redis",
    "nginx",
    "haproxy",
    "memcached",
    "rabbitmq",
    "elasticsearch",
    "grafana",
    "prometheus"
]

def get_service_config(service, distro, version, image):
    """Get service-specific configuration for each base image"""
    
    configs = {
        "postgresql": {
            "alpine": {
                "packages": ["postgresql15", "postgresql15-client"],
                "init": """
          # Create directories
          mkdir -p /run/postgresql /var/lib/postgresql/data
          chown -R postgres:postgres /run/postgresql /var/lib/postgresql
          chmod 700 /var/lib/postgresql/data
          
          # Initialize database
          su postgres -c "initdb -D /var/lib/postgresql/data"
          
          # Configure for network access
          echo "host all all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
          echo "listen_addresses = '*'" >> /var/lib/postgresql/data/postgresql.conf
          
          # Start PostgreSQL
          su postgres -c "pg_ctl -D /var/lib/postgresql/data start"
          sleep 3"""
            },
            "ubuntu": {
                "packages": ["postgresql", "postgresql-client", "postgresql-contrib"],
                "init": """
          # Start PostgreSQL service
          service postgresql start
          sleep 3
          
          # Get PostgreSQL version
          PG_VERSION=$(ls /etc/postgresql/ | head -1)"""
            },
            "ubuntu-minimal": {
                "packages": ["postgresql", "postgresql-client"],
                "init": """
          # Create run directory
          mkdir -p /run/postgresql
          chown postgres:postgres /run/postgresql
          
          # Get PostgreSQL version
          PG_VERSION=$(ls /usr/lib/postgresql/ | head -1)
          
          # Initialize database
          sudo -u postgres /usr/lib/postgresql/$PG_VERSION/bin/initdb -D /var/lib/postgresql/$PG_VERSION/main"""
            },
            "debian": {
                "packages": ["postgresql", "postgresql-client", "postgresql-contrib"],
                "init": """
          # Start PostgreSQL service
          service postgresql start
          sleep 3
          
          # Get PostgreSQL version
          PG_VERSION=$(ls /etc/postgresql/ | head -1)"""
            }
        },
        "redis": {
            "alpine": {
                "packages": ["redis"],
                "init": """
          # Configure Redis for network access
          cat > /etc/redis.conf << 'EOF'
          bind 0.0.0.0
          port 6379
          dir /data
          logfile ""
          protected-mode no
          EOF
          
          # Start Redis
          redis-server /etc/redis.conf --daemonize yes
          sleep 2"""
            },
            "ubuntu": {
                "packages": ["redis-server"],
                "init": """
          # Configure Redis for network access
          sed -i 's/^bind 127.0.0.1.*/bind 0.0.0.0/' /etc/redis/redis.conf
          sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
          
          # Restart Redis
          systemctl restart redis-server
          sleep 2"""
            },
            "ubuntu-minimal": {
                "packages": ["redis-server"],
                "init": """
          # Configure Redis
          sed -i 's/^bind 127.0.0.1.*/bind 0.0.0.0/' /etc/redis/redis.conf
          sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
          
          # Start Redis manually
          redis-server /etc/redis/redis.conf --daemonize yes
          sleep 2"""
            },
            "debian": {
                "packages": ["redis-server"],
                "init": """
          # Configure Redis for network access
          sed -i 's/^bind 127.0.0.1.*/bind 0.0.0.0/' /etc/redis/redis.conf
          sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf
          
          # Restart Redis
          systemctl restart redis-server
          sleep 2"""
            }
        },
        "nginx": {
            "alpine": {
                "packages": ["nginx"],
                "init": """
          # Create necessary directories
          mkdir -p /run/nginx /usr/share/nginx/html
          
          # Start nginx
          nginx"""
            },
            "ubuntu": {
                "packages": ["nginx"],
                "init": """
          # Start nginx
          systemctl enable nginx
          systemctl start nginx"""
            },
            "ubuntu-minimal": {
                "packages": ["nginx"],
                "init": """
          # Start nginx manually
          nginx"""
            },
            "debian": {
                "packages": ["nginx"],
                "init": """
          # Start nginx
          systemctl enable nginx
          systemctl start nginx"""
            }
        },
        "mysql": {
            "alpine": {
                "packages": ["mariadb", "mariadb-client"],
                "init": """
          # Note: MariaDB on Alpine
          mysql_install_db --user=mysql --datadir=/var/lib/mysql
          mysqld_safe &
          sleep 5"""
            },
            "ubuntu": {
                "packages": ["mysql-server", "mysql-client"],
                "init": """
          # Start MySQL service
          service mysql start
          sleep 5"""
            },
            "ubuntu-minimal": {
                "packages": ["mysql-server", "mysql-client"],
                "init": """
          # Start MySQL manually
          mysqld_safe &
          sleep 5"""
            },
            "debian": {
                "packages": ["default-mysql-server", "default-mysql-client"],
                "init": """
          # Start MySQL service
          service mysql start
          sleep 5"""
            }
        },
        "memcached": {
            "alpine": {
                "packages": ["memcached"],
                "init": """
          # Start memcached
          memcached -d -m 64 -c 1024 -l 0.0.0.0 -p 11211 -u nobody"""
            },
            "ubuntu": {
                "packages": ["memcached"],
                "init": """
          # Configure and start memcached
          sed -i 's/-l 127.0.0.1/-l 0.0.0.0/' /etc/memcached.conf
          systemctl restart memcached"""
            },
            "ubuntu-minimal": {
                "packages": ["memcached"],
                "init": """
          # Start memcached manually
          memcached -d -m 64 -c 1024 -l 0.0.0.0 -p 11211 -u nobody"""
            },
            "debian": {
                "packages": ["memcached"],
                "init": """
          # Configure and start memcached
          sed -i 's/-l 127.0.0.1/-l 0.0.0.0/' /etc/memcached.conf
          systemctl restart memcached"""
            }
        },
        "haproxy": {
            "alpine": {
                "packages": ["haproxy"],
                "init": """
          # Start HAProxy
          haproxy -f /etc/haproxy/haproxy.cfg"""
            },
            "ubuntu": {
                "packages": ["haproxy"],
                "init": """
          # Enable and start HAProxy
          systemctl enable haproxy
          systemctl start haproxy"""
            },
            "ubuntu-minimal": {
                "packages": ["haproxy"],
                "init": """
          # Start HAProxy manually
          haproxy -f /etc/haproxy/haproxy.cfg -D"""
            },
            "debian": {
                "packages": ["haproxy"],
                "init": """
          # Enable and start HAProxy
          systemctl enable haproxy
          systemctl start haproxy"""
            }
        }
    }
    
    # Get base distro name (without -minimal)
    base_distro = distro.split('-')[0]
    
    if service in configs and base_distro in configs[service]:
        return configs[service][base_distro]
    
    # Return empty config for services not yet defined
    return {"packages": [], "init": "# TODO: Implement for this base image"}

def generate_service(service, distro, version, image):
    """Generate a service configuration for a specific base image"""
    
    config = get_service_config(service, distro, version, image)
    
    # Map service to port
    ports = {
        "postgresql": ["5432"],
        "mysql": ["3306"],
        "mongodb": ["27017"],
        "redis": ["6379"],
        "nginx": ["80", "443"],
        "haproxy": ["80", "443", "8404"],
        "memcached": ["11211"],
        "rabbitmq": ["5672", "15672"],
        "elasticsearch": ["9200", "9300"],
        "grafana": ["3000"],
        "prometheus": ["9090"]
    }
    
    # Get test name
    test_name = {
        "postgresql": "crud",
        "redis": "operations",
        "mysql": "mysql",
        "mongodb": "mongodb",
        "nginx": "nginx",
        "haproxy": "haproxy",
        "memcached": "memcached",
        "rabbitmq": "rabbitmq",
        "elasticsearch": "elasticsearch",
        "grafana": "grafana",
        "prometheus": "prometheus"
    }.get(service, service)
    
    template = f"""# {service.title()} Server - {distro.title()} {version}
# {service.title()} on {distro.title()} {version}
# Usage: lxc-compose up

version: '1.0'

containers:
  {service}:
    image: {image}
    
    exposed_ports:
{chr(10).join(f'      - {port}' for port in ports.get(service, ['8080']))}
    
    packages:
{chr(10).join(f'      - {pkg}' for pkg in config.get('packages', []))}
    
    tests:
      external:
        - {test_name}:/tests/{service}.sh
    
    post_install:
      - name: "Setup {service.title()}"
        command: |
{config.get('init', '          # TODO: Implement')}
          
          echo "{service.title()} is ready!"
"""
    
    return template

def main():
    """Generate all service configurations"""
    
    library_path = Path("library")
    
    for distro, version, image in BASE_IMAGES:
        print(f"\nGenerating services for {distro}/{version}...")
        
        for service in SERVICES:
            # Create directory
            service_dir = library_path / distro / version / service
            service_dir.mkdir(parents=True, exist_ok=True)
            
            # Check if already exists
            config_file = service_dir / "lxc-compose.yml"
            if config_file.exists():
                print(f"  ✓ {service} already exists")
                continue
            
            # Generate configuration
            config = generate_service(service, distro, version, image)
            config_file.write_text(config)
            print(f"  + Generated {service}")
            
            # Create tests directory
            tests_dir = service_dir / "tests"
            tests_dir.mkdir(exist_ok=True)
            
            # Copy test from Alpine if it exists and we don't have one
            test_file = tests_dir / f"{service}.sh"
            if not test_file.exists():
                alpine_test = library_path / "alpine" / "3.19" / service / "tests"
                if alpine_test.exists():
                    # Copy all test files
                    for test in alpine_test.glob("*.sh"):
                        shutil.copy2(test, tests_dir / test.name)
                    print(f"    + Copied tests for {service}")

if __name__ == "__main__":
    main()