# CyberXP-OS Configuration Guide

## 📋 Overview

This guide covers all configuration aspects of CyberXP-OS, from basic system settings to advanced security configurations.

---

## 🎯 Configuration Hierarchy

```
/etc/                           # System configuration
├── network/                    # Network settings
├── iptables/                   # Firewall rules
├── suricata/                   # IDS/IPS configuration
├── fail2ban/                   # Intrusion prevention
└── ssh/                        # SSH configuration

/opt/cyberxp/                   # CyberXP configuration
├── .env                        # Environment variables
├── src/config.py               # Main configuration
├── custom_agents/              # Custom AI agents
└── integrations/               # SIEM integrations
```

---

## 🔧 CyberXP Configuration

### Main Configuration File

**Location:** `/opt/cyberxp/src/config.py`

```python
# Edit configuration
sudo nano /opt/cyberxp/src/config.py
```

**Key Settings:**

```python
# AI Model Configuration
AI_MODEL = "mistralai/Mistral-7B-Instruct-v0.2"
MAX_TOKENS = 2048
TEMPERATURE = 0.1

# Gradio Server
GRADIO_SERVER_NAME = "0.0.0.0"
GRADIO_SERVER_PORT = 7860
GRADIO_SHARE = False

# Threat Assessment
THREAT_THRESHOLD = 7.0  # Severity threshold for auto-actions
AUTO_BLOCK_ENABLED = False  # Automatic IP blocking

# IOC Enrichment
VIRUSTOTAL_ENABLED = True
VIRUSTOTAL_CACHE_TTL = 86400  # 24 hours

# Logging
LOG_LEVEL = "INFO"  # DEBUG, INFO, WARNING, ERROR
LOG_RETENTION_DAYS = 30
```

### Environment Variables

**Location:** `/opt/cyberxp/.env`

```bash
# Create/edit environment file
sudo nano /opt/cyberxp/.env
```

**Required Variables:**

```bash
# VirusTotal API Key (get from https://www.virustotal.com/gui/my-apikey)
VIRUSTOTAL_API_KEY=your_api_key_here

# Hugging Face Token (for model downloads)
HF_TOKEN=your_hf_token_here

# Optional: Custom model cache location
HF_HOME=/opt/cyberxp/.cache/huggingface

# Gradio Configuration
GRADIO_SERVER_PORT=7860
GRADIO_SERVER_NAME=0.0.0.0

# Security Settings
SECRET_KEY=change_this_to_random_string
```

**Apply Changes:**
```bash
sudo rc-service cyberxp-agent restart
```

---

## 🌐 Network Configuration

### Static IP Address

**Location:** `/etc/network/interfaces`

```bash
# Edit network configuration
sudo nano /etc/network/interfaces
```

**Configuration:**
```bash
# Static IP
auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4

# DHCP (default)
auto eth0
iface eth0 inet dhcp
```

**Apply Changes:**
```bash
sudo rc-service networking restart
```

### Multiple Network Interfaces

```bash
# eth0 - Management network
auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1

# eth1 - Monitoring network (span port)
auto eth1
iface eth1 inet manual
    up ip link set eth1 up
    up ip link set eth1 promisc on
```

### DNS Configuration

**Location:** `/etc/resolv.conf`

```bash
# Edit DNS servers
sudo nano /etc/resolv.conf

# Example:
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
```

---

## 🔥 Firewall Configuration

### iptables Rules

**Location:** `/etc/iptables/rules.v4`

```bash
# Edit firewall rules
sudo nano /etc/iptables/rules.v4
```

**Basic Configuration:**
```bash
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established connections
-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow CyberXP Dashboard
-A INPUT -p tcp --dport 7860 -j ACCEPT

# Allow ICMP (ping)
-A INPUT -p icmp -j ACCEPT

# Log dropped packets
-A INPUT -j LOG --log-prefix "iptables-dropped: "

COMMIT
```

**Apply Rules:**
```bash
sudo iptables-restore < /etc/iptables/rules.v4
sudo rc-service iptables save
```

### Advanced Firewall Rules

```bash
# Rate limiting (prevent DoS)
-A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set
-A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP

# Block specific countries (requires xtables-addons)
-A INPUT -m geoip --src-cc CN,RU -j DROP

# Allow specific IP ranges
-A INPUT -s 192.168.1.0/24 -j ACCEPT
```

---

## 🛡️ Security Tool Configuration

### Suricata (IDS/IPS)

**Location:** `/etc/suricata/suricata.yaml`

```bash
# Edit Suricata configuration
sudo nano /etc/suricata/suricata.yaml
```

**Key Settings:**

```yaml
# Network interface
af-packet:
  - interface: eth0
    threads: 2

# Home network
vars:
  address-groups:
    HOME_NET: "[192.168.1.0/24]"
    EXTERNAL_NET: "!$HOME_NET"

# Rule sets
rule-files:
  - suricata.rules
  - /etc/suricata/rules/local.rules

# Logging
outputs:
  - fast:
      enabled: yes
      filename: fast.log
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
```

