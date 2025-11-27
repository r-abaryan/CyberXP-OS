# Building Ubuntu ISO

## Overview

This guide explains how the Ubuntu ISO build process works step-by-step. The script creates a bootable ISO containing CyberXP-OS based on Ubuntu 24.04.

**What you get:**
- Bootable Ubuntu 24.04 ISO (BIOS + UEFI)
- CyberXP Dashboard pre-installed
- Auto-starting services
- Network auto-configuration

**Time required:** 30-45 minutes

## Prerequisites

**Required tools:**
```bash
sudo apt install debootstrap grub-pc-bin grub-efi-amd64-bin \
  xorriso squashfs-tools mtools
```

**Verify installation:**
```bash
which debootstrap grub-mkrescue xorriso mksquashfs
# Should output paths to all four tools
```

**System requirements:**
- Ubuntu/Debian host system
- Root access
- 10GB free disk space
- Internet connection

**Check disk space:**
```bash
df -h
# Need at least 10GB free
```

## Build Process

### 1. Environment Check

**Script location:** `check_requirements()` function

**What it checks:**
```bash
# Running as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Must run as root"
    exit 1
fi

# Required tools
for tool in debootstrap grub-mkrescue xorriso mksquashfs; do
    command -v "$tool" || exit 1
done

# Disk space (10GB minimum)
df "$BUILD_DIR" | awk 'NR==2 {if ($4 < 10485760) exit 1}'

# Network connectivity
ping -c 1 -W 3 archive.ubuntu.com
```

**Verify manually:**
```bash
# Check you're root
whoami  # Should output: root

# Check disk space
df -h | grep -E '/$|/home'

# Test network
ping -c 3 archive.ubuntu.com
```

### 2. Create Base System

**Script location:** `download_ubuntu()` function

**Tool:** debootstrap

Downloads and installs minimal Ubuntu 24.04 to `build/ubuntu/rootfs/`:

```bash
debootstrap --arch=amd64 \
    --include=systemd,systemd-sysv,dbus \
    --verbose \
    noble \
    build/ubuntu/rootfs \
    http://archive.ubuntu.com/ubuntu/
```

**What this does:**
1. Downloads ~400MB of .deb packages
2. Extracts to rootfs directory
3. Creates directory structure:
   ```
   rootfs/
   ├── bin/
   ├── boot/
   ├── etc/
   ├── lib/
   ├── usr/
   └── var/
   ```
4. Installs package manager (apt)
5. Configures basic system

**Mirror fallback:**
Script tries multiple mirrors if primary fails:
```bash
mirrors=(
    "http://archive.ubuntu.com/ubuntu/"
    "http://us.archive.ubuntu.com/ubuntu/"
    "http://mirror.math.princeton.edu/pub/ubuntu/"
    "http://mirrors.kernel.org/ubuntu/"
)
```

**Verify:**
```bash
# Check rootfs was created
ls -la build/ubuntu/rootfs/
# Should show bin, etc, usr, var directories

# Check size
du -sh build/ubuntu/rootfs/
# Should be ~1-2GB
```

### 3. Setup Chroot Environment

**Mounts required filesystems:**
```bash
mount --bind /dev build/ubuntu/rootfs/dev
mount --bind /proc build/ubuntu/rootfs/proc
mount --bind /sys build/ubuntu/rootfs/sys
```

**Configures DNS:**
Copies `/etc/resolv.conf` or uses fallback (8.8.8.8)

**Sets up APT sources:**
```
deb http://archive.ubuntu.com/ubuntu/ noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ noble-security main restricted universe multiverse
```

### 4. Install Packages

**Inside chroot, installs:**

Base system:
- python3, python3-pip
- systemd, dbus
- linux-image-generic (kernel)
- initramfs-tools

Bootloader:
- grub-pc-bin (BIOS)
- grub-efi-amd64-bin (UEFI)

Network tools:
- net-tools, iproute2, iputils-ping

Python packages (via pip):
- Flask==3.0.0
- Werkzeug==3.0.1
- psutil==5.9.0

### 5. Install CyberXP Dashboard

