# CyberXP-OS Quick Start

Get CyberXP-OS running in **15 minutes**.

---

## Prerequisites

- Linux machine (Ubuntu 22.04+ or WSL2)
- 10GB disk space
- VirtualBox installed
- Internet connection

---

## Build & Run

### 1. Clone & Build
```bash
git clone https://github.com/abaryan/CyberXP-OS
cd CyberXP-OS

# Build bootable ISO (15-20 min)
sudo ./scripts/build-alpine-iso.sh
```

### 2. Create VM
```bash
# Setup VirtualBox VM
./scripts/setup-dev-vm.sh
```

### 3. Boot
```bash
# Start VM
VBoxManage startvm "CyberXP-OS-Dev"

# Login: cyberxp / cyberxp
# Dashboard: http://localhost:8080
```

---

## What You Get

- ✅ Alpine Linux 3.18.4 (lightweight, secure)
- ✅ Flask Dashboard (port 8080)
- ✅ Security tools (Suricata, fail2ban, iptables)
- ✅ OpenRC services (auto-start)
- ✅ Bootable ISO (BIOS/UEFI ready)

---

## Features

**Dashboard**:
- Real-time system monitoring
- Service status
- Security alerts
- Log viewer
- Quick actions (block IP, etc.)

**Security**:
- Firewall (iptables)
- IDS/IPS (Suricata)
- Intrusion prevention (fail2ban)
- Hardened kernel

---

## Next Steps

1. Access dashboard: `http://localhost:8080`
2. Check logs: Dashboard → Logs
3. Customize: Edit `config/` files
4. Rebuild: Re-run build script

---

**Docs**: [README.md](README.md) | [Technical Architecture](docs/TECHNICAL_ARCHITECTURE.md)

