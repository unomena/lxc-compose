# LXC Compose Networking Guide

Complete guide to networking, port forwarding, and security in LXC Compose.

## Table of Contents

- [Networking Overview](#networking-overview)
- [Container Networking](#container-networking)
  - [Bridge Network](#bridge-network)
  - [IP Address Management](#ip-address-management)
  - [Container Communication](#container-communication)
- [Port Forwarding](#port-forwarding)
  - [Exposed Ports](#exposed-ports)
  - [iptables Rules](#iptables-rules)
  - [DNAT Configuration](#dnat-configuration)
- [Security](#security)
  - [Port Isolation](#port-isolation)
  - [Firewall Rules](#firewall-rules)
  - [Best Practices](#best-practices)
- [Hosts File Management](#hosts-file-management)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)

## Networking Overview

LXC Compose provides a secure, isolated networking environment for containers with:

- **Bridge Network**: All containers connect to `lxdbr0` bridge
- **Static IPs**: Containers get consistent IP addresses
- **Name Resolution**: Shared hosts file for container-to-container communication
- **Port Forwarding**: Selective port exposure via iptables DNAT
- **Security**: Default-deny firewall with explicit port allowances

### Network Architecture

```
Internet
    ↓
Host Machine (iptables PREROUTING)
    ↓
lxdbr0 Bridge (10.0.3.0/24)
    ├── Container 1 (10.0.3.100)
    ├── Container 2 (10.0.3.101)
    └── Container 3 (10.0.3.102)
```

## Container Networking

### Bridge Network

All containers connect to the `lxdbr0` bridge network by default:

- **Network**: 10.0.3.0/24
- **Gateway**: 10.0.3.1 (bridge interface)
- **DHCP Range**: 10.0.3.100 - 10.0.3.254
- **DNS**: 10.0.3.1 (provided by LXD)

#### Viewing Bridge Configuration
```bash
# Show bridge details
ip addr show lxdbr0

# Show bridge status
lxc network show lxdbr0

# List connected containers
lxc network list-used lxdbr0
```

### IP Address Management

#### Automatic IP Assignment

Containers receive IPs via DHCP from the bridge:

```bash
# View container IPs
lxc list -c n,4

# Check specific container
lxc list container-name -c 4 --format csv
```

#### IP Tracking

LXC Compose tracks container IPs in `/etc/lxc-compose/container-ips.json`:

```json
{
  "sample-datastore": "10.0.3.100",
  "sample-django-app": "10.0.3.101",
  "sample-worker": "10.0.3.102"
}
```

#### Static IP Assignment (Advanced)

For consistent IPs across restarts:

```bash
# Set static IP for container
lxc config device add container-name eth0 nic \
  nictype=bridged \
  parent=lxdbr0 \
  ipv4.address=10.0.3.150
```

### Container Communication

#### Internal Communication

Containers can communicate using container names:

```yaml
# In application configuration
services:
  app:
    environment:
      DB_HOST: myapp-database  # Container name
      DB_PORT: 5432
      REDIS_HOST: myapp-cache
      REDIS_PORT: 6379
```

#### Testing Connectivity
```bash
# From inside container
lxc exec app-container -- ping database-container
lxc exec app-container -- nc -zv database-container 5432

# Check hosts file
lxc exec app-container -- cat /etc/hosts
```

## Port Forwarding

### Exposed Ports

Only ports listed in `exposed_ports` are accessible from the host:

```yaml
containers:
  myapp:
    exposed_ports:
      - 80    # HTTP
      - 443   # HTTPS
      - 8080  # Alternative HTTP
    # Ports 5432, 6379, etc. remain internal only
```

### iptables Rules

LXC Compose manages iptables rules automatically:

#### DNAT Rules (Port Forwarding)
```bash
# View port forwarding rules
sudo iptables -t nat -L PREROUTING -n -v

# Example output:
# Chain PREROUTING (policy ACCEPT)
# pkts bytes target     prot opt in     out     source    destination
#  100  6000 DNAT       tcp  --  *      *       0.0.0.0/0 0.0.0.0/0    tcp dpt:80 /* lxc-compose:sample-app */ to:10.0.3.101:80
```

#### FORWARD Rules (Access Control)
```bash
# View forward rules
sudo iptables -L FORWARD -n -v

# Example output:
# Chain FORWARD (policy ACCEPT)
# pkts bytes target     prot opt in     out     source    destination
#  100  6000 ACCEPT     tcp  --  *      *       0.0.0.0/0 10.0.3.101   tcp dpt:80 /* lxc-compose:sample-app */
#    0     0 REJECT     tcp  --  *      *       0.0.0.0/0 10.0.3.101   tcp dpt:5432 /* lxc-compose:block-postgres */
```

### DNAT Configuration

#### How DNAT Works

1. **Incoming Traffic**: Arrives at host IP on specific port
2. **PREROUTING Chain**: iptables checks DNAT rules
3. **Address Translation**: Changes destination to container IP:port
4. **Routing**: Forwards packet to container via bridge
5. **Container Receives**: Traffic appears to come from original source

#### Manual DNAT Management
```bash
# Add DNAT rule manually
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 \
  -j DNAT --to-destination 10.0.3.101:80 \
  -m comment --comment "lxc-compose:myapp"

# Remove DNAT rule
sudo iptables -t nat -D PREROUTING -p tcp --dport 80 \
  -j DNAT --to-destination 10.0.3.101:80 \
  -m comment --comment "lxc-compose:myapp"

# List rules with line numbers
sudo iptables -t nat -L PREROUTING --line-numbers -n
```

## Security

### Port Isolation

By default, ALL ports are blocked except those explicitly exposed:

```yaml
containers:
  database:
    # No exposed_ports = completely isolated
    packages: [postgresql]
  
  app:
    exposed_ports: [80]  # Only port 80 accessible
    depends_on: [database]
    # Can still connect to database internally
```

### Firewall Rules

#### Default Security Rules

LXC Compose implements defense-in-depth:

1. **No exposed_ports**: Container completely isolated from external access
2. **With exposed_ports**: Only specified ports accessible
3. **Internal traffic**: Containers can communicate freely
4. **External traffic**: Must go through DNAT rules

#### Security Rule Examples
```bash
# Block all external access to PostgreSQL
sudo iptables -A FORWARD -p tcp --dport 5432 \
  -d 10.0.3.0/24 -j REJECT \
  -m comment --comment "lxc-compose:block-postgres"

# Allow only specific source IP
sudo iptables -I FORWARD -p tcp --dport 80 \
  -s 192.168.1.100 -d 10.0.3.101 -j ACCEPT \
  -m comment --comment "lxc-compose:whitelist"

# Rate limiting
sudo iptables -I FORWARD -p tcp --dport 80 \
  -d 10.0.3.101 -m limit --limit 100/min -j ACCEPT \
  -m comment --comment "lxc-compose:rate-limit"
```

### Best Practices

1. **Minimize Exposed Ports**: Only expose what's absolutely necessary
2. **Use Reverse Proxy**: Expose only nginx/haproxy, not application ports
3. **Internal Services**: Keep databases, caches, queues internal
4. **Network Segmentation**: Group related containers
5. **Regular Audits**: Check `iptables -L` regularly
6. **Monitoring**: Log suspicious traffic
7. **Updates**: Keep containers and host system updated
8. **Secrets**: Never expose management ports (SSH, admin panels)
9. **SSL/TLS**: Use HTTPS for all external traffic
10. **Fail Secure**: Default deny, explicit allow

## Hosts File Management

### Shared Hosts File

All containers share `/srv/lxc-compose/etc/hosts`:

```bash
# Hosts file content
10.0.3.100  sample-datastore
10.0.3.101  sample-django-app
10.0.3.102  sample-worker
```

### How It Works

1. **Creation**: LXC Compose creates shared hosts file
2. **Mounting**: File is bind-mounted into each container
3. **Updates**: Changes reflect immediately in all containers
4. **Name Resolution**: Containers can use names instead of IPs

### Manual Management
```bash
# View hosts file
cat /srv/lxc-compose/etc/hosts

# Add entry manually
echo "10.0.3.150  custom-container" | sudo tee -a /srv/lxc-compose/etc/hosts

# Verify from container
lxc exec myapp -- ping custom-container
```

### DNS Configuration

Containers use the following DNS resolution order:
1. `/etc/hosts` (includes shared hosts file)
2. LXD DNS (lxdbr0 at 10.0.3.1)
3. Host system DNS

## Troubleshooting

### Common Issues

#### Container Not Accessible

1. **Check container is running**:
   ```bash
   lxc list container-name
   ```

2. **Verify IP address**:
   ```bash
   lxc list container-name -c 4 --format csv
   ```

3. **Check iptables rules**:
   ```bash
   sudo iptables -t nat -L PREROUTING -n | grep container-name
   ```

4. **Test from host**:
   ```bash
   curl -v http://container-ip:port
   ```

#### Port Forwarding Not Working

1. **Verify exposed_ports in config**:
   ```yaml
   exposed_ports:
     - 80
   ```

2. **Check DNAT rule exists**:
   ```bash
   sudo iptables -t nat -L PREROUTING -n | grep "dpt:80"
   ```

3. **Check FORWARD rules**:
   ```bash
   sudo iptables -L FORWARD -n | grep "dpt:80"
   ```

4. **Test directly to container**:
   ```bash
   curl http://10.0.3.101:80  # Using container IP directly
   ```

#### Container Can't Reach Internet

1. **Check NAT masquerading**:
   ```bash
   sudo iptables -t nat -L POSTROUTING -n
   # Should see MASQUERADE rule for 10.0.3.0/24
   ```

2. **Enable IP forwarding**:
   ```bash
   sudo sysctl net.ipv4.ip_forward=1
   ```

3. **Check container DNS**:
   ```bash
   lxc exec container -- cat /etc/resolv.conf
   lxc exec container -- nslookup google.com
   ```

#### Containers Can't Communicate

1. **Check hosts file**:
   ```bash
   lxc exec container1 -- cat /etc/hosts
   ```

2. **Test connectivity**:
   ```bash
   lxc exec container1 -- ping container2
   ```

3. **Check firewall between containers**:
   ```bash
   sudo iptables -L FORWARD -n | grep 10.0.3
   ```

### Debugging Commands

```bash
# Network namespace inspection
sudo ip netns list
sudo ip netns exec container-ns ip addr

# Bridge inspection
brctl show lxdbr0
bridge link show

# Traffic monitoring
sudo tcpdump -i lxdbr0 -n port 80
sudo tcpdump -i any -n host 10.0.3.101

# Connection tracking
sudo conntrack -L | grep 10.0.3

# iptables packet counters
sudo iptables -t nat -L -n -v
sudo iptables -L -n -v

# Container network config
lxc config show container-name | grep -A10 devices

# Reset all iptables rules (CAREFUL!)
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
```

## Examples

### Web Application with Database

```yaml
version: "1.0"

containers:
  # Database - internal only
  app-database:
    template: alpine
    release: "3.19"
    packages: [postgresql]
    # No exposed_ports - completely internal
    
  # Redis cache - internal only  
  app-cache:
    template: alpine
    release: "3.19"
    packages: [redis]
    # No exposed_ports - completely internal
    
  # Web application - exposed
  app-web:
    template: ubuntu-minimal
    release: lts
    depends_on:
      - app-database
      - app-cache
    exposed_ports:
      - 80   # HTTP
      - 443  # HTTPS
    services:
      nginx:
        command: nginx -g "daemon off;"
      app:
        command: python app.py
        environment: |
          DB_HOST=app-database
          DB_PORT=5432
          REDIS_HOST=app-cache
          REDIS_PORT=6379
```

### Microservices Architecture

```yaml
version: "1.0"

containers:
  # API Gateway - exposed
  api-gateway:
    template: alpine
    release: "3.19"
    packages: [nginx]
    exposed_ports: [80, 443]
    
  # Service A - internal
  service-a:
    template: ubuntu-minimal
    release: lts
    packages: [python3]
    # Accessible only from api-gateway
    
  # Service B - internal
  service-b:
    template: ubuntu-minimal
    release: lts
    packages: [nodejs]
    # Accessible only from api-gateway
    
  # Message Queue - internal
  message-queue:
    template: alpine
    release: "3.19"
    packages: [rabbitmq]
    # Services can publish/consume
    
  # Database - internal
  database:
    template: alpine
    release: "3.19"
    packages: [postgresql]
    # Services can query
```

### Development Environment

```yaml
version: "1.0"

containers:
  # Development database - exposed for tools
  dev-db:
    template: alpine
    release: "3.19"
    packages: [postgresql]
    exposed_ports:
      - 5432  # Allow database tools
    
  # Development app - exposed
  dev-app:
    template: ubuntu
    release: jammy
    packages: [python3, nodejs, git]
    exposed_ports:
      - 3000  # Node.js dev server
      - 8000  # Django dev server
      - 5000  # Flask dev server
    mounts:
      - .:/workspace
```

### Security-Hardened Production

```yaml
version: "1.0"

containers:
  # WAF/Reverse Proxy - only exposed container
  waf:
    template: alpine
    release: "3.19"
    packages: [nginx, modsecurity]
    exposed_ports:
      - 443  # HTTPS only
    post_install:
      - name: "Force HTTPS redirect"
        command: |
          # Redirect all HTTP to HTTPS at host level
          iptables -t nat -A PREROUTING -p tcp --dport 80 \
            -j REDIRECT --to-port 443
    
  # Application - internal only
  app:
    template: ubuntu-minimal
    release: lts
    depends_on: [waf]
    # No exposed ports
    
  # Database - internal only
  database:
    template: alpine
    release: "3.19"
    packages: [postgresql]
    # No exposed ports
    post_install:
      - name: "Restrict database access"
        command: |
          # Only allow connections from app container
          echo "host all all 10.0.3.101/32 md5" > /etc/postgresql/pg_hba.conf
```

### Multi-Tenant Isolation

```yaml
version: "1.0"

containers:
  # Tenant A
  tenant-a-app:
    template: ubuntu-minimal
    release: lts
    exposed_ports: [8001]
    
  tenant-a-db:
    template: alpine
    release: "3.19"
    packages: [postgresql]
    # Isolated to tenant-a-app only
    
  # Tenant B  
  tenant-b-app:
    template: ubuntu-minimal
    release: lts
    exposed_ports: [8002]
    
  tenant-b-db:
    template: alpine
    release: "3.19"
    packages: [postgresql]
    # Isolated to tenant-b-app only
    
  # Shared services
  shared-cache:
    template: alpine
    release: "3.19"
    packages: [redis]
    # Accessible by all tenants
```

### Load Balanced Application

```yaml
version: "1.0"

containers:
  # Load balancer - exposed
  loadbalancer:
    template: alpine
    release: "3.19"
    packages: [haproxy]
    exposed_ports: [80, 443]
    post_install:
      - name: "Configure HAProxy"
        command: |
          cat > /etc/haproxy/haproxy.cfg <<EOF
          backend web_servers
            balance roundrobin
            server web1 app-1:8000 check
            server web2 app-2:8000 check
            server web3 app-3:8000 check
          EOF
    
  # Application instances - internal
  app-1:
    template: ubuntu-minimal
    release: lts
    depends_on: [loadbalancer]
    
  app-2:
    template: ubuntu-minimal
    release: lts
    depends_on: [loadbalancer]
    
  app-3:
    template: ubuntu-minimal
    release: lts
    depends_on: [loadbalancer]
    
  # Shared database
  database:
    template: alpine
    release: "3.19"
    packages: [postgresql]
```

## Advanced Topics

### VLAN Support

```bash
# Create VLAN interface
lxc network create vlan100 \
  ipv4.address=192.168.100.1/24 \
  ipv4.nat=true \
  parent=eth0 \
  vlan=100

# Attach container to VLAN
lxc config device add container eth0 nic \
  nictype=bridged \
  parent=vlan100
```

### IPv6 Support

```yaml
# Enable IPv6 in container
post_install:
  - name: "Enable IPv6"
    command: |
      echo "net.ipv6.conf.all.disable_ipv6 = 0" >> /etc/sysctl.conf
      sysctl -p
```

### Custom Bridge Networks

```bash
# Create custom bridge
lxc network create mybr0 \
  ipv4.address=172.16.0.1/24 \
  ipv4.nat=true

# Use in container
lxc launch ubuntu:jammy mycontainer -n mybr0
```

### Network Performance Tuning

```bash
# Increase network buffers
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728"

# Enable TCP BBR congestion control
sudo sysctl -w net.core.default_qdisc=fq
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
```

## Summary

LXC Compose networking provides:

1. **Simplicity**: Automatic network configuration
2. **Security**: Default-deny with explicit port exposure
3. **Flexibility**: Support for various architectures
4. **Performance**: Direct bridge networking
5. **Compatibility**: Standard Linux networking stack

Key takeaways:
- Only expose necessary ports
- Use container names for internal communication
- Monitor iptables rules regularly
- Test connectivity thoroughly
- Document network architecture