# User Guide

## First Steps

### Installation

```bash
git clone https://github.com/r-abaryan/CyberXP-OS
cd CyberXP-OS
sudo ./scripts/install.sh
```

Choose:
1. Dashboard only or Dashboard + AI
2. Terminal or Web interface

### Access

**Terminal dashboard:**
```bash
cyberxp
```

**Web dashboard:**
```
http://localhost:8080
```

---

## Terminal Dashboard

### Commands

- `q` - Quit
- `r` - Refresh
- `s` - Service management
- `l` - View logs
- `a` - AI threat analysis (if installed)

### Features

- Real-time system metrics (CPU, memory, disk)
- Network information
- Service status
- Log viewer
- AI analysis integration

---

## Web Dashboard

### Access

Open browser: `http://localhost:8080`

### Features

- System status overview
- Resource monitoring
- Service management
- Quick actions
- Log viewing

---

## AI Analysis

### Requirements

AI dependencies must be installed:
```bash
sudo ./scripts/install-cyberxp-dependencies.sh
```

### Usage

**Terminal:**
```bash
cyberxp
# Press 'a' for analysis
# Enter threat description
```

**CLI:**
```bash
cyberxp-analyze "Suspicious login from unknown IP"
```

### Output

- Severity assessment
- Threat classification
- Recommended actions
- IOC extraction

---

## Service Management

### Check Status

```bash
# Terminal dashboard
sudo systemctl status cyberxp-dashboard

# Web dashboard
sudo systemctl status cyberxp-dashboard

# AI engine (if installed)
cd /opt/cyberxp-ai
python3 src/cyber_agent_vec.py --help
```

### Start/Stop

```bash
# Start
sudo systemctl start cyberxp-dashboard

# Stop
sudo systemctl stop cyberxp-dashboard

# Restart
sudo systemctl restart cyberxp-dashboard
```

### Logs

```bash
# View logs
sudo journalctl -u cyberxp-dashboard -f

# Last 50 lines
sudo journalctl -u cyberxp-dashboard -n 50
```

---

## Configuration

### Dashboard Port

Edit service file:
```bash
sudo nano /etc/systemd/system/cyberxp-dashboard.service
```

Change:
```ini
Environment=PORT=8080
```

Restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart cyberxp-dashboard
```

### Firewall

```bash
# Allow dashboard port
sudo ufw allow 8080/tcp

# Check status
sudo ufw status
```

---

## Troubleshooting

### Dashboard Won't Start

```bash
# Check status
sudo systemctl status cyberxp-dashboard

# View errors
sudo journalctl -u cyberxp-dashboard -n 100

# Check port
sudo netstat -tlnp | grep 8080

# Restart
sudo systemctl restart cyberxp-dashboard
```

### Can't Access Dashboard

```bash
# Test locally
curl http://localhost:8080

# Check firewall
sudo ufw status

# Check service
sudo systemctl status cyberxp-dashboard
```

### AI Analysis Not Working

```bash
# Check if installed
ls /opt/cyberxp-ai

# If not installed
sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh

# Test manually
cd /opt/cyberxp-ai
python3 src/cyber_agent_vec.py --threat "test"
```

---

## System Updates

```bash
# Update system
sudo apt update && sudo apt upgrade

# Update CyberXP (if new version available)
cd ~/CyberXP-OS
git pull
sudo ./scripts/install.sh
```

---

## Security

### Change Passwords

Default credentials (change immediately):
- User: `cyberxp` / `cyberxp`
- Root: `root` / `cyberxp`

```bash
# Change user password
passwd

# Change root password
sudo passwd root
```

### SSH Access

```bash
# Disable root login
sudo nano /etc/ssh/sshd_config
# Set: PermitRootLogin no

# Restart SSH
sudo systemctl restart sshd
```

### Firewall

```bash
# Enable firewall
sudo ufw enable

# Allow SSH
sudo ufw allow 22/tcp

# Allow dashboard
sudo ufw allow 8080/tcp

# Check rules
sudo ufw status
```

---

## Advanced

### Custom Dashboard

Edit dashboard code:
```bash
sudo nano /opt/cyberxp-dashboard/app.py
sudo systemctl restart cyberxp-dashboard
```

### Add Custom Analysis

Create custom script:
```bash
sudo nano /opt/cyberxp-ai/custom_analysis.py
```

Integrate with dashboard or use standalone.

### Export Data

```bash
# System metrics
curl http://localhost:8080/api/status > metrics.json

# Logs
sudo journalctl -u cyberxp-dashboard > dashboard.log
```

---

## Support

- GitHub: https://github.com/r-abaryan/CyberXP-OS
- Issues: https://github.com/r-abaryan/CyberXP-OS/issues
- AI Engine: https://github.com/r-abaryan/CyberLLM-Agent
