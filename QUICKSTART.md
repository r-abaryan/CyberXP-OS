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

# Access Dashboard from host machine:
# http://localhost:8080
```

---

## What You Get

- Alpine Linux 3.18.4 base (lightweight, ~130MB)
- Flask Dashboard at `/opt/cyberxp-dashboard` (port 8080)
- Python 3 + Flask dependencies
- Security tools (Suricata, fail2ban, nmap, iptables)
- OpenRC services auto-start configured
- Hardened firewall and kernel settings

---

## Next Steps

1. **Test Dashboard**: Access http://localhost:8080
2. **Review Logs**: Check system status, alerts, and logs
3. **Customize**: Edit configs in `config/`
4. **Rebuild**: Make changes and run build script again
5. **Deploy**: Burn ISO to USB or deploy to hardware

---

## Status

**Phase 1 MVP** - Core features:
- ✅ Alpine Linux filesystem
- ✅ Flask Dashboard (port 8080)
- ✅ OpenRC services configured
- ✅ Security tools integrated
- ✅ System hardening complete
- 🔄 Bootloader (Phase 2 next)

---

**Full docs**: [README.md](README.md) | [Building](docs/BUILDING.md)

