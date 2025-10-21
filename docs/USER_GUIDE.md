# CyberXP-OS User Guide

## 🎯 Getting Started

Welcome to CyberXP-OS! This guide will help you understand and use your AI-powered security operating system.

---

## 🖥️ First Boot

### Login Credentials

**Default credentials (CHANGE IMMEDIATELY IN PRODUCTION!):**
- Username: `cyberxp`
- Password: `cyberxp`

**Root access:**
- Username: `root`
- Password: `cyberxp`

### First Steps

1. **Login** to the system
2. **Change default passwords**:
   ```bash
   passwd              # Change cyberxp password
   sudo passwd root    # Change root password
   ```
3. **Access CyberXP Dashboard**: Open browser to http://localhost:7860

---

## 🎨 User Interface

### CyberXP Web Dashboard

The primary interface for CyberXP-OS is the web-based dashboard.

**Access:**
- Local: http://localhost:7860
- Network: http://<server-ip>:7860

**Main Sections:**

1. **Threat Assessment**
   - Upload logs/alerts for AI analysis
   - Get threat severity scores
   - View recommended actions

2. **Real-Time Monitoring**
   - Live network traffic analysis
   - System events monitoring
   - Active threat detection

3. **IOC Management**
   - Indicator of Compromise (IOC) extraction
   - VirusTotal integration
   - Threat intelligence enrichment

4. **Incident Response**
   - One-click actions (block IP, quarantine file)
   - Automated response workflows
   - Investigation tools

5. **Reports & Analytics**
   - Security posture overview
   - Threat trends
   - Compliance reports

---

## 🔧 Command Line Basics

### Essential Commands

```bash
# System Management
sudo rc-service cyberxp-agent status    # Check CyberXP status
sudo rc-service cyberxp-agent restart   # Restart CyberXP
sudo rc-service cyberxp-agent logs      # View logs

# Network
ip addr show                             # Show IP addresses
ping 8.8.8.8                            # Test connectivity
sudo tcpdump -i eth0                    # Capture packets

# Security Tools
sudo suricata -T                        # Test Suricata config
sudo fail2ban-client status             # Check fail2ban
sudo nmap localhost                      # Scan local ports

# System Info
htop                                    # Process monitor
df -h                                   # Disk usage
free -h                                 # Memory usage
uname -a                                # System info
```

---

## 🛡️ Core Features

### 1. Threat Assessment

**AI-Powered Analysis:**
```bash
# From dashboard:
1. Navigate to "Threat Assessment"
2. Upload alert/log file
3. AI analyzes and provides:
   - Severity score (0-10)
   - Attack classification
   - Recommended actions
   - IOCs extracted
```

**CLI Alternative:**
```bash
cd /opt/cyberxp
python3 -c "from src.cyberxp import analyze_threat; analyze_threat('alert.json')"
```

### 2. Network Monitoring

**Suricata IDS/IPS:**
```bash
# Check status
sudo rc-service suricata status

# View alerts
sudo tail -f /var/log/suricata/fast.log

# Custom rules
sudo nano /etc/suricata/rules/local.rules
sudo rc-service suricata reload
```

**Real-Time Traffic:**
```bash
# Monitor with tcpdump
sudo tcpdump -i eth0 -n

# Monitor with CyberXP (in dashboard)
# Navigate to "Network Monitoring"
```

### 3. Intrusion Prevention

**fail2ban:**
```bash
# Check banned IPs
sudo fail2ban-client status sshd

# Unban IP
sudo fail2ban-client set sshd unbanip 192.168.1.100

# View logs
sudo tail -f /var/log/fail2ban.log
```

**Firewall (iptables):**
```bash
# View rules
sudo iptables -L -n

# Block IP
sudo iptables -A INPUT -s 192.168.1.100 -j DROP

# Save rules
sudo rc-service iptables save
```

### 4. IOC Enrichment

**Automatic VirusTotal Lookups:**
```bash
# Configure API key (in dashboard or config)
echo "VIRUSTOTAL_API_KEY=your_key_here" | sudo tee -a /opt/cyberxp/.env

# IOCs are automatically enriched in dashboard
```

### 5. Incident Response

**One-Click Actions (Dashboard):**
- **Block IP**: Automatically adds iptables rule
- **Quarantine File**: Moves file to isolated directory
- **Isolate System**: Disables network interfaces
- **Kill Process**: Terminates suspicious process

**CLI Actions:**
```bash
# Block IP
sudo /opt/cyberxp/scripts/block-ip.sh 192.168.1.100

# Quarantine file
sudo /opt/cyberxp/scripts/quarantine-file.sh /suspicious/file

# Network isolation
sudo ifdown eth0
```

---

## 📊 Monitoring & Logs

### Log Locations

```bash
# CyberXP Logs
/var/log/cyberxp-agent.log          # Main application log
/var/log/cyberxp-agent.err          # Error log
/opt/cyberxp/feedback_logs/         # User feedback

# Security Logs
/var/log/suricata/                  # IDS alerts
/var/log/fail2ban.log               # Ban/unban events
/var/log/auth.log                   # Authentication attempts

# System Logs
/var/log/messages                   # System messages
/var/log/syslog                     # General syslog
```

### Viewing Logs

```bash
# Real-time monitoring
sudo tail -f /var/log/cyberxp-agent.log

# Search logs
sudo grep "ERROR" /var/log/cyberxp-agent.log

# View with less
sudo less /var/log/suricata/fast.log
```

