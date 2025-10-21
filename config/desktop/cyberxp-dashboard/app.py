#!/usr/bin/env python3
"""
CyberXP-OS Web Dashboard
Lightweight Flask-based security monitoring dashboard
"""

from flask import Flask, render_template, request, jsonify
import os
import subprocess
import json
from datetime import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'change-this-in-production')

# Configuration
CYBERXP_CORE_PATH = "/opt/cyberxp"
LOG_DIR = "/var/log"

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html', 
                         hostname=get_hostname(),
                         system_info=get_system_info())

@app.route('/api/status')
def api_status():
    """Get system and service status"""
    return jsonify({
        'timestamp': datetime.now().isoformat(),
        'system': get_system_info(),
        'services': get_service_status(),
        'alerts': get_recent_alerts()
    })

@app.route('/api/analyze', methods=['POST'])
def api_analyze():
    """Analyze security alert using CyberXP"""
    data = request.get_json()
    
    # Call CyberXP core for analysis
    result = analyze_with_cyberxp(data.get('alert', ''))
    
    return jsonify(result)

@app.route('/api/block-ip', methods=['POST'])
def api_block_ip():
    """Block an IP address"""
    data = request.get_json()
    ip = data.get('ip', '')
    
    if not ip:
        return jsonify({'error': 'No IP provided'}), 400
    
    # Add iptables rule
    try:
        subprocess.run(['iptables', '-A', 'INPUT', '-s', ip, '-j', 'DROP'], 
                      check=True, capture_output=True)
        subprocess.run(['rc-service', 'iptables', 'save'], 
                      check=True, capture_output=True)
        return jsonify({'success': True, 'message': f'IP {ip} blocked'})
    except subprocess.CalledProcessError as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs/<service>')
def api_logs(service):
    """Get logs for a specific service"""
    logs = get_service_logs(service)
    return jsonify({'logs': logs})

def get_hostname():
    """Get system hostname"""
    try:
        with open('/etc/hostname', 'r') as f:
            return f.read().strip()
    except:
        return 'cyberxp-os'

def get_system_info():
    """Get system information"""
    try:
        # Load average
        with open('/proc/loadavg', 'r') as f:
            loadavg = f.read().split()[:3]
        
        # Memory info
        meminfo = {}
        with open('/proc/meminfo', 'r') as f:
            for line in f:
                parts = line.split(':')
                if len(parts) == 2:
                    meminfo[parts[0].strip()] = parts[1].strip()
        
        total_mem = int(meminfo.get('MemTotal', '0').split()[0])
        free_mem = int(meminfo.get('MemAvailable', '0').split()[0])
        used_mem = total_mem - free_mem
        
        return {
            'loadavg': loadavg,
            'memory': {
                'total': f"{total_mem // 1024} MB",
                'used': f"{used_mem // 1024} MB",
                'free': f"{free_mem // 1024} MB",
                'percent': round((used_mem / total_mem) * 100, 1) if total_mem > 0 else 0
            },
            'uptime': get_uptime()
        }
    except Exception as e:
        return {'error': str(e)}

def get_uptime():
    """Get system uptime"""
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.read().split()[0])
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            return f"{days}d {hours}h {minutes}m"
    except:
        return "Unknown"

def get_service_status():
    """Get status of security services"""
    services = ['cyberxp-agent', 'suricata', 'fail2ban', 'iptables', 'sshd']
    status = {}
    
    for service in services:
        try:
            result = subprocess.run(['rc-service', service, 'status'],
                                  capture_output=True, text=True)
            status[service] = 'running' if 'started' in result.stdout.lower() else 'stopped'
        except:
            status[service] = 'unknown'
    
    return status

def get_recent_alerts(limit=10):
    """Get recent security alerts"""
    alerts = []
    
    # Check Suricata fast.log
    suricata_log = '/var/log/suricata/fast.log'
    if os.path.exists(suricata_log):
        try:
            with open(suricata_log, 'r') as f:
                lines = f.readlines()
                for line in lines[-limit:]:
                    alerts.append({
                        'source': 'suricata',
                        'message': line.strip(),
                        'timestamp': datetime.now().isoformat()
                    })
        except:
            pass
    
    return alerts

def get_service_logs(service, lines=50):
    """Get logs for a service"""
    log_files = {
        'cyberxp': '/var/log/cyberxp-agent.log',
        'suricata': '/var/log/suricata/fast.log',
        'fail2ban': '/var/log/fail2ban.log',
        'system': '/var/log/messages'
    }
    
    log_file = log_files.get(service)
    if not log_file or not os.path.exists(log_file):
        return []
    
    try:
        result = subprocess.run(['tail', f'-n{lines}', log_file],
                              capture_output=True, text=True)
        return result.stdout.split('\n')
    except:
        return []

def analyze_with_cyberxp(alert_text):
    """Analyze alert using CyberXP core"""
    # TODO: Integrate with CyberXP core for AI analysis
    # For now, return a simple response
    return {
        'severity': 5,
        'analysis': 'Alert analysis feature coming soon',
        'recommendations': [
            'Monitor the situation',
            'Review logs for additional context'
        ]
    }

if __name__ == '__main__':
    # Run on all interfaces, port 8080
    app.run(host='0.0.0.0', port=8080, debug=False)

