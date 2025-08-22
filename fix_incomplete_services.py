#!/usr/bin/env python3
"""Fix all incomplete service implementations with proper configurations"""

import os
import glob

# Service implementations for each type
IMPLEMENTATIONS = {
    'elasticsearch': {
        'alpine': {
            'packages': ['openjdk11-jre', 'curl', 'bash'],
            'post_install': '''# Note: Elasticsearch requires manual download on Alpine
          # Download and install Elasticsearch
          cd /tmp
          wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.9-linux-x86_64.tar.gz
          tar -xzf elasticsearch-7.17.9-linux-x86_64.tar.gz
          mv elasticsearch-7.17.9 /opt/elasticsearch
          
          # Create elasticsearch user
          adduser -D -h /opt/elasticsearch elasticsearch
          chown -R elasticsearch:elasticsearch /opt/elasticsearch
          
          # Configure Elasticsearch
          cat > /opt/elasticsearch/config/elasticsearch.yml << EOF
network.host: 0.0.0.0
discovery.type: single-node
xpack.security.enabled: false
EOF
          
          # Create startup script
          cat > /usr/local/bin/start-elasticsearch.sh << 'SCRIPT'
#!/bin/sh
su - elasticsearch -c "ES_JAVA_OPTS='-Xms512m -Xmx512m' /opt/elasticsearch/bin/elasticsearch"
SCRIPT
          chmod +x /usr/local/bin/start-elasticsearch.sh
          
          # Start Elasticsearch in background
          nohup /usr/local/bin/start-elasticsearch.sh > /var/log/elasticsearch.log 2>&1 &
          
          # Wait for Elasticsearch to start
          sleep 30
          
          # Test connection
          curl -X GET "localhost:9200/" || echo "Elasticsearch starting..."'''
        },
        'ubuntu': {
            'packages': ['curl', 'gnupg', 'apt-transport-https'],
            'post_install': '''# Install Elasticsearch from official repository
          curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
          echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" > /etc/apt/sources.list.d/elastic-7.x.list
          apt-get update
          apt-get install -y elasticsearch
          
          # Configure Elasticsearch
          cat > /etc/elasticsearch/elasticsearch.yml << EOF
network.host: 0.0.0.0
discovery.type: single-node
xpack.security.enabled: false
EOF
          
          # Start Elasticsearch
          systemctl enable elasticsearch
          systemctl start elasticsearch
          
          # Wait for Elasticsearch to start
          sleep 20
          
          # Test connection
          curl -X GET "localhost:9200/"'''
        },
        'ubuntu-minimal': {
            'packages': ['curl', 'openjdk-11-jre-headless'],
            'post_install': '''# Download and install Elasticsearch manually
          cd /tmp
          wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.17.9-linux-x86_64.tar.gz
          tar -xzf elasticsearch-7.17.9-linux-x86_64.tar.gz
          mv elasticsearch-7.17.9 /opt/elasticsearch
          
          # Create elasticsearch user
          useradd -r -s /bin/false -d /opt/elasticsearch elasticsearch
          chown -R elasticsearch:elasticsearch /opt/elasticsearch
          
          # Configure Elasticsearch
          cat > /opt/elasticsearch/config/elasticsearch.yml << EOF
network.host: 0.0.0.0
discovery.type: single-node
xpack.security.enabled: false
EOF
          
          # Start Elasticsearch
          sudo -u elasticsearch ES_JAVA_OPTS="-Xms512m -Xmx512m" /opt/elasticsearch/bin/elasticsearch -d
          
          # Wait for Elasticsearch to start
          sleep 30
          
          # Test connection
          curl -X GET "localhost:9200/" || echo "Elasticsearch starting..."'''
        }
    },
    'grafana': {
        'alpine': {
            'packages': ['curl'],
            'post_install': '''# Install Grafana on Alpine
          cd /tmp
          wget https://dl.grafana.com/oss/release/grafana-9.5.2.linux-amd64.tar.gz
          tar -xzf grafana-9.5.2.linux-amd64.tar.gz
          mv grafana-9.5.2 /opt/grafana
          
          # Create grafana user
          adduser -D -h /opt/grafana grafana
          chown -R grafana:grafana /opt/grafana
          
          # Configure Grafana
          cat > /opt/grafana/conf/custom.ini << EOF
[server]
http_addr = 0.0.0.0
http_port = 3000

[security]
admin_user = admin
admin_password = admin
EOF
          
          # Create startup script
          cat > /usr/local/bin/start-grafana.sh << 'SCRIPT'
#!/bin/sh
cd /opt/grafana
su - grafana -c "/opt/grafana/bin/grafana-server --config=/opt/grafana/conf/custom.ini --homepath=/opt/grafana"
SCRIPT
          chmod +x /usr/local/bin/start-grafana.sh
          
          # Start Grafana in background
          nohup /usr/local/bin/start-grafana.sh > /var/log/grafana.log 2>&1 &
          
          # Wait for Grafana to start
          sleep 10'''
        },
        'ubuntu': {
            'packages': ['curl', 'gnupg', 'apt-transport-https', 'software-properties-common'],
            'post_install': '''# Install Grafana from official repository
          curl -fsSL https://packages.grafana.com/gpg.key | apt-key add -
          add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
          apt-get update
          apt-get install -y grafana
          
          # Configure Grafana
          cat >> /etc/grafana/grafana.ini << EOF

[server]
http_addr = 0.0.0.0
http_port = 3000
EOF
          
          # Start Grafana
          systemctl enable grafana-server
          systemctl start grafana-server
          
          # Wait for Grafana to start
          sleep 10'''
        },
        'ubuntu-minimal': {
            'packages': ['curl'],
            'post_install': '''# Download and install Grafana manually
          cd /tmp
          wget https://dl.grafana.com/oss/release/grafana_9.5.2_amd64.deb
          dpkg -i grafana_9.5.2_amd64.deb || apt-get install -f -y
          
          # Configure Grafana
          cat >> /etc/grafana/grafana.ini << EOF

[server]
http_addr = 0.0.0.0
http_port = 3000
EOF
          
          # Start Grafana manually
          /usr/sbin/grafana-server --config=/etc/grafana/grafana.ini --homepath=/usr/share/grafana &
          
          # Wait for Grafana to start
          sleep 10'''
        }
    },
    'prometheus': {
        'alpine': {
            'packages': ['curl'],
            'post_install': '''# Install Prometheus on Alpine
          cd /tmp
          wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
          tar -xzf prometheus-2.45.0.linux-amd64.tar.gz
          mv prometheus-2.45.0.linux-amd64 /opt/prometheus
          
          # Create prometheus user
          adduser -D -h /opt/prometheus prometheus
          chown -R prometheus:prometheus /opt/prometheus
          
          # Basic configuration
          cat > /opt/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
EOF
          
          # Create startup script
          cat > /usr/local/bin/start-prometheus.sh << 'SCRIPT'
#!/bin/sh
cd /opt/prometheus
su - prometheus -c "/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data"
SCRIPT
          chmod +x /usr/local/bin/start-prometheus.sh
          
          # Start Prometheus in background
          nohup /usr/local/bin/start-prometheus.sh > /var/log/prometheus.log 2>&1 &
          
          # Wait for Prometheus to start
          sleep 5'''
        },
        'ubuntu': {
            'packages': ['curl'],
            'post_install': '''# Install Prometheus
          cd /tmp
          wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
          tar -xzf prometheus-2.45.0.linux-amd64.tar.gz
          mv prometheus-2.45.0.linux-amd64 /opt/prometheus
          
          # Create prometheus user
          useradd -r -s /bin/false prometheus
          chown -R prometheus:prometheus /opt/prometheus
          
          # Basic configuration
          cat > /opt/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
EOF
          
          # Create systemd service
          cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
          
          # Start Prometheus
          systemctl daemon-reload
          systemctl enable prometheus
          systemctl start prometheus
          
          # Wait for Prometheus to start
          sleep 5'''
        },
        'ubuntu-minimal': {
            'packages': ['curl', 'wget'],
            'post_install': '''# Install Prometheus manually
          cd /tmp
          wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
          tar -xzf prometheus-2.45.0.linux-amd64.tar.gz
          mv prometheus-2.45.0.linux-amd64 /opt/prometheus
          
          # Create prometheus user
          useradd -r -s /bin/false prometheus || true
          chown -R prometheus:prometheus /opt/prometheus
          
          # Basic configuration
          cat > /opt/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['localhost:9090']
EOF
          
          # Start Prometheus
          sudo -u prometheus /opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data &
          
          # Wait for Prometheus to start
          sleep 5'''
        }
    },
    'rabbitmq': {
        'alpine': {
            'packages': ['rabbitmq-server'],
            'post_install': '''# Configure and start RabbitMQ
          # Enable management plugin
          rabbitmq-plugins enable rabbitmq_management
          
          # Start RabbitMQ
          rc-service rabbitmq-server start
          rc-update add rabbitmq-server default
          
          # Wait for RabbitMQ to start
          sleep 10
          
          # Create admin user
          rabbitmqctl add_user admin admin || true
          rabbitmqctl set_user_tags admin administrator || true
          rabbitmqctl set_permissions -p / admin ".*" ".*" ".*" || true'''
        },
        'ubuntu': {
            'packages': ['rabbitmq-server'],
            'post_install': '''# Configure and start RabbitMQ
          # Enable management plugin
          rabbitmq-plugins enable rabbitmq_management
          
          # Start RabbitMQ
          systemctl enable rabbitmq-server
          systemctl start rabbitmq-server
          
          # Wait for RabbitMQ to start
          sleep 10
          
          # Create admin user
          rabbitmqctl add_user admin admin || true
          rabbitmqctl set_user_tags admin administrator || true
          rabbitmqctl set_permissions -p / admin ".*" ".*" ".*" || true'''
        },
        'ubuntu-minimal': {
            'packages': ['rabbitmq-server'],
            'post_install': '''# Configure and start RabbitMQ
          # Enable management plugin
          rabbitmq-plugins enable rabbitmq_management
          
          # Start RabbitMQ manually
          /usr/sbin/rabbitmq-server -detached
          
          # Wait for RabbitMQ to start
          sleep 15
          
          # Create admin user
          rabbitmqctl add_user admin admin || true
          rabbitmqctl set_user_tags admin administrator || true
          rabbitmqctl set_permissions -p / admin ".*" ".*" ".*" || true'''
        }
    },
    'mongodb': {
        'alpine': {
            'packages': ['mongodb', 'mongodb-tools'],
            'post_install': '''# Configure and start MongoDB
          # Create data directory
          mkdir -p /data/db
          chown mongodb:mongodb /data/db
          
          # Create config file
          cat > /etc/mongod.conf << EOF
storage:
  dbPath: /data/db
net:
  bindIp: 0.0.0.0
  port: 27017
EOF
          
          # Start MongoDB
          mongod --config /etc/mongod.conf --fork --logpath /var/log/mongodb.log
          
          # Wait for MongoDB to start
          sleep 5
          
          # Test connection
          mongo --eval "db.version()" || echo "MongoDB starting..."'''
        }
    }
}