**Custom Rules:**
```bash
# Create custom rules
sudo nano /etc/suricata/rules/local.rules

# Example rules:
alert tcp any any -> $HOME_NET 22 (msg:"SSH Brute Force Attempt"; \
  flow:to_server,established; content:"SSH"; threshold: type threshold, \
  track by_src, count 5, seconds 60; sid:1000001;)

alert http any any -> $HOME_NET any (msg:"Possible SQL Injection"; \
  flow:to_server,established; content:"union"; content:"select"; \
  sid:1000002;)
```

**Reload Rules:**
```bash
sudo rc-service suricata reload
```

### fail2ban

**Location:** `/etc/fail2ban/jail.local`

```bash
# Edit fail2ban configuration
sudo nano /etc/fail2ban/jail.local
```

**Configuration:**
```ini
[DEFAULT]
# Ban for 1 hour
bantime = 3600

# 5 failures within 10 minutes
findtime = 600
maxretry = 5

# Send email alerts
destemail = admin@example.com
sendername = CyberXP-OS
action = %(action_mwl)s

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
maxretry = 3

[cyberxp-dashboard]
enabled = true
port = 7860
logpath = /var/log/cyberxp-agent.log
maxretry = 5
```

**Restart fail2ban:**
```bash
sudo rc-service fail2ban restart
```

---

## 🔐 SSH Configuration

**Location:** `/etc/ssh/sshd_config`

```bash
# Edit SSH configuration
sudo nano /etc/ssh/sshd_config
```

**Secure Configuration:**
```bash
# Disable root login
PermitRootLogin no

# Use key-based authentication
PubkeyAuthentication yes
PasswordAuthentication no

# Change default port
Port 2222

# Limit users
AllowUsers cyberxp

# Disable empty passwords
PermitEmptyPasswords no

# Use strong ciphers
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,diffie-hellman-group-exchange-sha256

# Enable logging
SyslogFacility AUTH
LogLevel VERBOSE
```

**Generate SSH Keys:**
```bash
# On client machine
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copy to CyberXP-OS
ssh-copy-id cyberxp@<cyberxp-os-ip>
```

**Restart SSH:**
```bash
sudo rc-service sshd restart
```

---

## 📊 SIEM Integration

### Splunk Configuration

**Location:** `/opt/cyberxp/src/integrations/splunk_config.py`

```python
# Edit Splunk integration
sudo nano /opt/cyberxp/src/integrations/splunk_config.py
```

**Configuration:**
```python
SPLUNK_CONFIG = {
    "host": "splunk.example.com",
    "port": 8088,
    "token": "your-hec-token-here",
    "index": "cyberxp",
    "sourcetype": "cyberxp:alert",
    "verify_ssl": True
}
```

### Microsoft Sentinel

```python
# Edit Sentinel integration
sudo nano /opt/cyberxp/src/integrations/sentinel_config.py

SENTINEL_CONFIG = {
    "workspace_id": "your-workspace-id",
    "shared_key": "your-shared-key",
    "log_type": "CyberXP"
}
```

### Elastic Stack

```python
# Edit Elastic integration
sudo nano /opt/cyberxp/src/integrations/elastic_config.py

ELASTIC_CONFIG = {
    "hosts": ["https://elasticsearch.example.com:9200"],
    "api_key": "your-api-key",
    "index": "cyberxp-alerts",
    "verify_certs": True
}
```

---

## 🤖 Custom AI Agents

### Creating Custom Agents

**Location:** `/opt/cyberxp/custom_agents/`

```bash
# Create new agent
sudo nano /opt/cyberxp/custom_agents/my_custom_agent.py
```

**Example Agent:**
```python
from src.base_agent import BaseAgent

class MyCustomAgent(BaseAgent):
    def __init__(self):
        super().__init__(
            name="My Custom Agent",
            description="Custom threat analysis agent",
            system_prompt="You are a specialized threat analyst..."
        )
    
    def analyze(self, data):
        # Your custom analysis logic
        result = self.llm.query(data)
        return result
```

**Register Agent:**
```python
# Edit main config
sudo nano /opt/cyberxp/src/config.py

# Add to CUSTOM_AGENTS list
CUSTOM_AGENTS = [
    "custom_agents.my_custom_agent.MyCustomAgent"
]
```

**Restart CyberXP:**
```bash
sudo rc-service cyberxp-agent restart
```

---

## 📝 Logging Configuration

### CyberXP Logging

**Location:** `/opt/cyberxp/src/config.py`