**Copies dashboard files:**
```
config/desktop/cyberxp-dashboard/ → /opt/cyberxp-dashboard/
```

**Creates minimal dashboard if source missing:**
- Basic Flask app
- System monitoring (CPU, memory, disk)
- Service status display

### 6. Configure Services

**Creates systemd service:**
```ini
[Unit]
Description=CyberXP-OS Security Dashboard
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cyberxp-dashboard
ExecStart=/usr/bin/python3 /opt/cyberxp-dashboard/app.py
Restart=always
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
```

**Enables services:**
- cyberxp-dashboard (auto-start)
- ssh (remote access)
- systemd-networkd (networking)

### 7. System Configuration

**Script location:** `configure_system()` function

**Sets hostname:**
```bash
echo "cyberxp-os" > /etc/hostname
```

**Configures hosts file:**
```bash
cat > /etc/hosts <<EOF
127.0.0.1   localhost
127.0.1.1   cyberxp-os
::1         localhost ip6-localhost ip6-loopback
EOF
```

**Creates users:**
```bash
# Root password
echo "root:cyberxp" | chpasswd

# Create cyberxp user with sudo access
useradd -m -s /bin/bash -G sudo cyberxp
echo "cyberxp:cyberxp" | chpasswd
```

**User directories created:**
```
/home/cyberxp/
├── .bashrc
├── .profile
└── .bash_logout
```

**Configures network:**
```bash
# /etc/netplan/01-netcfg.yaml
cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  ethernets:
    all:
      match:
        name: "en*"
      dhcp4: true
      dhcp6: false
EOF
```

**Sets timezone:**
```bash
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
```

**Configures SSH:**
```bash
# /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
```

**Creates MOTD:**
```bash
# /etc/motd
cat > /etc/motd <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║          CyberXP-OS v0.1.0-alpha                         ║
║      AI-Powered Security Analysis Platform               ║
╚═══════════════════════════════════════════════════════════╝

Login Credentials:
  Username: cyberxp
  Password: cyberxp
  
Dashboard: http://<this-ip>:8080
Find IP: ip addr show

Quick Commands:
  • Check dashboard: sudo systemctl status cyberxp-dashboard
  • View logs: sudo journalctl -u cyberxp-dashboard -f
  • Restart: sudo systemctl restart cyberxp-dashboard
EOF
```

## System Files Modified

### During Installation

**Package management:**
```
/etc/apt/sources.list          # Ubuntu repositories
/var/lib/apt/lists/*           # Package lists
/var/cache/apt/archives/*      # Downloaded .deb files
```

**System configuration:**
```
/etc/hostname                  # System hostname
/etc/hosts                     # Host resolution
/etc/timezone                  # Timezone setting
/etc/localtime                 # Timezone symlink
/etc/locale.gen                # Locale configuration
/etc/default/locale            # Default locale
```

**Network configuration:**
```
/etc/netplan/01-netcfg.yaml   # Network auto-config
/etc/resolv.conf               # DNS configuration
/etc/network/interfaces        # Legacy network config (unused)
```

**User management:**
```
/etc/passwd                    # User accounts
/etc/shadow                    # User passwords
/etc/group                     # User groups
/etc/sudoers.d/               # Sudo permissions
/home/cyberxp/                # User home directory
```

**SSH configuration:**
```
/etc/ssh/sshd_config          # SSH server config
/etc/ssh/ssh_host_*           # SSH host keys
```

**Boot configuration:**
```
/boot/vmlinuz-*               # Linux kernel
/boot/initrd.img-*            # Initial ramdisk
/boot/grub/grub.cfg           # GRUB configuration
/boot/grub/grubenv            # GRUB environment
```

**CyberXP files:**
```
/opt/cyberxp-dashboard/       # Dashboard application
├── app.py                    # Main Flask app
├── requirements.txt          # Python dependencies
└── static/                   # Static assets (if any)
```

**Systemd services:**
```
/etc/systemd/system/cyberxp-dashboard.service  # Dashboard service
/etc/systemd/system/multi-user.target.wants/  # Auto-start links
```

**Logs:**
```
/var/log/apt/                 # Package installation logs
/var/log/dpkg.log             # Package manager log
/var/log/auth.log             # Authentication log
/var/log/syslog               # System log
```

