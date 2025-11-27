#!/bin/bash
###############################################################################
# CyberXP-OS Direct Installation Script for Ubuntu
# Installs CyberXP components directly on an existing Ubuntu system
#
# Usage: sudo ./install-cyberxp-ubuntu.sh
#
# This script:
# - Installs all required dependencies
# - Sets up CyberXP Dashboard
# - Configures systemd services
# - Enables auto-start on boot
# - Configures firewall
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/cyberxp"
DASHBOARD_DIR="/opt/cyberxp-dashboard"
SERVICE_NAME="cyberxp-dashboard"
DASHBOARD_PORT="8080"

###############################################################################
# Helper Functions
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."
    
    # Check if running on Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        log_warn "This script is designed for Ubuntu, but will attempt to continue..."
    fi
    
    # Check for root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Run with: sudo $0"
        exit 1
    fi
    
    # Check network connectivity
    if ! ping -c 1 -W 3 8.8.8.8 &> /dev/null; then
        log_error "No internet connection detected"
        log_info "Please check your network connection"
        exit 1
    fi
    
    log_success "Requirements check passed"
}

update_system() {
    log_info "Updating system packages..."
    
    apt update || {
        log_error "Failed to update package lists"
        exit 1
    }
    
    log_success "System updated"
}

install_dependencies() {
    log_info "Installing dependencies (this may take 5-10 minutes)..."
    
    # Install Python and essential tools
    DEBIAN_FRONTEND=noninteractive apt install -y \
        python3 \
        python3-pip \
        python3-venv \
        git \
        curl \
        wget \
        nano \
        vim \
        htop \
        net-tools \
        iproute2 \
        iputils-ping \
        iptables \
        ufw \
        supervisor \
        nginx || {
        log_error "Failed to install dependencies"
        exit 1
    }
    
    log_success "Dependencies installed"
}

install_python_packages() {
    log_info "Installing Python packages..."
    
    # Install Flask and dependencies
    pip3 install --break-system-packages \
        Flask==3.0.0 \
        Werkzeug==3.0.1 \
        psutil==5.9.0 \
        requests || {
        log_warn "Some Python packages failed to install, trying without --break-system-packages..."
        pip3 install \
            Flask==3.0.0 \
            Werkzeug==3.0.1 \
            psutil==5.9.0 \
            requests || {
            log_error "Failed to install Python packages"
            exit 1
        }
    }
    
    log_success "Python packages installed"
}

