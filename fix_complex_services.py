#!/usr/bin/env python3
"""
Fix complex services that need special handling
"""

from pathlib import Path

def fix_mongodb(base_path):
    """Fix MongoDB for all non-Alpine distributions"""
    
    ubuntu_init = """
          # Install MongoDB
          wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
          echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
          apt-get update
          apt-get install -y mongodb-org
          
          # Create data directory
          mkdir -p /data/db
          chown -R mongodb:mongodb /data/db
          
          # Configure MongoDB
          sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
          
          # Start MongoDB
          systemctl enable mongod
          systemctl start mongod
          sleep 5"""
    
    debian_init = """
          # Install MongoDB
          wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
          echo "deb http://repo.mongodb.org/apt/debian $(lsb_release -cs)/mongodb-org/6.0 main" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
          apt-get update
          apt-get install -y mongodb-org
          
          # Create data directory
          mkdir -p /data/db
          chown -R mongodb:mongodb /data/db
          
          # Configure MongoDB
          sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
          
          # Start MongoDB
          systemctl enable mongod
          systemctl start mongod
          sleep 5"""
    
    minimal_init = """
          # Note: MongoDB is complex for minimal installations
          echo "MongoDB requires manual installation on minimal systems"
          echo "Consider using full Ubuntu instead"
          exit 1"""
    
    configs = {
        "ubuntu/22.04": ubuntu_init,
        "ubuntu/24.04": ubuntu_init.replace("6.0", "7.0"),  # MongoDB 7 for Ubuntu 24.04
        "debian/11": debian_init,
        "debian/12": debian_init,
        "ubuntu-minimal/22.04": minimal_init,
        "ubuntu-minimal/24.04": minimal_init,
    }
    
    for path, init_cmd in configs.items():
        fix_service(base_path / path / "mongodb", "mongodb", 
                   ["wget", "gnupg", "lsb-release", "apt-transport-https"],
                   init_cmd)

def fix_rabbitmq(base_path):
    """Fix RabbitMQ for all distributions"""
    
    ubuntu_init = """
          # Start RabbitMQ
          systemctl enable rabbitmq-server
          systemctl start rabbitmq-server
          sleep 5
          
          # Enable management plugin
          rabbitmq-plugins enable rabbitmq_management
          
          # Create admin user
          RABBITMQ_USER=${RABBITMQ_DEFAULT_USER:-admin}
          RABBITMQ_PASS=${RABBITMQ_DEFAULT_PASS:-admin}
          rabbitmqctl add_user $RABBITMQ_USER $RABBITMQ_PASS
          rabbitmqctl set_user_tags $RABBITMQ_USER administrator
          rabbitmqctl set_permissions -p / $RABBITMQ_USER ".*" ".*" ".*"
          
          # Delete guest user
          rabbitmqctl delete_user guest || true
          
          systemctl restart rabbitmq-server"""
    
    configs = {
        "ubuntu/22.04": ubuntu_init,
        "ubuntu/24.04": ubuntu_init,
        "debian/11": ubuntu_init,
        "debian/12": ubuntu_init,
    }
    
    for path, init_cmd in configs.items():
        fix_service(base_path / path / "rabbitmq", "RabbitMQ",
                   ["rabbitmq-server"],
                   init_cmd)

def fix_elasticsearch(base_path):
    """Fix Elasticsearch for all distributions"""
    
    ubuntu_init = """
          # Add Elastic repository
          wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
          echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list
          apt-get update
          
          # Install Elasticsearch
          apt-get install -y elasticsearch
          
          # Configure for single-node
          cat >> /etc/elasticsearch/elasticsearch.yml << 'EOF'
          network.host: 0.0.0.0
          discovery.type: single-node
          xpack.security.enabled: false
          EOF
          
          # Set JVM heap
          sed -i 's/-Xms.*/-Xms512m/' /etc/elasticsearch/jvm.options
          sed -i 's/-Xmx.*/-Xmx512m/' /etc/elasticsearch/jvm.options
          
          # Start Elasticsearch
          systemctl enable elasticsearch
          systemctl start elasticsearch
          
          # Wait for it to be ready
          for i in {1..30}; do
            if curl -s http://localhost:9200 >/dev/null; then
              break
            fi
            sleep 2
          done"""
    
    configs = {
        "ubuntu/22.04": ubuntu_init,
        "ubuntu/24.04": ubuntu_init,
        "debian/11": ubuntu_init,
        "debian/12": ubuntu_init,
    }
    
    for path, init_cmd in configs.items():
        fix_service(base_path / path / "elasticsearch", "Elasticsearch",
                   ["wget", "gnupg", "apt-transport-https", "default-jdk"],
                   init_cmd)

