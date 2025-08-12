# /srv/lxc-compose/scripts/generate_supervisor.py

def generate_supervisor_config(config):
    """Generate supervisor config from YAML"""
    configs = []
    
    # Django instances
    if 'django' in config['services']:
        django = config['services']['django']
        for i in range(django['instances']):
            port = django['ports'][i]
            configs.append(f"""
[program:django_{i}]
command=/app/venv/bin/gunicorn myapp.wsgi:application --bind 0.0.0.0:{port}
directory=/app/code
user=app
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/app/django_{i}.log
environment=PATH="/app/venv/bin",{load_env_vars(django['environment_file'])}
""")
    
    # Celery workers
    if 'celery' in config['services']:
        celery = config['services']['celery']
        for i, (queue_name, command) in enumerate(celery['queues'].items()):
            configs.append(f"""
[program:celery_{queue_name}]
command=/app/venv/bin/{command.format(instance=i)}
directory=/app/code
user=app
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/app/celery_{queue_name}.log
environment=PATH="/app/venv/bin",{load_env_vars(celery['environment_file'])}
""")
    
    return '\n'.join(configs)