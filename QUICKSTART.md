# CyberXP-OS Quick Start

## 🎯 Goal

Get CyberXP-OS running in a VM in under 10 minutes.

---

## Prerequisites

- Linux machine (Ubuntu/Debian recommended)
- 10GB free disk space
- VirtualBox installed
- Internet connection

---

## Steps

### 1. Clone Repositories

```bash
# Create workspace
mkdir ~/cyberxp-workspace && cd ~/cyberxp-workspace

# Clone CyberXP-OS
git clone https://github.com/abaryan/CyberXP-OS
cd CyberXP-OS

# Clone CyberXP core (required for build)
cd ..
git clone https://github.com/abaryan/CyberXP
cd CyberXP-OS
```

### 2. Build ISO

```bash
# Build (requires sudo for chroot)
sudo ./scripts/build-alpine-iso.sh

# Wait 10-20 minutes...
# Output: build/output/cyberxp-os-0.1.0-alpha.iso
```

### 3. Create VM

```bash
# Automated VM setup
./scripts/setup-dev-vm.sh

# Starts VirtualBox VM with ISO attached
```

### 4. Boot & Test

```bash
# Start VM
VBoxManage startvm "CyberXP-OS-Dev"

# Login credentials:
# Username: cyberxp
# Password: cyberxp

# Access CyberXP from host machine:
# http://localhost:7860
```

---

## What You Get

- Alpine Linux base (lightweight)
- CyberXP AI agent pre-installed at `/opt/cyberxp`
- Python 3 + all dependencies
- Security tools (Suricata, fail2ban, nmap)
- Auto-start services configured

---

## Next Steps

1. **Test CyberXP**: Access http://localhost:7860
2. **Customize**: Edit configs in `config/`
3. **Rebuild**: Make changes and run build script again
4. **Deploy**: Burn ISO to USB or deploy to hardware

---

## Status

**Phase 1 MVP** - Core features:
- ✅ Bootable filesystem
- ✅ CyberXP pre-installed
- ✅ Basic services
- 🔄 GUI dashboard (coming)
- 🔄 Auto-monitoring (coming)

---

**Full docs**: [README.md](README.md) | [Building](docs/BUILDING.md)

