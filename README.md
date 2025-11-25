# 🛡️ CyberXP-OS: AI-Powered Security Linux Distribution

**The world's first AI-powered defensive security operating system.**

Ubuntu 24.04-based Linux distribution with CyberXP AI security agent built-in. Boot, monitor, and defend - no configuration required.

---

## 🚀 Quick Installation

Traditional security tools are complex, expensive, and require expert knowledge. **CyberXP-OS** changes that:

- **Boot and Go**: No installation, no configuration
- **AI-Powered**: Built-in threat assessment and response
- **User-Friendly**: GUI-first, minimal terminal needed
- **Self-Defending**: Automatically blocks threats
- **Free & Open**: Community edition available

---

## Features

### Core Capabilities
- **CyberXP AI Agent** - Multi-agent threat assessment pre-installed
- **Auto-Monitoring** - Continuous security monitoring on boot
- **Threat Detection** - IDS/IPS with AI analysis (Suricata + CyberXP)
- **Network Defense** - Real-time traffic analysis and blocking
- **IOC Enrichment** - Automatic VirusTotal lookups
- **SIEM Integration** - Pre-configured Splunk/Sentinel connectors
- **One-Click Actions** - Block IPs, quarantine files, isolate systems

### User Experience
- **Lightweight** - Boots in < 10 seconds
- **GUI Dashboard** - No terminal required for 90% of tasks
- **Live USB Ready** - Run from USB without installation
- **VM Optimized** - Perfect for VirtualBox/VMware
- **Auto-Updates** - Security updates automatically applied

### Use Cases
- **SOC Workstation** - Analyst desktop environment
- **Security Appliance** - Network gateway/sensor
- **Training Lab** - Cybersecurity education
- **Incident Response** - Bootable IR toolkit
- **Home Lab** - Personal security monitoring

---

## 🚀 Quick Start

### Download & Boot (Coming Soon)

```bash
# Download ISO
wget https://downloads.cyberxp-os.com/cyberxp-os-v1.0.iso

# Burn to USB (Linux)
sudo dd if=cyberxp-os-v1.0.iso of=/dev/sdX bs=4M

# Or use Rufus/Etcher on Windows/Mac
```

## 🚀 Minimal Quick Start (Alpine ISO)

- Boot ISO in VirtualBox (best: Bridged Adapter; or use NAT + port forward 8080)
- Login as **root** (press Enter for blank password)
- First boot will auto-install Python, pip, and dashboard (wait until "✓ CyberXP Dashboard started on port 8080")
- Find VM IP in Alpine with:
  ```sh
  ip addr
  # or
  ifconfig
  ```
- Access dashboard: `http://<vm-ip>:8080` from your host browser
- If VM has no IP, set network to **Bridged Adapter** and reboot the VM

## System Requirements

### Minimum
- **CPU**: 2 cores, x86_64
- **RAM**: 2GB
- **Disk**: 4GB (live mode), 8GB (installed)
- **Network**: Ethernet or WiFi

### Recommended
- **CPU**: 4 cores, x86_64
- **RAM**: 4GB
- **Disk**: 20GB SSD
- **GPU**: Optional (faster AI inference)
- **Network**: Gigabit Ethernet