### Runtime Directories

**Temporary files:**
```
/tmp/                         # Temporary files
/var/tmp/                     # Persistent temp files
/run/                         # Runtime data
```

**System state:**
```
/var/lib/systemd/             # Systemd state
/var/lib/dpkg/                # Package manager state
```

## Directory Structure

**Complete rootfs layout:**
```
build/ubuntu/rootfs/
├── bin/                      # Essential binaries
├── boot/                     # Boot files (kernel, initrd)
├── dev/                      # Device files (mounted)
├── etc/                      # Configuration files
│   ├── apt/                  # APT configuration
│   ├── netplan/              # Network configuration
│   ├── ssh/                  # SSH configuration
│   ├── systemd/              # Systemd configuration
│   ├── hostname              # System hostname
│   ├── hosts                 # Host resolution
│   ├── passwd                # User accounts
│   ├── shadow                # User passwords
│   └── motd                  # Message of the day
├── home/                     # User home directories
│   └── cyberxp/              # CyberXP user home
├── lib/                      # System libraries
├── opt/                      # Optional software
│   └── cyberxp-dashboard/    # CyberXP dashboard
├── proc/                     # Process info (mounted)
├── root/                     # Root user home
├── run/                      # Runtime data
├── sbin/                     # System binaries
├── sys/                      # System info (mounted)
├── tmp/                      # Temporary files
├── usr/                      # User programs
│   ├── bin/                  # User binaries
│   ├── lib/                  # User libraries
│   ├── share/                # Shared data
│   └── local/                # Local installations
└── var/                      # Variable data
    ├── cache/                # Cache files
    ├── lib/                  # State information
    ├── log/                  # Log files
    └── tmp/                  # Temporary files
```

**ISO structure:**
```
build/ubuntu/iso/
├── boot/
│   └── grub/
│       ├── grub.cfg          # GRUB menu configuration
│       └── i386-pc/          # BIOS boot files
├── EFI/
│   └── BOOT/
│       └── BOOTX64.EFI       # UEFI boot loader
└── casper/
    ├── vmlinuz               # Linux kernel
    ├── initrd                # Initial ramdisk
    ├── filesystem.squashfs   # Compressed rootfs
    └── filesystem.size       # Size metadata
```

### 8. Bootloader Setup

**Script location:** `setup_bootloader()` function

**Updates initramfs:**
```bash
# Inside chroot
update-initramfs -u -k all
```

**What this does:**
- Regenerates initial ramdisk for all installed kernels
- Includes necessary drivers and modules
- Creates `/boot/initrd.img-*` files
- Required for system boot

**Verify initramfs created:**
```bash
ls -lh build/ubuntu/rootfs/boot/initrd.img-*
# Should show file ~50-100MB
```

**Generates GRUB configuration:**
```bash
# Inside chroot
update-grub
# Or manually:
grub-mkconfig -o /boot/grub/grub.cfg
```

**GRUB config file created:**
```
/boot/grub/grub.cfg
```

**Config includes:**
- Kernel boot entries
- Recovery mode options
- Memory test options
- Kernel parameters

**Verifies kernel files:**

Script checks for required boot files:
```bash
# Kernel
ls build/ubuntu/rootfs/boot/vmlinuz-*
# Example: vmlinuz-6.8.0-48-generic

# Initramfs
ls build/ubuntu/rootfs/boot/initrd.img-*
# Example: initrd.img-6.8.0-48-generic
```

**If kernel missing:**
```bash
# Error shown:
ERROR: Kernel installation failed in chroot
No kernel found in /boot

# Manual fix:
sudo chroot build/ubuntu/rootfs /bin/bash
apt install -y linux-image-generic
update-initramfs -u -k all
exit
```

**Boot files created:**
```
/boot/
├── vmlinuz-6.8.0-48-generic      # Linux kernel (~10MB)
├── initrd.img-6.8.0-48-generic   # Initial ramdisk (~50MB)
├── System.map-6.8.0-48-generic   # Kernel symbol map
├── config-6.8.0-48-generic       # Kernel build config
└── grub/
    ├── grub.cfg                  # GRUB configuration
    ├── grubenv                   # GRUB environment
    └── fonts/                    # GRUB fonts
```

