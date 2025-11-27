# CyberXP-OS

**AI-Powered Security Operating System**

Ubuntu-based Linux distribution with integrated CyberXP AI security agent. Boot, monitor, and defend with minimal configuration.

---

![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)
![PyTorch](https://img.shields.io/badge/PyTorch-2.0+-red.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Quick Start

### Installation

```bash
# Clone repository
git clone https://github.com/r-abaryan/CyberXP-OS
cd CyberXP-OS

# Run installer (Ubuntu/Debian)
sudo ./scripts/install.sh
```

**Installer options:**
1. Dashboard only (Terminal or Web)
2. Dashboard + AI dependencies (includes CyberLLM-Agent)

**Dashboard types:**
- Terminal: Lightweight CLI monitor
- Web: Flask dashboard on port 8080

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

## Features

**Core Capabilities**
- Real-time system monitoring
- Security event tracking
- Service management
- Log analysis
- AI threat assessment (optional)

**Security Tools**
- Network monitoring (Suricata, tcpdump)
- Intrusion prevention (fail2ban)
- Firewall management (iptables/ufw)
- System hardening

**AI Integration** (optional)
- CyberLLM-Agent for threat analysis
- IOC extraction and enrichment
- Automated response recommendations
- SIEM integration support

---

## System Requirements

**Minimum:**
- CPU: 2 cores (x86_64)
- RAM: 2GB
- Disk: 8GB
- Network: Ethernet or WiFi

**Recommended:**
- CPU: 4 cores
- RAM: 4GB
- Disk: 20GB SSD
- Network: Gigabit Ethernet

**Supported Platforms:**
- Physical machines (UEFI/BIOS)
- VirtualBox, VMware, KVM
- Cloud VMs (AWS, Azure, GCP)

---

## Architecture

```
┌─────────────────────────────────────────┐
│     Dashboard (Terminal or Web)         │
├─────────────────────────────────────────┤
│     CyberXP Services (systemd)          │
│  • System monitoring                    │
│  • Security event tracking              │
│  • Service management                   │
├─────────────────────────────────────────┤
│     Optional: CyberLLM-Agent            │
│  • AI threat analysis                   │
│  • IOC extraction                       │
│  • Response recommendations             │
├─────────────────────────────────────────┤
│     Ubuntu 24.04 LTS                    │
└─────────────────────────────────────────┘
```

---

## Installation Options

### Option 1: Direct Installation

Install on existing Ubuntu system:

```bash
sudo ./scripts/install.sh
```

Choose:
1. Dashboard type (Terminal or Web)
2. Include AI dependencies (optional)

### Option 2: Bootable ISO

Create bootable ISO for deployment:

```bash
# Install build dependencies
sudo apt install debootstrap grub-pc-bin grub-efi-amd64-bin \
  xorriso squashfs-tools

# Build ISO
sudo ./scripts/iso/build-ubuntu-iso-fixed.sh

# Output: build/output/cyberxp-os-*.iso
```

### Option 3: Add AI Later

If you installed dashboard-only, add AI capabilities:

```bash
sudo ./scripts/install-cyberxp-dependencies.sh
```

---

## Usage

### Terminal Dashboard

```bash
# Launch dashboard
cyberxp

# Commands:
# q - Quit
# r - Refresh
# s - Service management
# l - View logs
# a - AI threat analysis (if installed)
```

### Web Dashboard

Access via browser: `http://localhost:8080`

Features:
- Real-time system metrics
- Service status monitoring
- Log viewer
- Quick actions

### AI Analysis

```bash
# Analyze threat (if AI installed)
cyberxp-analyze "Suspicious login from unknown IP"
```

---

## Project Structure

```
CyberXP-OS/
├── scripts/
│   ├── install.sh                      # Main installer
│   ├── install-cyberxp-dependencies.sh # AI add-on
│   ├── iso/                            # ISO builders
│   └── internal/                       # Helper scripts
├── config/
│   └── desktop/cyberxp-dashboard/      # Dashboard files
└── docs/                               # Documentation
```

---

## Development

### Build from Source

```bash
git clone https://github.com/r-abaryan/CyberXP-OS
cd CyberXP-OS
sudo ./scripts/install.sh
```

### Create Custom ISO

```bash
sudo ./scripts/iso/build-ubuntu-iso-fixed.sh
```

---

## Documentation

- [Installation Guide](docs/INSTALLATION.md)
- [User Manual](docs/USER_GUIDE.md)
- [API Documentation](docs/API.md)

---

## Tech Stack

- **Base**: Ubuntu 24.04 LTS
- **Init**: systemd
- **Dashboard**: Python + Flask (web) or CLI (terminal)
- **AI Engine**: CyberLLM-Agent (optional)
- **Security**: Suricata, fail2ban, iptables, ufw

---

## License

MIT License - Free for personal and commercial use.

---

## Links

- **GitHub**: [r-abaryan/CyberXP-OS](https://github.com/r-abaryan/CyberXP-OS)
- **AI Engine**: [r-abaryan/CyberLLM-Agent](https://github.com/r-abaryan/CyberLLM-Agent)
- **Issues**: [GitHub Issues](https://github.com/r-abaryan/CyberXP-OS/issues)

---

**Version**: 0.1.0-alpha  
**Status**: Active Development
