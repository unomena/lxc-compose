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
    import time
    return render_template('wizard.html', 
                         registry=registry,
                         templates=CONTAINER_TEMPLATES,
                         version=int(time.time()))

@app.route('/api/wizard/create', methods=['POST'])
def api_wizard_create():
    """Create containers using wizard settings - returns quickly, use WebSocket for progress"""
    data = request.json
    
    # Store the request data in session for WebSocket handler
    session['wizard_create_data'] = data
    
    return jsonify({
        'success': True,
        'message': 'Container creation started. Use WebSocket for progress.'
    })

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
                    test_dir = os.path.normpath(new_dir)
                elif new_dir == '~':
                    test_dir = '/root'
                elif new_dir == '..':
                    # Go up one directory
                    test_dir = os.path.normpath(os.path.dirname(working_dir))
                    if not test_dir:
                        test_dir = '/'
                else:
                    # Relative path
                    test_dir = os.path.normpath(os.path.join(working_dir, new_dir))
                
                # Test if directory exists in container
                test_result = subprocess.run(
                    ['sudo', 'lxc-attach', '-n', container, '--', 'test', '-d', test_dir],
                    capture_output=True,
                    timeout=5
                )
                
                if test_result.returncode == 0:
                    # Normalize the path before storing
                    normalized_dir = os.path.normpath(test_dir)
                    # Update the working directory for this session
                    if session_id and container in shell_sessions:
                        shell_sessions[container][session_id] = normalized_dir
                    return jsonify({
                        'success': True,
                        'stdout': '',
                        'stderr': '',
                        'working_dir': normalized_dir
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

@app.route('/api/autocomplete', methods=['POST'])
def api_autocomplete():
    """Provide autocomplete suggestions for commands and paths"""
    data = request.json
    container = data.get('container')
    partial = data.get('partial', '')
    context = data.get('context', 'command')  # 'command' or 'path'
    session_id = data.get('session_id')
    
    if context == 'command':
        # Command completion
        commands = [
            'ls', 'cd', 'pwd', 'cat', 'echo', 'grep', 'find', 'mkdir', 'rm', 'cp', 'mv',
            'touch', 'chmod', 'chown', 'ps', 'kill', 'df', 'du', 'tar', 'zip', 'unzip',
            'apt', 'apt-get', 'systemctl', 'service', 'python', 'python3', 'pip', 'npm',
            'git', 'vim', 'nano', 'less', 'more', 'head', 'tail', 'wget', 'curl', 'ssh',
            'exit', 'clear', 'history', 'which', 'whereis', 'man', 'env', 'export'
        ]
        matches = [cmd for cmd in commands if cmd.startswith(partial)]
        return jsonify({'suggestions': matches})
    
    elif context == 'path' and container:
        # Path completion
        working_dir = '/root'
        if session_id and container in shell_sessions and session_id in shell_sessions[container]:
            working_dir = shell_sessions[container][session_id]
        
        # Build the path to complete
        if partial.startswith('/'):
            # Absolute path
            base_path = partial
        elif partial.startswith('~'):
            # Home directory
            base_path = partial.replace('~', '/root', 1)
        else:
            # Relative path
            base_path = os.path.join(working_dir, partial) if partial else working_dir
        
        # Get directory listing
        try:
            # Use shell globbing to find matches
            cmd = f'ls -d {base_path}* 2>/dev/null | head -20'
            result = subprocess.run(
                ['sudo', 'lxc-attach', '-n', container, '--', 'bash', '-c', cmd],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0 and result.stdout:
                paths = result.stdout.strip().split('\n')
                # Check if paths are directories and append /
                suggestions = []
                for path in paths:
                    if path:
                        check_dir = subprocess.run(
                            ['sudo', 'lxc-attach', '-n', container, '--', 'test', '-d', path],
                            capture_output=True,
                            timeout=2
                        )
                        if check_dir.returncode == 0:
                            suggestions.append(path + '/')
                        else:
                            suggestions.append(path)
                
                return jsonify({'suggestions': suggestions})
            
        except Exception as e:
            logger.error(f"Autocomplete error: {e}")
    
    return jsonify({'suggestions': []})

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

@socketio.on('create_containers')
def handle_create_containers(data):
    """Create containers with real-time log streaming"""
    
    # Send initial test message to verify WebSocket is working
    emit('log_output', {'message': '=== WebSocket Connection Test ===', 'type': 'header'})
    emit('log_output', {'message': 'WebSocket is working! Starting container creation...', 'type': 'success'})
    emit('log_output', {'message': f'Request data: {data}', 'type': 'stdout'})
    
    def stream_command(cmd, description):
        """Execute command and stream output"""
        emit('log_output', {'message': f'\n=== {description} ===', 'type': 'header'})
        emit('log_output', {'message': f'Running: {cmd[:100]}...', 'type': 'command'})
        
        # For testing, let's use a simpler approach
        try:
            # Run command and capture output
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=120
            )
            
            # Send output
            if result.stdout:
                for line in result.stdout.split('\n'):
                    if line.strip():
                        emit('log_output', {'message': line, 'type': 'stdout'})
                        time.sleep(0.01)  # Small delay for readability
            
            if result.stderr:
                for line in result.stderr.split('\n'):
                    if line.strip():
                        emit('log_output', {'message': line, 'type': 'stderr'})
                        time.sleep(0.01)
            
            if result.returncode != 0:
                emit('log_output', {'message': f'[ERROR] Command failed with exit code {result.returncode}', 'type': 'stderr'})
            else:
                emit('log_output', {'message': '[SUCCESS] Command completed', 'type': 'success'})
            
            return result.returncode
            
        except subprocess.TimeoutExpired:
            emit('log_output', {'message': '[ERROR] Command timed out after 120 seconds', 'type': 'stderr'})
            return 1
        except Exception as e:
            emit('log_output', {'message': f'[ERROR] Exception: {str(e)}', 'type': 'stderr'})
            return 1
    
    results = []
    
    # Create datastore if requested
    if data.get('create_datastore'):
        emit('progress_update', {'container': 'datastore', 'status': 'in_progress', 'message': 'Creating datastore container...'})
        
        # Check if datastore already exists
        check_cmd = "sudo lxc-info -n datastore 2>/dev/null | grep -q 'State:' && echo 'exists' || echo 'not_exists'"
        check_result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True)
        
        if 'exists' in check_result.stdout:
            emit('log_output', {'message': 'Datastore container already exists, checking if PostgreSQL is installed...', 'type': 'stdout'})
            # Setup PostgreSQL in existing container
            returncode = stream_command(
                '''sudo lxc-attach -n datastore -- bash -c "
                    if ! command -v psql &> /dev/null; then
                        echo 'Installing PostgreSQL...'
                        apt-get update
                        DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-contrib
                        systemctl start postgresql
                        systemctl enable postgresql
                    fi
                    echo 'PostgreSQL is installed and running'
                "''',
                'Setting up PostgreSQL in Datastore'
            )
        else:
            # Create new datastore container
            emit('log_output', {'message': 'Creating new datastore container...', 'type': 'stdout'})
            
            # Create container
            returncode = stream_command(
                'sudo lxc-create -n datastore -t ubuntu -- -r jammy',
                'Creating Ubuntu 22.04 container'
            )
            
            if returncode == 0:
                # Start container
                stream_command('sudo lxc-start -n datastore', 'Starting container')
                time.sleep(5)  # Wait for container to fully start
                
                # Configure network
                stream_command(
                    'sudo lxc-attach -n datastore -- bash -c "echo nameserver 8.8.8.8 > /etc/resolv.conf"',
                    'Configuring DNS'
                )
                
                # Install PostgreSQL
                returncode = stream_command(
                    '''sudo lxc-attach -n datastore -- bash -c "
                        apt-get update && 
                        DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql postgresql-contrib redis-server &&
                        systemctl start postgresql &&
                        systemctl enable postgresql &&
                        systemctl start redis-server &&
                        systemctl enable redis-server
                    "''',
                    'Installing PostgreSQL and Redis'
                )
        
        success = returncode == 0
        emit('progress_update', {
            'container': 'datastore',
            'status': 'success' if success else 'error',
            'message': 'Datastore created successfully' if success else 'Failed to create datastore'
        })
        results.append({'container': 'datastore', 'success': success})
    
    # Create app containers
    for i in range(1, data.get('app_count', 0) + 1):
        container_name = f"app-{i}"
        container_ip = f"10.0.3.{10 + i}"
        emit('progress_update', {'container': container_name, 'status': 'in_progress', 'message': f'Creating {container_name} container...'})
        
        # Check if container already exists
        check_cmd = f"sudo lxc-info -n {container_name} 2>/dev/null | grep -q 'State:' && echo 'exists' || echo 'not_exists'"
        check_result = subprocess.run(check_cmd, shell=True, capture_output=True, text=True)
        
        if 'exists' in check_result.stdout:
            emit('log_output', {'message': f'Container {container_name} already exists, skipping creation...', 'type': 'stdout'})
            returncode = 0
        else:
            # Create new app container
            emit('log_output', {'message': f'Creating new container {container_name}...', 'type': 'stdout'})
            
            # Create container
            returncode = stream_command(
                f'sudo lxc-create -n {container_name} -t ubuntu -- -r jammy',
                f'Creating Ubuntu 22.04 container for {container_name}'
            )
            
            if returncode == 0:
                # Start container
                stream_command(f'sudo lxc-start -n {container_name}', f'Starting {container_name}')
                time.sleep(5)  # Wait for container to fully start
                
                # Configure network and static IP
                stream_command(
                    f'''sudo lxc-attach -n {container_name} -- bash -c "
                        echo nameserver 8.8.8.8 > /etc/resolv.conf &&
                        echo nameserver 8.8.4.4 >> /etc/resolv.conf
                    "''',
                    f'Configuring DNS for {container_name}'
                )
                
                # Install basic packages
                returncode = stream_command(
                    f'''sudo lxc-attach -n {container_name} -- bash -c "
                        apt-get update && 
                        DEBIAN_FRONTEND=noninteractive apt-get install -y nginx python3 python3-pip nodejs npm supervisor &&
                        systemctl start nginx &&
                        systemctl enable nginx
                    "''',
                    f'Installing packages in {container_name}'
                )
        
        success = returncode == 0
        emit('progress_update', {
            'container': container_name,
            'status': 'success' if success else 'error',
            'message': f'{container_name} created successfully' if success else f'Failed to create {container_name}'
        })
        results.append({'container': container_name, 'success': success})
    
    # Deploy Django sample if requested
    if data.get('create_django_sample') and data.get('app_count', 0) > 0:
        emit('progress_update', {'container': 'django', 'status': 'in_progress', 'message': 'Deploying Django sample application...'})
        
        # For now, just log that Django deployment would happen
        emit('log_output', {'message': 'Django sample deployment would be implemented here', 'type': 'stdout'})
        emit('log_output', {'message': 'This feature is currently being developed', 'type': 'stdout'})
        returncode = 0  # Simulated success
        
        success = returncode == 0
        emit('progress_update', {
            'container': 'django',
            'status': 'success' if success else 'error',
            'message': 'Django sample marked for deployment' if success else 'Failed to deploy Django sample'
        })
        results.append({'container': 'django', 'success': success})
    
    emit('creation_complete', {'results': results})

if __name__ == '__main__':
    # Ensure directories exist
    os.makedirs('/etc/lxc-compose', exist_ok=True)
    os.makedirs('/var/log', exist_ok=True)
    
    # Run with SocketIO (allow_unsafe_werkzeug is OK for local management interface)
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)