install_dashboard() {
    log_info "Installing CyberXP Dashboard..."
    
    # Create dashboard directory
    mkdir -p "$DASHBOARD_DIR"
    
    # Check if dashboard files exist in repo
    if [[ -f "config/desktop/cyberxp-dashboard/app.py" ]]; then
        log_info "Copying dashboard from config/"
        cp -r config/desktop/cyberxp-dashboard/* "$DASHBOARD_DIR/"
    else
        log_info "Creating minimal dashboard..."
        
        # Create minimal dashboard
        cat > "$DASHBOARD_DIR/app.py" <<'PYEOF'
#!/usr/bin/env python3
"""
CyberXP-OS Dashboard
Minimal Flask-based security monitoring dashboard
"""

from flask import Flask, jsonify, render_template_string
import subprocess
import os
import psutil
from datetime import datetime

app = Flask(__name__)

HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>CyberXP-OS Dashboard</title>
    <meta http-equiv="refresh" content="30">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-align: center;
        }
        .subtitle {
            text-align: center;
            font-size: 1.2em;
            opacity: 0.9;
            margin-bottom: 40px;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background: rgba(255, 255, 255, 0.2);
            padding: 20px;
            border-radius: 10px;
        }
        .card h2 {
            font-size: 1.3em;
            margin-bottom: 15px;
            border-bottom: 2px solid rgba(255,255,255,0.3);
            padding-bottom: 10px;
        }
        .metric {
            background: rgba(0, 0, 0, 0.3);
            padding: 12px;
            border-radius: 8px;
            margin: 8px 0;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .metric-label {
            font-weight: 500;
        }
        .metric-value {
            font-size: 1.1em;
            font-weight: bold;
            color: #4ade80;
        }
        .status-ok { color: #4ade80; }
        .status-warn { color: #fbbf24; }
        .status-error { color: #ef4444; }
        .footer {
            text-align: center;
            margin-top: 30px;
            opacity: 0.8;
            font-size: 0.9em;
        }
        .footer a {
            color: #4ade80;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ CyberXP-OS</h1>
        <div class="subtitle">AI-Powered Security Analysis Platform</div>
        
        <div class="grid">
            <div class="card">
                <h2>System Status</h2>
                <div class="metric">
                    <span class="metric-label">Status</span>
                    <span class="metric-value status-ok">✅ Online</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Hostname</span>
                    <span class="metric-value">{{ hostname }}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Uptime</span>
                    <span class="metric-value">{{ uptime }}</span>
                </div>
            </div>
            
            <div class="card">
                <h2>Resources</h2>
                <div class="metric">
                    <span class="metric-label">CPU Usage</span>
                    <span class="metric-value">{{ cpu_percent }}%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Memory</span>
                    <span class="metric-value">{{ memory_percent }}%</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Disk</span>
                    <span class="metric-value">{{ disk_percent }}%</span>
                </div>
            </div>
            
            <div class="card">
                <h2>Network</h2>
                <div class="metric">
                    <span class="metric-label">IP Address</span>
                    <span class="metric-value">{{ ip_address }}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Dashboard Port</span>
                    <span class="metric-value">8080</span>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h2>Quick Links</h2>
            <div class="metric">
                <span class="metric-label">API Status</span>
                <span class="metric-value"><a href="/api/status" style="color: #4ade80;">View JSON</a></span>
            </div>
            <div class="metric">
                <span class="metric-label">Health Check</span>
                <span class="metric-value"><a href="/healthz" style="color: #4ade80;">Check</a></span>
            </div>
        </div>
        
        <div class="footer">
            <p>Page auto-refreshes every 30 seconds</p>
            <p style="margin-top: 10px;">
                <a href="https://github.com/r-abaryan/CyberXP-OS" target="_blank">
                    GitHub: github.com/r-abaryan/CyberXP-OS
                </a>
            </p>
        </div>
    </div>
</body>
</html>
'''

def get_system_info():
    """Get system information"""
    try:
        # Hostname
        hostname = os.uname().nodename
        
        # Uptime
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.read().split()[0])
            days = int(uptime_seconds // 86400)
            hours = int((uptime_seconds % 86400) // 3600)
            minutes = int((uptime_seconds % 3600) // 60)
            uptime = f"{days}d {hours}h {minutes}m"
        
        # CPU
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Memory
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        
        # Disk
        disk = psutil.disk_usage('/')
        disk_percent = disk.percent
        
        # IP Address
        try:
            import socket
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip_address = s.getsockname()[0]
            s.close()
        except:
            ip_address = "Unknown"
        
        return {
            'hostname': hostname,
            'uptime': uptime,
            'cpu_percent': cpu_percent,
            'memory_percent': memory_percent,
            'disk_percent': disk_percent,
            'ip_address': ip_address
        }
    except Exception as e:
        return {
            'hostname': 'Unknown',
            'uptime': 'Unknown',
            'cpu_percent': 0,
            'memory_percent': 0,
            'disk_percent': 0,
            'ip_address': 'Unknown'
        }

@app.route('/')
def index():
    """Main dashboard page"""
    info = get_system_info()
    return render_template_string(HTML_TEMPLATE, **info)

@app.route('/api/status')
def api_status():
    """Get system status as JSON"""
    info = get_system_info()
    info['timestamp'] = datetime.now().isoformat()
    info['status'] = 'online'
    return jsonify(info)

@app.route('/healthz')
def healthz():
    """Health check endpoint"""
    return 'ok', 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', '8080'))
    print(f"Starting CyberXP Dashboard on port {port}...")
    app.run(host='0.0.0.0', port=port, debug=False)
PYEOF
        
        chmod +x "$DASHBOARD_DIR/app.py"
    fi
    
    # Create requirements.txt
    cat > "$DASHBOARD_DIR/requirements.txt" <<EOF
Flask==3.0.0
Werkzeug==3.0.1
psutil==5.9.0
EOF
    
    log_success "Dashboard installed to $DASHBOARD_DIR"
}

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=CyberXP-OS Security Dashboard
Documentation=https://github.com/r-abaryan/CyberXP-OS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$DASHBOARD_DIR
ExecStart=/usr/bin/python3 $DASHBOARD_DIR/app.py
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1
Environment=PORT=$DASHBOARD_PORT

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "Systemd service created"
}

configure_firewall() {
    log_info "Configuring firewall..."
    
    # Enable UFW if not already enabled
    if ! ufw status | grep -q "Status: active"; then
        log_info "Enabling UFW firewall..."
        ufw --force enable
    fi
    
    # Allow dashboard port
    ufw allow $DASHBOARD_PORT/tcp comment "CyberXP Dashboard"
    
    # Allow SSH (important!)
    ufw allow 22/tcp comment "SSH"
    
    log_success "Firewall configured"
}

start_service() {
    log_info "Starting CyberXP Dashboard service..."
    
    # Enable service
    systemctl enable $SERVICE_NAME
    
    # Start service
    systemctl start $SERVICE_NAME
    
    # Wait a moment for service to start
    sleep 2
    
    # Check status
    if systemctl is-active --quiet $SERVICE_NAME; then
        log_success "Service started successfully"
    else
        log_error "Service failed to start"
        log_info "Check logs with: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

verify_installation() {
    log_info "Verifying installation..."
    
    # Check if service is running
    if ! systemctl is-active --quiet $SERVICE_NAME; then
        log_error "Service is not running"
        return 1
    fi
    
    # Check if port is listening
    if ! netstat -tlnp 2>/dev/null | grep -q ":$DASHBOARD_PORT"; then
        log_warn "Port $DASHBOARD_PORT not listening yet (may take a moment)"
    fi
    
    # Try to access dashboard
    sleep 2
    if curl -s http://localhost:$DASHBOARD_PORT/healthz | grep -q "ok"; then
        log_success "Dashboard is responding"
    else
        log_warn "Dashboard not responding yet (may take a moment to start)"
    fi
    
    log_success "Installation verified"
}

show_summary() {
    # Get IP address
    local ip_address=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🎉 CyberXP-OS Installation Complete!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Dashboard Access:"
    echo "    Local:  http://localhost:$DASHBOARD_PORT"
    if [[ -n "$ip_address" ]]; then
        echo "    Network: http://$ip_address:$DASHBOARD_PORT"
    fi
    echo ""
    echo "  Service Management:"
    echo "    Status:  sudo systemctl status $SERVICE_NAME"
    echo "    Start:   sudo systemctl start $SERVICE_NAME"
    echo "    Stop:    sudo systemctl stop $SERVICE_NAME"
    echo "    Restart: sudo systemctl restart $SERVICE_NAME"
    echo "    Logs:    sudo journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "  Files:"
    echo "    Dashboard: $DASHBOARD_DIR"
    echo "    Service:   /etc/systemd/system/${SERVICE_NAME}.service"
    echo ""
    echo "  Next Steps:"
    echo "    1. Access dashboard in browser"
    echo "    2. Add your CyberXP AI code to $INSTALL_DIR"
    echo "    3. Customize dashboard as needed"
    echo ""
    echo "  Firewall:"
    echo "    Port $DASHBOARD_PORT is open"
    echo "    View rules: sudo ufw status"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CyberXP-OS Direct Installation for Ubuntu"
    echo "  Version: 0.1.0-alpha"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_requirements
    update_system
    install_dependencies
    install_python_packages
    install_dashboard
    create_systemd_service
    configure_firewall
    start_service
    verify_installation
    show_summary
    
    echo ""
    log_success "Installation complete! Access dashboard at http://localhost:$DASHBOARD_PORT"
    echo ""
}

# Run main function
main "$@"