**GRUB modules installed:**
```
/boot/grub/i386-pc/       # BIOS boot modules
/boot/grub/x86_64-efi/    # UEFI boot modules
```

**Important:** Script does NOT install GRUB to a device (no `/dev/loop0` or `/dev/sda`). This is intentional because:
1. We're building an ISO, not installing to disk
2. `grub-mkrescue` handles bootloader embedding later
3. Device installation would fail in build environment

### 9. Create ISO Structure

**Directory layout:**
```
build/ubuntu/iso/
├── boot/grub/
├── EFI/BOOT/
└── casper/
    ├── vmlinuz (kernel)
    ├── initrd (initramfs)
    ├── filesystem.squashfs (compressed rootfs)
    └── filesystem.size
```

**Copies kernel:**
```bash
cp build/ubuntu/rootfs/boot/vmlinuz-* build/ubuntu/iso/casper/vmlinuz
cp build/ubuntu/rootfs/boot/initrd.img-* build/ubuntu/iso/casper/initrd
```

**Creates SquashFS:**
```bash
mksquashfs build/ubuntu/rootfs build/ubuntu/iso/casper/filesystem.squashfs -comp xz
```

Compression:
- Algorithm: xz (high compression)
- Block size: 1MB
- Result: ~1-2GB compressed from ~4GB rootfs

### 10. GRUB Configuration

**Creates boot menu:**
```
menuentry "CyberXP-OS (Live)" {
    linux /casper/vmlinuz boot=casper quiet splash
    initrd /casper/initrd
}

menuentry "CyberXP-OS (Safe Graphics)" {
    linux /casper/vmlinuz boot=casper nomodeset quiet splash
    initrd /casper/initrd
}

menuentry "CyberXP-OS (Debug)" {
    linux /casper/vmlinuz boot=casper debug
    initrd /casper/initrd
}
```

Boot parameters:
- `boot=casper` - Live boot mode
- `quiet splash` - Minimal boot messages
- `nomodeset` - Disable graphics acceleration (compatibility)
- `debug` - Verbose boot messages

### 11. Generate ISO

**Tool: grub-mkrescue**

```bash
grub-mkrescue -o output.iso build/ubuntu/iso \
  --compress=xz \
  --fonts= \
  --locales= \
  --themes=
```

Options:
- `--compress=xz` - Compress ISO contents
- `--fonts=` - Exclude fonts (smaller ISO)
- `--locales=` - Exclude locales (smaller ISO)
- `--themes=` - Exclude themes (smaller ISO)

**Result:**
Hybrid bootable ISO supporting:
- BIOS (Legacy) boot
- UEFI boot
- USB boot (dd mode)

### 12. Cleanup

**Unmounts chroot filesystems:**
```bash
umount build/ubuntu/rootfs/dev/pts
umount build/ubuntu/rootfs/dev
umount build/ubuntu/rootfs/proc
umount build/ubuntu/rootfs/sys
```

**Cleans package cache:**
```bash
apt clean
apt autoremove
```

## Output

**ISO location:**
```
build/output/cyberxp-os-0.1.0-alpha-ubuntu.iso
```

**Size:** ~1.5-2GB

**Boot support:**
- BIOS (Legacy)
- UEFI
- USB (dd mode)

## Testing

**VirtualBox:**
```bash
VBoxManage createvm --name "CyberXP-Test" --register
VBoxManage modifyvm "CyberXP-Test" --memory 2048 --cpus 2
VBoxManage storagectl "CyberXP-Test" --name "SATA" --add sata
VBoxManage storageattach "CyberXP-Test" --storagectl "SATA" \
  --port 1 --type dvddrive --medium cyberxp-os-*.iso
VBoxManage startvm "CyberXP-Test"
```

**USB:**
```bash
# Linux
sudo dd if=cyberxp-os-*.iso of=/dev/sdX bs=4M status=progress

# Windows: Use Rufus in DD mode
# macOS: Use balenaEtcher
```

## Common Issues

### Debootstrap Fails

