#!/usr/bin/env python3

"""
LXC Compose Manager - Complete web interface for LXC container management
"""

from flask import Flask, render_template, jsonify, request, url_for, session
from flask_socketio import SocketIO, emit
import json
import subprocess
import os
import time
from datetime import datetime
import logging
import secrets
import uuid

app = Flask(__name__)
app.secret_key = os.environ.get('FLASK_SECRET_KEY', secrets.token_hex(32))
socketio = SocketIO(app, cors_allowed_origins="*")

# Store shell sessions (container -> session_id -> working_directory)
shell_sessions = {}

# Configuration
CONFIG_FILE = '/etc/lxc-compose/registry.json'
IPTABLES_RULES_FILE = '/etc/lxc-compose/port-forwards.json'
LOG_FILE = '/var/log/lxc-compose-manager.log'
WIZARD_CONFIG = '/etc/lxc-compose/wizard-config.json'

# Setup logging
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Container templates (from wizard)
CONTAINER_TEMPLATES = {
    'datastore': {
        'name': 'Database & Cache Server',
        'description': 'PostgreSQL and Redis services',
        'services': ['postgresql', 'redis'],
        'ports': [
            {'name': 'PostgreSQL', 'port': 5432, 'protocol': 'tcp'},
            {'name': 'Redis', 'port': 6379, 'protocol': 'tcp'}
        ]
    },
    'app': {
        'name': 'Application Server',
        'description': 'Web application container',
        'services': ['nginx', 'python', 'nodejs'],
        'ports': [
            {'name': 'HTTP', 'port': 80, 'protocol': 'tcp'},
            {'name': 'HTTPS', 'port': 443, 'protocol': 'tcp'},
            {'name': 'Dev Server', 'port': 8000, 'protocol': 'tcp'}
        ]
    },
    'django': {
        'name': 'Django Application',
        'description': 'Django with Celery and Redis',
        'services': ['django', 'celery', 'nginx'],
        'ports': [
            {'name': 'Web', 'port': 80, 'protocol': 'tcp'},
            {'name': 'Django Dev', 'port': 8000, 'protocol': 'tcp'}
        ]
    }
}

def load_registry():
    """Load container registry from JSON file"""
    if not os.path.exists(CONFIG_FILE):
        return {
            'containers': {},
            'port_forwards': [],
            'network': {
                'bridge': 'lxcbr0',
                'subnet': '10.0.3.0/24',
                'gateway': '10.0.3.1',
                'next_ip': 2
            },
            'last_updated': None
        }
    
    try:
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Error loading registry: {e}")
        return {
            'containers': {},
            'port_forwards': [],
            'network': {
                'bridge': 'lxcbr0',
                'subnet': '10.0.3.0/24',
                'gateway': '10.0.3.1',
                'next_ip': 2
            },
            'last_updated': None
        }

def save_registry(registry):
    """Save container registry to JSON file"""
    registry['last_updated'] = datetime.now().isoformat()
    
    # Ensure directory exists
    os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
    
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(registry, f, indent=2)
        return True
    except Exception as e:
        logger.error(f"Error saving registry: {e}")
        return False