```python
# Logging configuration
LOGGING_CONFIG = {
    "level": "INFO",  # DEBUG, INFO, WARNING, ERROR, CRITICAL
    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    "handlers": {
        "file": {
            "filename": "/var/log/cyberxp-agent.log",
            "max_bytes": 10485760,  # 10MB
            "backup_count": 5
        },
        "console": {
            "enabled": True
        }
    }
}
```

### System Logging

**Location:** `/etc/rsyslog.conf`

```bash
# Edit rsyslog configuration
sudo nano /etc/rsyslog.conf

# Example: Forward to remote syslog
*.* @192.168.1.10:514

# Example: Separate security logs
auth,authpriv.* /var/log/auth.log
```

---

## ⚡ Performance Tuning

### CyberXP Performance

```python
# Edit config
sudo nano /opt/cyberxp/src/config.py

# Performance settings
PERFORMANCE_CONFIG = {
    "max_workers": 4,  # Parallel processing
    "batch_size": 10,  # Batch alert processing
    "cache_enabled": True,
    "cache_ttl": 3600,  # 1 hour
    "model_quantization": "int8"  # Reduce memory usage
}
```

### System Performance

```bash
# Increase file descriptors
sudo nano /etc/security/limits.conf

cyberxp soft nofile 65536
cyberxp hard nofile 65536

# Optimize network stack
sudo nano /etc/sysctl.conf

net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
```

---

## 🔄 Auto-Updates

### System Updates

```bash
# Create update script
sudo nano /etc/periodic/daily/system-update

#!/bin/sh
apk update
apk upgrade --available
apk cache clean

# Make executable
sudo chmod +x /etc/periodic/daily/system-update
```

### CyberXP Updates

```bash
# Create update script
sudo nano /etc/periodic/weekly/cyberxp-update

#!/bin/sh
cd /opt/cyberxp
git pull
pip3 install -r requirements.txt --upgrade
rc-service cyberxp-agent restart

# Make executable
sudo chmod +x /etc/periodic/weekly/cyberxp-update
```

---

## 💾 Backup Configuration

### Configuration Backup

```bash
# Create backup script
sudo nano /usr/local/bin/backup-config.sh

#!/bin/bash
BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d)

mkdir -p $BACKUP_DIR

# Backup configurations
tar -czf $BACKUP_DIR/config-$DATE.tar.gz \
    /etc/network/ \
    /etc/iptables/ \
    /etc/suricata/ \
    /etc/fail2ban/ \
    /opt/cyberxp/src/config.py \
    /opt/cyberxp/.env

# Keep last 30 days
find $BACKUP_DIR -name "config-*.tar.gz" -mtime +30 -delete

# Make executable
sudo chmod +x /usr/local/bin/backup-config.sh

# Run daily
sudo crontab -e
0 2 * * * /usr/local/bin/backup-config.sh
```

---

## 🧪 Testing Configuration

### Validate CyberXP Configuration

```bash
# Test configuration
cd /opt/cyberxp
python3 -c "from src.config import *; print('Config OK')"

# Test service start (dry run)
sudo rc-service cyberxp-agent checkconfig
```

### Validate Firewall

```bash
# Test iptables rules
sudo iptables-restore --test < /etc/iptables/rules.v4

# View current rules
sudo iptables -L -n -v
```

### Validate Suricata

```bash
# Test configuration
sudo suricata -T -c /etc/suricata/suricata.yaml

# Test rules
sudo suricata -T -S /etc/suricata/rules/local.rules
```

---

## 📚 Configuration Templates

Pre-configured templates available in `/opt/cyberxp/config_templates/`:

- `minimal.conf` - Minimal resource usage
- `balanced.conf` - Balanced performance/security
- `high-security.conf` - Maximum security
- `cloud.conf` - Cloud deployment optimized
- `enterprise.conf` - Enterprise features

**Apply Template:**
```bash
sudo cp /opt/cyberxp/config_templates/high-security.conf /opt/cyberxp/src/config.py
sudo rc-service cyberxp-agent restart
```

---

## 🆘 Troubleshooting

### Configuration Issues

```bash
# Validate configuration syntax
python3 -m py_compile /opt/cyberxp/src/config.py

# Check for typos in environment variables
cat /opt/cyberxp/.env

# Restore default configuration
cp /opt/cyberxp/src/config.py.default /opt/cyberxp/src/config.py
```

### Common Issues

**Issue:** CyberXP won't start after config change
```bash
# Check logs for errors
sudo tail -50 /var/log/cyberxp-agent.err

# Restore backup
sudo cp /opt/backups/config-latest.tar.gz /tmp/
cd /
sudo tar -xzf /tmp/config-latest.tar.gz
```

---

## 📖 Next Steps

- Review [User Guide](USER_GUIDE.md) for usage instructions
- See [Deployment Guide](DEPLOYMENT.md) for production deployment
- Join community for configuration tips

---

**Last Updated:** October 2025  
**Version:** 0.1.0-alpha