**Symptoms:**
```
ERROR: Debootstrap failed with all mirrors
```

**Check network:**
```bash
ping -c 3 archive.ubuntu.com
# Should get responses
```

**Check disk space:**
```bash
df -h
# Need at least 10GB free
```

**Try manual debootstrap:**
```bash
sudo debootstrap --arch=amd64 noble /tmp/test http://archive.ubuntu.com/ubuntu/
# See what error occurs
```

**Check logs:**
```bash
cat build/ubuntu/debootstrap.log
# Look for specific error messages
```

### Package Installation Fails

**Symptoms:**
```
ERROR: Failed to install essential packages
```

**Check chroot mounts:**
```bash
mount | grep build/ubuntu/rootfs
# Should show /dev, /proc, /sys mounted
```

**Test chroot manually:**
```bash
sudo chroot build/ubuntu/rootfs /bin/bash
apt update
# See what error occurs
exit
```

**Check DNS in chroot:**
```bash
cat build/ubuntu/rootfs/etc/resolv.conf
# Should have nameservers (8.8.8.8, etc.)
```

### Kernel Not Found

**Symptoms:**
```
ERROR: Kernel installation failed in chroot
No kernel found in /boot
```

**Check if kernel was installed:**
```bash
ls -la build/ubuntu/rootfs/boot/
# Should see vmlinuz-* and initrd.img-*
```

**Manually install kernel:**
```bash
sudo chroot build/ubuntu/rootfs /bin/bash
apt install -y linux-image-generic
ls /boot/vmlinuz-*
exit
```

**Check available space:**
```bash
df -h build/ubuntu/rootfs
# Kernel needs ~200MB
```

### ISO Won't Boot

**Symptoms:**
- ISO file exists
- VM shows "No bootable device"

**Verify ISO is bootable:**
```bash
file build/output/cyberxp-os-0.1.0-alpha-ubuntu.iso
# Should mention "bootable"
```

**Check GRUB files:**
```bash
xorriso -indev build/output/cyberxp-os-0.1.0-alpha-ubuntu.iso -find
# Should list /boot/grub/grub.cfg
```

**Try different boot mode:**
- In VirtualBox: Settings → System → Enable/Disable EFI

### Dashboard Not Accessible

**Symptoms:**
- System boots
- Can login
- Dashboard not accessible from host

**Check service status:**
```bash
sudo systemctl status cyberxp-dashboard
# Should show "active (running)"
```

**Check if port is listening:**
```bash
sudo netstat -tlnp | grep 8080
# Should show Python listening
```

**Check firewall:**
```bash
sudo ufw status
# If active, allow port 8080
sudo ufw allow 8080/tcp
```

**Check logs:**
```bash
sudo journalctl -u cyberxp-dashboard -n 50
# Look for errors
```

**Test locally first:**
```bash
curl http://localhost:8080
# Should return HTML
```

**Check VirtualBox port forwarding:**
```bash
VBoxManage showvminfo "CyberXP-Test" | grep "NIC 1 Rule"
# Should show port 8080 forwarding
```

### Large ISO Size

**Symptoms:**
- ISO larger than 3GB

**Remove unnecessary packages:**
Edit `install_base_packages()` to exclude:
- Documentation packages
- Language packs
- Development tools

**Use lighter compression:**
```bash
# In create_iso() function, change:
mksquashfs ... -comp gzip  # Instead of xz
```

**Exclude locales:**
```bash
# Before creating SquashFS:
rm -rf build/ubuntu/rootfs/usr/share/locale/*
rm -rf build/ubuntu/rootfs/usr/share/doc/*
```

## Build Time

**Typical duration:**
- Debootstrap: 5-10 minutes
- Package installation: 10-15 minutes
- SquashFS creation: 5-10 minutes
- ISO generation: 2-5 minutes

**Total: 30-45 minutes**

## Customization

**Add packages:**
Edit package list in `install_base_packages()` function.

**Change dashboard:**
Modify files in `config/desktop/cyberxp-dashboard/`.

**Adjust boot menu:**
Edit GRUB config in `create_iso()` function.

**Change credentials:**
Edit user creation in `configure_system()` function.