def fix_service(file_path, service_type, os_type):
    """Fix a single service file"""
    # Determine the OS category
    if 'alpine' in file_path:
        os_category = 'alpine'
    elif 'ubuntu-minimal' in file_path:
        os_category = 'ubuntu-minimal'
    elif 'ubuntu' in file_path:
        os_category = 'ubuntu'
    elif 'debian' in file_path:
        os_category = 'ubuntu'  # Debian uses same as Ubuntu
    else:
        return False
    
    # Get the implementation
    if service_type not in IMPLEMENTATIONS:
        print(f"  No implementation for {service_type}")
        return False
    
    if os_category not in IMPLEMENTATIONS[service_type]:
        print(f"  No implementation for {service_type} on {os_category}")
        return False
    
    impl = IMPLEMENTATIONS[service_type][os_category]
    
    # Read the current file
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    # Find and replace the packages section
    new_lines = []
    in_packages = False
    in_post_install = False
    skip_todo = False
    
    for line in lines:
        if 'packages:' in line and not line.strip().startswith('#'):
            new_lines.append(line)
            in_packages = True
            # Add packages
            for pkg in impl['packages']:
                new_lines.append(f'      - {pkg}\n')
        elif in_packages and line.strip() and not line.strip().startswith('-'):
            in_packages = False
            new_lines.append(line)
        elif '# TODO: Implement for this base image' in line:
            skip_todo = True
            # Replace with actual implementation
            new_lines.append(impl['post_install'] + '\n')
        elif skip_todo and line.strip() == '':
            skip_todo = False
            continue
        elif not in_packages and not skip_todo:
            new_lines.append(line)
    
    # Write back
    with open(file_path, 'w') as f:
        f.writelines(new_lines)
    
    return True

def main():
    print("Fixing incomplete service implementations...")
    print("=" * 60)
    
    # Find all files with TODO
    todo_files = []
    for file_path in glob.glob('library/**/*.yml', recursive=True):
        with open(file_path, 'r') as f:
            if '# TODO: Implement for this base image' in f.read():
                todo_files.append(file_path)
    
    print(f"Found {len(todo_files)} incomplete services")
    print()
    
    fixed_count = 0
    for file_path in todo_files:
        # Extract service type from path
        service_type = os.path.basename(os.path.dirname(file_path))
        print(f"Fixing {file_path} ({service_type})...")
        
        if fix_service(file_path, service_type, file_path):
            print(f"  ✓ Fixed {service_type}")
            fixed_count += 1
        else:
            print(f"  ✗ Could not fix {service_type}")
    
    print()
    print("=" * 60)
    print(f"Fixed {fixed_count} out of {len(todo_files)} services")

if __name__ == '__main__':
    main()