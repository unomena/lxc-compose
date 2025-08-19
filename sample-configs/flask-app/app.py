#!/usr/bin/env python3
"""
Simple Flask application with Redis integration
"""
import os
from flask import Flask, jsonify, render_template_string
import redis
from datetime import datetime

app = Flask(__name__)

# Redis configuration
REDIS_HOST = os.environ.get('REDIS_HOST', 'flask-redis')
REDIS_PORT = int(os.environ.get('REDIS_PORT', 6379))

# Connect to Redis
try:
    r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)
    r.ping()
    redis_connected = True
except:
    r = None
    redis_connected = False

# Simple HTML template
HOME_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Flask App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .connected { background-color: #d4edda; color: #155724; }
        .disconnected { background-color: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <h1>Flask Application</h1>
    <div class="status {{ 'connected' if redis_status else 'disconnected' }}">
        Redis Status: {{ 'Connected' if redis_status else 'Disconnected' }}
    </div>
    <p>Visit Count: {{ visit_count }}</p>
    <p>Last Visit: {{ last_visit }}</p>
    <hr>
    <p>
        <a href="/api/status">API Status</a> | 
        <a href="/api/increment">Increment Counter</a>
    </p>
</body>
</html>
"""

@app.route('/')
def home():
    visit_count = 0
    last_visit = "Never"
    
    if redis_connected:
        try:
            # Increment visit counter
            visit_count = r.incr('visit_count')
            # Store last visit time
            last_visit = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            r.set('last_visit', last_visit)
        except:
            pass
    
    return render_template_string(HOME_TEMPLATE, 
                                redis_status=redis_connected,
                                visit_count=visit_count,
                                last_visit=last_visit)

@app.route('/api/status')
def api_status():
    return jsonify({
        'status': 'ok',
        'redis_connected': redis_connected,
        'redis_host': REDIS_HOST,
        'redis_port': REDIS_PORT
    })

@app.route('/api/increment')
def api_increment():
    if redis_connected:
        try:
            count = r.incr('api_counter')
            return jsonify({'success': True, 'count': count})
        except Exception as e:
            return jsonify({'success': False, 'error': str(e)}), 500
    else:
        return jsonify({'success': False, 'error': 'Redis not connected'}), 503

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)