def run_command(command, capture=True, timeout=30):
    """Run a shell command and return the result"""
    try:
        if capture:
            result = subprocess.run(
                command if isinstance(command, list) else command.split(),
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return {
                'success': result.returncode == 0,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'returncode': result.returncode
            }
        else:
            # For long-running commands, run without capturing
            process = subprocess.Popen(
                command if isinstance(command, list) else command.split(),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            return {'success': True, 'process': process}
    except subprocess.TimeoutExpired:
        return {'success': False, 'error': 'Command timed out'}
    except Exception as e:
        logger.error(f"Error running command: {e}")
        return {'success': False, 'error': str(e)}

def get_container_status(container_name):
    """Get the status of a container"""
    result = run_command(f'sudo lxc-info -n {container_name} -s')
    if result['success'] and 'RUNNING' in result['stdout']:
        return 'running'
    elif result['success'] and 'STOPPED' in result['stdout']:
        return 'stopped'
    else:
        return 'unknown'

def get_container_ip(container_name):
    """Get the IP address of a container"""
    result = run_command(f'sudo lxc-info -n {container_name} -iH')
    if result['success']:
        return result['stdout'].strip().split('\n')[0]
    return None

def get_host_ip():
    """Get the host machine's primary IP"""
    result = run_command('ip route get 1.1.1.1')
    if result['success']:
        # Parse output like: "1.1.1.1 via 192.168.1.1 dev eth0 src 192.168.1.100"
        parts = result['stdout'].split()
        if 'src' in parts:
            return parts[parts.index('src') + 1]
    return '0.0.0.0'

def get_all_containers():
    """Get list of all LXC containers with their details"""
    result = run_command('sudo lxc-ls --fancy')
    containers = []
    
    if result['success']:
        lines = result['stdout'].strip().split('\n')
        if len(lines) > 1:  # Skip header
            for line in lines[1:]:
                parts = line.split()
                if len(parts) >= 2:
                    containers.append({
                        'name': parts[0],
                        'state': parts[1],
                        'ipv4': parts[3] if len(parts) > 3 else 'N/A',
                        'ipv6': parts[4] if len(parts) > 4 else 'N/A'
                    })
    
    return containers

def create_container(name, container_type='app', ip_address=None):
    """Create a new LXC container"""
    registry = load_registry()
    
    # Determine IP address
    if not ip_address:
        ip_address = f"10.0.3.{registry['network']['next_ip']}"
        registry['network']['next_ip'] += 1
    
    # Create container
    commands = [
        f'sudo lxc-create -n {name} -t ubuntu -- -r jammy',
        f'sudo lxc-start -n {name}',
        f'sudo lxc-attach -n {name} -- bash -c "apt-get update && apt-get install -y python3 python3-pip nginx"'
    ]
    
    for cmd in commands:
        result = run_command(cmd, timeout=120)
        if not result['success']:
            return {'success': False, 'error': f'Failed to execute: {cmd}'}
    
    # Register container
    registry['containers'][name] = {
        'name': name,
        'type': container_type,
        'ip': ip_address,
        'services': CONTAINER_TEMPLATES.get(container_type, {}).get('services', []),
        'created': datetime.now().isoformat(),
        'status': 'running'
    }
    
    save_registry(registry)
    return {'success': True, 'container': registry['containers'][name]}

@app.route('/health')
def health_check():
    """Health check endpoint"""
    try:
        # Check if we can list containers
        result = subprocess.run(['sudo', 'lxc-ls'], 
                              capture_output=True, 
                              text=True, 
                              timeout=5)
        if result.returncode == 0:
            return jsonify({'status': 'healthy', 'message': 'LXC Compose Manager is running'}), 200
        else:
            return jsonify({'status': 'unhealthy', 'message': 'Cannot access LXC commands'}), 503
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'message': str(e)}), 503

@app.route('/')
def index():
    """Main dashboard"""
    registry = load_registry()
    host_ip = get_host_ip()
    containers = get_all_containers()
    
    return render_template('dashboard.html', 
                         registry=registry, 
                         host_ip=host_ip,
                         containers=containers,
                         templates=CONTAINER_TEMPLATES)

@app.route('/wizard')
def wizard():
    """Container creation wizard"""
    registry = load_registry()
    return render_template('wizard.html', 
                         registry=registry,
                         templates=CONTAINER_TEMPLATES)

@app.route('/api/wizard/create', methods=['POST'])
def api_wizard_create():
    """Create containers using wizard settings"""
    data = request.json
    results = []
    
    # Create datastore if requested
    if data.get('create_datastore'):
        result = create_container('datastore', 'datastore', '10.0.3.2')
        results.append({
            'container': 'datastore',
            'success': result['success'],
            'message': 'Datastore created successfully' if result['success'] else result.get('error')
        })
        
        # Setup PostgreSQL and Redis
        if result['success']:
            setup_commands = [
                'sudo lxc-attach -n datastore -- bash -c "apt-get install -y postgresql redis-server"',
                'sudo lxc-attach -n datastore -- bash -c "systemctl start postgresql redis-server"'
            ]
            for cmd in setup_commands:
                run_command(cmd, timeout=120)
    
    # Create app containers
    for i in range(1, data.get('app_count', 0) + 1):
        container_name = f"app-{i}"
        ip_address = f"10.0.3.{10 + i}"
        result = create_container(container_name, 'app', ip_address)
        results.append({
            'container': container_name,
            'success': result['success'],
            'message': f'App container {i} created' if result['success'] else result.get('error')
        })
    
    # Create Django sample if requested
    if data.get('create_django_sample'):
        # Run the Django sample creation script
        result = run_command('sudo bash /srv/lxc-compose/create-django-sample.sh app-1', timeout=300)
        results.append({
            'container': 'django-sample',
            'success': result['success'],
            'message': 'Django sample deployed' if result['success'] else 'Failed to deploy Django sample'
        })
    
    return jsonify({'success': True, 'results': results})

@app.route('/api/container/<name>/start', methods=['POST'])
def api_container_start(name):
    """Start a container"""
    result = run_command(f'sudo lxc-start -n {name}')
    return jsonify(result)