### Supported Hardware
- Physical machines (UEFI/BIOS)
- VirtualBox, VMware, KVM
- Raspberry Pi 4+ (ARM build)
- Cloud VMs (AWS, Azure, GCP)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│      Flask Dashboard (http://localhost:8080)        │
│  ┌──────────┐  ┌────────┐  ┌────────┐  ┌────────┐   │
│  │ Status   │  │ Alerts │  │  Logs  │  │ Actions│   │
│  └──────────┘  └────────┘  └────────┘  └────────┘   │
├─────────────────────────────────────────────────────┤
│          CyberXP-OS Services (OpenRC)               │
│  ┌──────────────────────────────────────────────┐   │
│  │ cyberxp-dashboard (Security monitoring UI)   │   │
│  │ suricata          (IDS/IPS detection)        │   │
│  │ fail2ban          (Intrusion prevention)     │   │
│  │ iptables          (Firewall protection)      │   │
│  └──────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────┤
│          Security Monitoring Stack                  │
│  ┌───────────┐  ┌─────────┐  ┌──────────────────┐   │
│  │ Suricata  │  │ fail2ban│  │  iptables        │   │
│  │ (IDS/IPS) │  │ (IPS)   │  │  (Firewall)      │   │
│  └───────────┘  └─────────┘  └──────────────────┘   │
├─────────────────────────────────────────────────────┤
│        Alpine Linux 3.18.4 (Hardened Kernel)        │
│  Init: OpenRC | Firewall: iptables | Shell: bash   │
└─────────────────────────────────────────────────────┘
```

---

## What's Included

### Pre-installed Tools

**Web Dashboard (Flask)**
- Real-time system monitoring
- Security alerts viewer
- Service status tracking
- Log viewer (Suricata, fail2ban, system)
- Quick actions (block IPs, manage services)
- Professional, lightweight UI (port 8080)

**Network Security**
- Suricata (IDS/IPS) ✅
- iptables/nftables (firewall) ✅
- tcpdump (packet analysis) ✅
- fail2ban (intrusion prevention) ✅

**System Security**
- OpenRC init system ✅
- Hardened kernel (sysctl) ✅
- SSH rate limiting ✅
- Firewall rules pre-configured ✅

**Monitoring & Analysis**
- htop (process monitoring) ✅
- iotop (I/O monitoring) ✅
- nethogs (network monitoring) ✅
- nmap (network scanning) ✅

**Coming Soon**
- CyberXP AI integration (optional)
- Advanced threat analysis
- SIEM integrations (Splunk, Sentinel)
- VirusTotal connector
- Custom detection rules

---

## Editions

### Community Edition (FREE)
- Full CyberXP AI capabilities
- All security tools included
- Single-system deployment
- Community support (Discord/GitHub)
- Perfect for: Students, home labs, testing

### Professional Edition ($99/year)
- Everything in Community +
- Priority updates and patches
- Email support (48hr SLA)
- Compliance report templates
- Perfect for: SOC teams, small businesses

### Enterprise Edition (Custom)
- Everything in Professional +
- Multi-system fleet management
- Centralized dashboard
- Custom integrations
- On-premise deployment
- 24/7 support with SLA
- Perfect for: Enterprises, MSSPs

---

## 🛠️ Development

### Build from Source

```bash
# Clone repository
git clone https://github.com/r-abaryan/CyberXP-OS
cd CyberXP-OS

# Install build dependencies (Linux/WSL)
sudo apt install wget tar xorriso squashfs-tools syslinux isolinux

# Build ISO (requires root)
sudo ./scripts/build-alpine-iso.sh

# Output: build/output/cyberxp-os-0.1.0-alpha.iso
```

### Boot & Access

1. **Boot ISO in VirtualBox**
   - Network: Bridged Adapter (recommended) or NAT with port forwarding (8080)
   - Login: `root` (blank password)

2. **Wait for auto-installation**
   - Python 3, Flask, PyTorch, and dashboard install automatically
   - Wait for: `✓ CyberXP Dashboard started on port 8080`

3. **Get VM IP**
   ```sh
   ip addr
   ```

4. **Access Dashboard**
   - From host: `http://<vm-ip>:8080`
   - Or with NAT: `http://localhost:8080` (after port forwarding)

---

## 📦 Tech Stack

- **Base**: Alpine Linux 3.18.4
- **Python**: 3.x (auto-installed)
- **PyTorch**: For AI/ML threat detection
- **Flask**: Web dashboard (port 8080)
- **OpenRC**: Service management
- **Security Tools**: Suricata, fail2ban, iptables

---

## 💻 System Requirements

**Minimum:**
- CPU: 2 cores (x86_64)
- RAM: 2GB
- Disk: 4GB (live mode)

**Recommended:**
- CPU: 4 cores
- RAM: 4GB
- GPU: Optional (faster AI inference)

---

## 🛠️ Features

- **AI-Powered Threat Detection** - PyTorch-based analysis
- **Web Dashboard** - Real-time monitoring (Flask)
- **Network Security** - Suricata IDS/IPS, iptables firewall
- **Auto-Monitoring** - Continuous security scanning
- **Live Boot** - Run from ISO/USB without installation

---

## 📚 Documentation

- [Quick Start Guide](docs/QUICKSTART.md)
- [Installation Guide](docs/INSTALLATION.md)
- [User Manual](docs/USER_GUIDE.md)

---

## 📊 Status

**Version**: 0.1.0-alpha  
**Status**: Bootable ISO ready  
**Base**: Alpine Linux 3.18.4

---

## 📄 License

MIT License - Free for personal and commercial use.

---

**GitHub**: [r-abaryan/CyberXP-OS](https://github.com/r-abaryan/CyberXP-OS)
