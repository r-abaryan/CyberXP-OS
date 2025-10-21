# Building CyberXP-OS from Source

## Prerequisites

### Required OS
- **Linux** (Ubuntu 22.04+ recommended)
- **WSL2** on Windows (also works)
- **macOS** not supported for building (use Linux VM)

### Required Tools

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y \
    wget tar gzip \
    xorriso squashfs-tools \
    git python3 python3-pip \
    qemu-system-x86 \
    virtualbox

# Arch Linux
sudo pacman -S wget tar gzip xorriso squashfs-tools \
    git python qemu virtualbox

# Fedora
sudo dnf install wget tar gzip xorriso squashfs-tools \
    git python3 qemu virtualbox
```

### Required Space
- **Build**: ~5GB
- **Output ISO**: ~1-2GB
- **Total**: ~10GB recommended

---

## Quick Build

```bash
# 1. Clone repositories
git clone https://github.com/abaryan/CyberXP-OS
cd CyberXP-OS

# 2. Get CyberXP core (must be in parent directory)
cd ..
git clone https://github.com/abaryan/CyberXP
cd CyberXP-OS

# 3. Build ISO (requires root)
sudo ./scripts/build-alpine-iso.sh

# 4. Output
ls -lh build/output/cyberxp-os-*.iso
```

---

## Step-by-Step Build Process

### 1. Prepare Build Environment

```bash
# Create workspace
mkdir -p ~/cyberxp-workspace
cd ~/cyberxp-workspace

# Clone CyberXP-OS
git clone https://github.com/abaryan/CyberXP-OS
cd CyberXP-OS

# Clone CyberXP core (needed for build)
cd ..
git clone https://github.com/abaryan/CyberXP
```

**Directory structure should be:**
```
~/cyberxp-workspace/
├── CyberXP/          # Core AI engine
└── CyberXP-OS/       # OS build scripts
```

### 2. Review Build Configuration

```bash
cd CyberXP-OS

# Edit build script if needed
nano scripts/build-alpine-iso.sh

# Key variables:
# - ALPINE_VERSION: Alpine Linux version
# - ISO_VERSION: CyberXP-OS version
# - CYBERXP_CORE: Path to CyberXP core
```

### 3. Run Build Script

```bash
# Must run as root (for chroot operations)
sudo ./scripts/build-alpine-iso.sh
```

**Build process will:**
1. Download Alpine Linux base (~130MB)
2. Extract and setup chroot environment
3. Install base packages
4. Copy CyberXP core to /opt/cyberxp
5. Install Python dependencies
6. Configure system services
7. Create SquashFS filesystem
8. Generate bootable ISO

**Expected time:** 10-30 minutes (depends on internet speed)

### 4. Verify Build

```bash
# Check output
ls -lh build/output/

# Verify ISO
file build/output/cyberxp-os-*.iso
```

---

## Testing the Build

### Option 1: QEMU (Quick Test)

```bash
# Run in QEMU
qemu-system-x86_64 \
    -cdrom build/output/cyberxp-os-*.iso \
    -m 4G \
    -smp 2 \
    -enable-kvm  # if available
```

### Option 2: VirtualBox

```bash
# Use setup script
./scripts/setup-dev-vm.sh

# Start VM
VBoxManage startvm "CyberXP-OS-Dev"
```

### Option 3: Physical USB

```bash
# Find USB device
lsblk

# Burn to USB (DANGEROUS - double check device!)
sudo dd if=build/output/cyberxp-os-*.iso of=/dev/sdX bs=4M status=progress

# Or use Etcher (safer)
# https://www.balena.io/etcher/
```

---

## Customizing the Build

### Add Custom Packages

Edit `config/system/packages.txt`:
```bash
nano config/system/packages.txt

# Add your packages
wireshark
nmap
```

### Modify CyberXP Configuration

Edit files in CyberXP core before building:
```bash
cd ../CyberXP
nano src/config.py

# Your changes will be included in build
```

### Change Default Credentials

Edit `scripts/build-alpine-iso.sh`:
```bash
# Find this section:
echo "root:cyberxp" | chpasswd

# Change to:
echo "root:YOUR_PASSWORD" | chpasswd
```

⚠️ **Security Note**: Change default passwords for production!

---

## Build Variants

### Minimal Build (< 500MB)
```bash
# Edit build script, comment out heavy packages
nano scripts/build-alpine-iso.sh

# Remove: wireshark, volatility, etc.
```

### GUI Build (2-3GB)
```bash
# Uncomment desktop environment in packages.txt
nano config/system/packages.txt

# Uncomment:
# xfce4
# xfce4-terminal
# firefox
```

### Cloud-Ready Build
```bash
# Optimized for cloud VMs (no desktop)
# Skip bootloader, use cloud-init
# Build as .qcow2 instead of ISO
```

---

## Troubleshooting

### "Command not found" errors
```bash
# Install missing tools
sudo apt install xorriso squashfs-tools
```

### "CyberXP core not found"
```bash
# Check directory structure
ls ../CyberXP

# If missing, clone it
cd ..
git clone https://github.com/abaryan/CyberXP
```

### "Permission denied"
```bash
# Run with sudo
sudo ./scripts/build-alpine-iso.sh
```

### Build fails in chroot
```bash
# Clean and retry
sudo rm -rf build/alpine/rootfs
sudo ./scripts/build-alpine-iso.sh
```

### ISO won't boot
```bash
# Phase 1: Bootloader not yet implemented
# Test filesystem directly:
sudo mount -o loop,ro build/output/*.iso /mnt
ls /mnt
```

---

## Advanced Topics

### Cross-Architecture Build

```bash
# Build ARM64 version (for Raspberry Pi)
# TODO: Not yet implemented

# Would require:
# - ARM64 Alpine base
# - QEMU user-mode emulation
# - Modified kernel/bootloader
```

### Automated CI/CD Build

```bash
# GitHub Actions workflow (coming soon)
# Will automatically build on each commit
```

### Incremental Builds

```bash
# Cache Alpine downloads
export ALPINE_CACHE=~/alpine-cache
mkdir -p $ALPINE_CACHE

# Modify build script to use cache
# (reduces rebuild time from 20min to 5min)
```

---

## Clean Up

```bash
# Remove build artifacts
sudo rm -rf build/alpine/rootfs
sudo rm -rf build/alpine/temp

# Keep ISO and downloads
# Or remove everything:
sudo rm -rf build/
```

---

## Getting Help

- **Issues**: https://github.com/abaryan/CyberXP-OS/issues
- **Discord**: https://discord.gg/cyberxp (coming soon)
- **Docs**: https://docs.cyberxp-os.com (coming soon)

---

**Next**: [Installation Guide](INSTALLATION.md) | [User Guide](USER_GUIDE.md)