def fix_grafana(base_path):
    """Fix Grafana for all distributions"""
    
    ubuntu_init = """
          # Add Grafana repository
          wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
          add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
          apt-get update
          
          # Install Grafana
          apt-get install -y grafana
          
          # Configure
          sed -i 's/;http_addr =.*/http_addr = 0.0.0.0/' /etc/grafana/grafana.ini
          
          # Set admin password
          GF_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD:-admin}
          sed -i "s/;admin_password =.*/admin_password = $GF_ADMIN_PASSWORD/" /etc/grafana/grafana.ini
          
          # Start Grafana
          systemctl enable grafana-server
          systemctl start grafana-server"""
    
    debian_init = ubuntu_init.replace("add-apt-repository", "echo")  # Debian doesn't have add-apt-repository by default
    
    configs = {
        "ubuntu/22.04": ubuntu_init,
        "ubuntu/24.04": ubuntu_init,
        "debian/11": debian_init,
        "debian/12": debian_init,
    }
    
    for path, init_cmd in configs.items():
        fix_service(base_path / path / "grafana", "Grafana",
                   ["wget", "gnupg", "apt-transport-https", "software-properties-common"],
                   init_cmd)

def fix_prometheus(base_path):
    """Fix Prometheus for all distributions"""
    
    init_cmd = """
          # Download Prometheus
          PROM_VERSION="2.45.0"
          ARCH=$(dpkg --print-architecture)
          if [ "$ARCH" = "arm64" ]; then
            ARCH="arm64"
          else
            ARCH="amd64"
          fi
          
          wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz
          tar xvf prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz
          
          # Install binaries
          cp prometheus-${PROM_VERSION}.linux-${ARCH}/prometheus /usr/local/bin/
          cp prometheus-${PROM_VERSION}.linux-${ARCH}/promtool /usr/local/bin/
          
          # Create directories
          mkdir -p /etc/prometheus /var/lib/prometheus
          
          # Create basic config
          cat > /etc/prometheus/prometheus.yml << 'EOF'
          global:
            scrape_interval: 15s
          scrape_configs:
            - job_name: 'prometheus'
              static_configs:
                - targets: ['localhost:9090']
          EOF
          
          # Create systemd service
          cat > /etc/systemd/system/prometheus.service << 'EOF'
          [Unit]
          Description=Prometheus
          After=network.target
          
          [Service]
          Type=simple
          ExecStart=/usr/local/bin/prometheus \
            --config.file=/etc/prometheus/prometheus.yml \
            --storage.tsdb.path=/var/lib/prometheus/ \
            --web.listen-address=0.0.0.0:9090
          
          [Install]
          WantedBy=multi-user.target
          EOF
          
          # Start Prometheus
          systemctl daemon-reload
          systemctl enable prometheus
          systemctl start prometheus"""
    
    configs = {
        "ubuntu/22.04": init_cmd,
        "ubuntu/24.04": init_cmd,
        "debian/11": init_cmd,
        "debian/12": init_cmd,
    }
    
    for path, init_cmd in configs.items():
        fix_service(base_path / path / "prometheus", "Prometheus",
                   ["wget"],
                   init_cmd)

def fix_service(service_path, service_name, packages, init_cmd):
    """Update a service configuration file"""
    
    config_file = service_path / "lxc-compose.yml"
    if not config_file.exists():
        return
    
    # Read current config
    content = config_file.read_text()
    
    # Replace packages
    packages_str = '\n'.join(f'      - {pkg}' for pkg in packages)
    import re
    content = re.sub(
        r'    packages:.*?(?=\n    [a-z]|\n\n|\Z)',
        f'    packages:\n{packages_str}',
        content,
        flags=re.DOTALL
    )
    
    # Replace post_install command
    content = re.sub(
        r'command: \|.*?echo ".*? is ready!"',
        f'command: |\n{init_cmd}\n          echo "{service_name} is ready!"',
        content,
        flags=re.DOTALL
    )
    
    # Write back
    config_file.write_text(content)
    print(f"Fixed {service_name} at {service_path}")

def main():
    library_path = Path("library")
    
    print("Fixing MongoDB...")
    fix_mongodb(library_path)
    
    print("\nFixing RabbitMQ...")
    fix_rabbitmq(library_path)
    
    print("\nFixing Elasticsearch...")
    fix_elasticsearch(library_path)
    
    print("\nFixing Grafana...")
    fix_grafana(library_path)
    
    print("\nFixing Prometheus...")
    fix_prometheus(library_path)

if __name__ == "__main__":
    main()