@app.route('/api/container/<name>/stop', methods=['POST'])
def api_container_stop(name):
    """Stop a container"""
    result = run_command(f'sudo lxc-stop -n {name}')
    return jsonify(result)

@app.route('/api/container/<name>/restart', methods=['POST'])
def api_container_restart(name):
    """Restart a container"""
    stop_result = run_command(f'sudo lxc-stop -n {name}')
    time.sleep(2)
    start_result = run_command(f'sudo lxc-start -n {name}')
    return jsonify({
        'success': start_result['success'],
        'stop': stop_result,
        'start': start_result
    })

@app.route('/api/container/<name>/delete', methods=['DELETE'])
def api_container_delete(name):
    """Delete a container"""
    # Stop container first
    run_command(f'sudo lxc-stop -n {name}')
    time.sleep(2)
    
    # Delete container
    result = run_command(f'sudo lxc-destroy -n {name}')
    
    if result['success']:
        # Remove from registry
        registry = load_registry()
        if name in registry['containers']:
            del registry['containers'][name]
            # Remove associated port forwards
            registry['port_forwards'] = [
                pf for pf in registry['port_forwards']
                if pf['container'] != name
            ]
            save_registry(registry)
    
    return jsonify(result)

@app.route('/api/container/<name>/shell', methods=['GET'])
def api_container_shell(name):
    """Get shell access to a container (WebSocket endpoint)"""
    # Create a session ID for this shell
    session_id = str(uuid.uuid4())
    
    # Initialize session for this container if not exists
    if name not in shell_sessions:
        shell_sessions[name] = {}
    
    # Set initial working directory
    shell_sessions[name][session_id] = '/root'
    
    # Get host IP for display in header
    host_ip = get_host_ip()
    
    return render_template('shell.html', container_name=name, session_id=session_id, host_ip=host_ip)