---

## ⚙️ Configuration

### CyberXP Configuration

**Main config file:**
```bash
sudo nano /opt/cyberxp/src/config.py
```

**Environment variables:**
```bash
sudo nano /opt/cyberxp/.env

# Key variables:
VIRUSTOTAL_API_KEY=your_key
GRADIO_SERVER_PORT=7860
AI_MODEL=mistralai/Mistral-7B-Instruct-v0.2
```

### Network Configuration

```bash
# Static IP
sudo nano /etc/network/interfaces

auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4

# Apply changes
sudo rc-service networking restart
```

### Firewall Configuration

```bash
# Edit rules
sudo nano /etc/iptables/rules.v4

# Or use CyberXP dashboard (recommended)
```

---

## 🚨 Common Tasks

### Analyzing an Alert

1. Open CyberXP dashboard (http://localhost:7860)
2. Click "Threat Assessment"
3. Upload alert file (JSON, CSV, or text)
4. Review AI analysis:
   - Severity score
   - Attack type
   - Recommended actions
5. Take action if needed

### Blocking a Malicious IP

**Via Dashboard:**
1. Navigate to "Incident Response"
2. Enter IP address
3. Click "Block IP"

**Via CLI:**
```bash
sudo iptables -A INPUT -s 192.168.1.100 -j DROP
sudo rc-service iptables save
```

### Investigating a File

```bash
# Calculate hash
md5sum /suspicious/file
sha256sum /suspicious/file

# Check with VirusTotal (via dashboard)
1. Navigate to "IOC Enrichment"
2. Enter file hash
3. View reputation

# Scan with ClamAV
sudo clamscan /suspicious/file
```

### Updating the System

```bash
# Update package list
sudo apk update

# Upgrade all packages
sudo apk upgrade

# Upgrade CyberXP (if available)
cd /opt/cyberxp
git pull
pip3 install -r requirements.txt --upgrade
sudo rc-service cyberxp-agent restart
```

---

## 🔐 Security Best Practices

### 1. Password Management
- Change default passwords immediately
- Use strong passwords (16+ characters)
- Consider SSH key-based authentication

### 2. Network Security
- Keep firewall enabled
- Only open necessary ports
- Use VPN for remote access

### 3. System Updates
- Apply security updates regularly
- Subscribe to security advisories
- Test updates in staging first

### 4. Monitoring
- Review logs daily
- Set up alerting for critical events
- Monitor CyberXP dashboard regularly

### 5. Backup
- Backup configuration files
- Export CyberXP custom agents
- Document your security policies

---

## 🐛 Troubleshooting

### CyberXP Won't Start

```bash
# Check service status
sudo rc-service cyberxp-agent status

# View logs
sudo tail -50 /var/log/cyberxp-agent.err

# Common fixes:
# 1. Check Python dependencies
cd /opt/cyberxp
pip3 install -r requirements.txt

# 2. Check permissions
sudo chown -R cyberxp:cyberxp /opt/cyberxp

# 3. Restart service
sudo rc-service cyberxp-agent restart
```

### Dashboard Not Accessible

```bash
# Check if service is running
sudo rc-service cyberxp-agent status

# Check if port is open
sudo netstat -tulpn | grep 7860

# Check firewall
sudo iptables -L -n | grep 7860

# Test locally
curl http://localhost:7860
```

### Network Issues

```bash
# Check network interfaces
ip addr show

# Check routing
ip route show

# Test DNS
ping google.com

# Restart networking
sudo rc-service networking restart
```

### High CPU/Memory Usage

```bash
# Check processes
htop

# Check CyberXP resource usage
ps aux | grep python3

# Restart CyberXP
sudo rc-service cyberxp-agent restart
```

---

## 📚 Advanced Topics

### Custom Security Rules

**Suricata Custom Rules:**
```bash
sudo nano /etc/suricata/rules/local.rules

# Example rule:
alert tcp any any -> $HOME_NET 22 (msg:"SSH Connection Attempt"; sid:1000001; rev:1;)

sudo rc-service suricata reload
```

### SIEM Integration

**Splunk Forwarding:**
```bash
# Configure in CyberXP dashboard
# Or edit config:
sudo nano /opt/cyberxp/src/integrations/splunk_config.py
```

**Elastic Stack:**
```bash
# Install Filebeat (optional)
sudo apk add filebeat
# Configure forwarding to Elasticsearch
```

### Custom AI Agents

```bash
# Navigate to custom agents directory
cd /opt/cyberxp/custom_agents

# Create new agent
nano my_custom_agent.py

# Restart CyberXP
sudo rc-service cyberxp-agent restart
```

---

## 🆘 Getting Help

### Resources
- **Documentation**: https://docs.cyberxp-os.com
- **GitHub**: https://github.com/abaryan/CyberXP-OS
- **Discord**: https://discord.gg/cyberxp
- **Email**: support@cyberxp-os.com

### Reporting Issues
1. Check existing issues on GitHub
2. Collect logs and error messages
3. Create detailed bug report
4. Include system information

---

## 📖 Next Steps

- Explore [Configuration Guide](CONFIGURATION.md) for advanced settings
- Review [Deployment Scenarios](DEPLOYMENT.md) for production use
- Join the community on Discord
- Contribute to the project!

---

**Last Updated:** October 2025  
**Version:** 0.1.0-alpha