@app.route('/api/command/execute', methods=['POST'])
def api_command_execute():
    """Execute an LXC Compose command"""
    data = request.json
    command = data.get('command', '')
    
    # Special handling for some commands
    if command == 'list':
        result = run_command('sudo lxc-ls --fancy')
        return jsonify(result)
    
    # Handle attach commands specially (they need interactive terminal)
    if command.startswith('attach '):
        container = command.split()[1] if len(command.split()) > 1 else 'datastore'
        return jsonify({
            'success': True,
            'redirect': f'/api/container/{container}/shell'
        })
    
    # Handle execute commands with session support
    if command.startswith('execute '):
        parts = command.split(None, 2)
        if len(parts) >= 3:
            container = parts[1]
            cmd = parts[2]
            
            # Get session ID and working directory if provided
            session_id = data.get('session_id')
            working_dir = '/root'  # Default working directory
            
            # Get the current working directory for this session
            if session_id and container in shell_sessions and session_id in shell_sessions[container]:
                working_dir = shell_sessions[container][session_id]
            
            # Handle cd command specially
            if cmd.strip().startswith('cd '):
                new_dir = cmd.strip()[3:].strip() or '/root'
                # Handle relative and absolute paths
                if new_dir.startswith('/'):
                    # Absolute path
                    test_dir = new_dir
                elif new_dir == '~':
                    test_dir = '/root'
                elif new_dir == '..':
                    # Go up one directory
                    test_dir = os.path.dirname(working_dir)
                else:
                    # Relative path
                    test_dir = os.path.join(working_dir, new_dir)
                
                # Test if directory exists in container
                test_result = subprocess.run(
                    ['sudo', 'lxc-attach', '-n', container, '--', 'test', '-d', test_dir],
                    capture_output=True,
                    timeout=5
                )
                
                if test_result.returncode == 0:
                    # Update the working directory for this session
                    if session_id and container in shell_sessions:
                        shell_sessions[container][session_id] = test_dir
                    return jsonify({
                        'success': True,
                        'stdout': '',
                        'stderr': '',
                        'working_dir': test_dir
                    })
                else:
                    return jsonify({
                        'success': False,
                        'stdout': '',
                        'stderr': f'cd: {new_dir}: No such file or directory',
                        'working_dir': working_dir
                    })
            
            # For other commands, execute in the working directory
            try:
                # Build command with working directory
                full_cmd = f'cd {working_dir} && {cmd}'
                
                result = subprocess.run(
                    ['sudo', 'lxc-attach', '-n', container, '--', 'bash', '-c', full_cmd],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                # Special handling for pwd command
                if cmd.strip() == 'pwd':
                    return jsonify({
                        'success': True,
                        'stdout': working_dir,
                        'stderr': '',
                        'working_dir': working_dir
                    })
                
                return jsonify({
                    'success': result.returncode == 0 or bool(result.stdout),
                    'stdout': result.stdout,
                    'stderr': result.stderr,
                    'returncode': result.returncode,
                    'working_dir': working_dir
                })
            except subprocess.TimeoutExpired:
                return jsonify({
                    'success': False,
                    'error': 'Command timed out after 30 seconds'
                })
            except Exception as e:
                return jsonify({
                    'success': False,
                    'error': str(e)
                })
    
    # For all other commands, use the actual lxc-compose CLI
    # This ensures commands like 'test db', 'test redis', 'doctor', 'update' work properly
    result = run_command(f'lxc-compose {command}')
    return jsonify(result)

@app.route('/terminal')
def terminal():
    """Terminal interface for running commands"""
    host_ip = get_host_ip()
    return render_template('terminal.html', host_ip=host_ip)

@app.route('/api/port-forward', methods=['GET', 'POST'])
def api_port_forward():
    """Manage port forwards"""
    registry = load_registry()
    
    if request.method == 'GET':
        return jsonify(registry['port_forwards'])
    
    elif request.method == 'POST':
        data = request.json
        
        # Get container IP
        container_ip = get_container_ip(data['container'])
        if not container_ip:
            return jsonify({'success': False, 'error': 'Could not determine container IP'}), 400
        
        # Apply iptables rule
        cmd = f'''sudo iptables -t nat -A PREROUTING -p {data.get('protocol', 'tcp')} \
                  --dport {data['host_port']} -j DNAT \
                  --to-destination {container_ip}:{data['container_port']}'''
        
        result = run_command(cmd)
        
        if result['success']:
            # Save to registry
            port_forward = {
                'id': f"{data['container']}-{data['host_port']}",
                'host_port': data['host_port'],
                'container': data['container'],
                'container_ip': container_ip,
                'container_port': data['container_port'],
                'protocol': data.get('protocol', 'tcp'),
                'service_name': data['service_name'],
                'enabled': True,
                'created': datetime.now().isoformat()
            }
            
            registry['port_forwards'].append(port_forward)
            save_registry(registry)
            
            return jsonify({'success': True, 'port_forward': port_forward})
        
        return jsonify({'success': False, 'error': 'Failed to apply port forward'}), 500

@app.route('/api/system/info')
def api_system_info():
    """Get system information"""
    info = {
        'host_ip': get_host_ip(),
        'containers': get_all_containers(),
        'bridge_info': {},
        'disk_usage': {},
        'memory_usage': {}
    }
    
    # Get bridge info
    bridge_result = run_command('ip addr show lxcbr0')
    if bridge_result['success']:
        lines = bridge_result['stdout'].split('\n')
        for line in lines:
            if 'inet ' in line:
                info['bridge_info']['ip'] = line.strip().split()[1]
    
    # Get disk usage
    disk_result = run_command('df -h /')
    if disk_result['success']:
        lines = disk_result['stdout'].split('\n')
        if len(lines) > 1:
            parts = lines[1].split()
            if len(parts) >= 5:
                info['disk_usage'] = {
                    'total': parts[1],
                    'used': parts[2],
                    'available': parts[3],
                    'percent': parts[4]
                }
    
    # Get memory usage
    mem_result = run_command('free -h')
    if mem_result['success']:
        lines = mem_result['stdout'].split('\n')
        if len(lines) > 1:
            parts = lines[1].split()
            if len(parts) >= 3:
                info['memory_usage'] = {
                    'total': parts[1],
                    'used': parts[2],
                    'free': parts[3] if len(parts) > 3 else 'N/A'
                }
    
    return jsonify(info)

@socketio.on('connect')
def handle_connect():
    """Handle WebSocket connection"""
    emit('connected', {'data': 'Connected to LXC Compose Manager'})

@socketio.on('execute_command')
def handle_execute_command(data):
    """Execute command via WebSocket for real-time output"""
    command = data.get('command', '')
    container = data.get('container', '')
    
    if container:
        full_command = f'sudo lxc-attach -n {container} -- {command}'
    else:
        full_command = command
    
    # Run command with real-time output
    process = subprocess.Popen(
        full_command,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    # Stream output
    for line in iter(process.stdout.readline, ''):
        if line:
            emit('command_output', {'output': line.rstrip()})
    
    process.wait()
    emit('command_complete', {'returncode': process.returncode})

if __name__ == '__main__':
    # Ensure directories exist
    os.makedirs('/etc/lxc-compose', exist_ok=True)
    os.makedirs('/var/log', exist_ok=True)
    
    # Run with SocketIO (allow_unsafe_werkzeug is OK for local management interface)
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)