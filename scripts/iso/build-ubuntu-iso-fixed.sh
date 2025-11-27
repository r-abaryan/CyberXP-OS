#!/bin/bash
###############################################################################
# CyberXP-OS Ubuntu Server ISO Builder - FIXED VERSION
# Creates bootable ISO with CyberXP AI security agent pre-installed
# 
# FIXES APPLIED:
# - Better debootstrap error handling with mirror fallback
# - Fixed kernel verification (proper wildcard handling)
# - Removed broken GRUB device installation
# - Improved DNS configuration in chroot
# - Better error messages and logging
# - Proper service configuration for systemd
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UBUNTU_VERSION="24.04"
UBUNTU_CODENAME="noble"
BUILD_DIR="$(pwd)/build/ubuntu"
OUTPUT_DIR="$(pwd)/build/output"
CYBERXP_CORE="../CyberXP"

# ISO Details
ISO_NAME="cyberxp-os"
ISO_VERSION="0.1.0-alpha"
ISO_LABEL="CyberXP-OS"

###############################################################################
# Helper Functions
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking build requirements..."
    
    # Check if running on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script must be run on Linux"
        exit 1
    fi
    
    # Check for required tools
    local required_tools=("wget" "tar" "gzip" "xorriso" "mksquashfs" "grub-mkrescue" "mount" "umount" "debootstrap" "chroot")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            log_info "Install with: sudo apt install wget tar gzip xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin util-linux debootstrap"
            exit 1
        fi
    done
    
    # Check for root (needed for chroot)
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (for chroot)"
        log_info "Run with: sudo ./scripts/build-ubuntu-iso-fixed.sh"
        exit 1
    fi
    
    # Check disk space (need at least 10GB to be safe)
    local available_space=$(df "$BUILD_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
    if [[ $available_space -lt 10485760 ]]; then  # 10GB in KB
        log_error "Insufficient disk space: $(df -h "$BUILD_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "unknown")"
        log_error "Need at least 10GB free space"
        exit 1
    fi
    
    # Check network connectivity
    if ! ping -c 1 -W 3 archive.ubuntu.com &> /dev/null; then
        log_warn "Cannot reach archive.ubuntu.com - will try alternative mirrors"
    fi
    
    log_success "All requirements met"
}

create_build_dirs() {
    log_info "Creating build directories..."
    mkdir -p "$BUILD_DIR"/{rootfs,iso,temp}
    mkdir -p "$OUTPUT_DIR"
    log_success "Build directories created"
}

download_ubuntu() {
    log_info "Creating Ubuntu rootfs with debootstrap..."
    
    # Clean any previous failed attempts
    if [[ -d "$BUILD_DIR/rootfs" ]]; then
        log_info "Cleaning previous build..."
        umount "$BUILD_DIR/rootfs/dev/pts" 2>/dev/null || true
        umount "$BUILD_DIR/rootfs/dev" 2>/dev/null || true
        umount "$BUILD_DIR/rootfs/proc" 2>/dev/null || true
        umount "$BUILD_DIR/rootfs/sys" 2>/dev/null || true
        rm -rf "$BUILD_DIR/rootfs"
    fi
    mkdir -p "$BUILD_DIR/rootfs"
    
    # Try multiple mirrors for reliability
    local mirrors=(
        "http://archive.ubuntu.com/ubuntu/"
        "http://us.archive.ubuntu.com/ubuntu/"
        "http://mirror.math.princeton.edu/pub/ubuntu/"
        "http://mirrors.kernel.org/ubuntu/"
    )
    
    local success=false
    for mirror in "${mirrors[@]}"; do
        log_info "Trying mirror: $mirror"
        
        if timeout 600 debootstrap \
            --arch=amd64 \
            --include=systemd,systemd-sysv,dbus \
            --verbose \
            "$UBUNTU_CODENAME" \
            "$BUILD_DIR/rootfs" \
            "$mirror" 2>&1 | tee "$BUILD_DIR/debootstrap.log"; then
            
            log_success "Debootstrap completed successfully with mirror: $mirror"
            success=true
            break
        else
            log_warn "Debootstrap failed with mirror: $mirror"
            log_warn "See $BUILD_DIR/debootstrap.log for details"
            rm -rf "$BUILD_DIR/rootfs"
            mkdir -p "$BUILD_DIR/rootfs"
        fi
    done
    
    if [[ "$success" != "true" ]]; then
        log_error "Debootstrap failed with all mirrors"
        log_error "Check network connectivity and disk space"
        log_error "See $BUILD_DIR/debootstrap.log for details"
        exit 1
    fi
    
    # Verify rootfs was created properly
    if [[ ! -d "$BUILD_DIR/rootfs/bin" ]] || [[ ! -d "$BUILD_DIR/rootfs/usr" ]]; then
        log_error "Debootstrap created incomplete rootfs"
        log_error "Expected directories missing (bin, usr)"
        exit 1
    fi
    
    log_success "Ubuntu rootfs created successfully"
}

setup_chroot() {
    log_info "Setting up chroot environment..."
    
    # Create essential directories
    mkdir -p "$BUILD_DIR/rootfs/dev/pts"
    mkdir -p "$BUILD_DIR/rootfs/proc"
    mkdir -p "$BUILD_DIR/rootfs/sys"
    mkdir -p "$BUILD_DIR/rootfs/run"
    
    # Mount essential filesystems
    mount --bind /dev "$BUILD_DIR/rootfs/dev"
    mount --bind /proc "$BUILD_DIR/rootfs/proc"
    mount --bind /sys "$BUILD_DIR/rootfs/sys"
    mount -t devpts devpts "$BUILD_DIR/rootfs/dev/pts" -o newinstance,ptmxmode=0666,mode=0620
    
    # Configure DNS with fallback
    if [[ -f /etc/resolv.conf ]]; then
        cp /etc/resolv.conf "$BUILD_DIR/rootfs/etc/resolv.conf"
    else
        cat > "$BUILD_DIR/rootfs/etc/resolv.conf" <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF
    fi
    
    # Set up APT sources
    cat > "$BUILD_DIR/rootfs/etc/apt/sources.list" <<EOF
deb http://archive.ubuntu.com/ubuntu/ $UBUNTU_CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $UBUNTU_CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
    
    log_success "Chroot environment ready"
}

install_base_packages() {
    log_info "Installing base packages (this may take 10-15 minutes)..."
    
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'CHROOT_EOF'
set -e

# Update package lists
echo "Updating package lists..."
apt update || {
    echo "ERROR: Failed to update package lists"
    exit 1
}

# Install essential packages
echo "Installing essential packages..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    nano \
    vim \
    htop \
    net-tools \
    iproute2 \
    iputils-ping \
    iptables \
    openssh-server \
    systemd \
    systemd-sysv \
    dbus \
    linux-image-generic \
    linux-headers-generic \
    initramfs-tools \
    grub-pc-bin \
    grub-efi-amd64-bin \
    grub-efi-amd64-signed \
    shim-signed \
    locales \
    ca-certificates \
    gnupg || {
    echo "ERROR: Failed to install essential packages"
    exit 1
}

# Install Python packages
echo "Installing Python packages..."
pip3 install --break-system-packages --ignore-installed \
    Flask==3.0.0 \
    Werkzeug==3.0.1 \
    psutil==5.9.0 || {
    echo "WARNING: Failed to install some Python packages"
}

# Install security tools (optional)
echo "Installing security tools..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    ufw \
    tcpdump \
    nmap \
    netcat-openbsd || {
    echo "WARNING: Some security tools not available"
}

# Generate locales
echo "Generating locales..."
locale-gen en_US.UTF-8

# Clean package cache
echo "Cleaning package cache..."
apt clean
apt autoremove -y

echo "✓ Base packages installed successfully"
CHROOT_EOF

    if [[ $? -ne 0 ]]; then
        log_error "Package installation failed in chroot"
        exit 1
    fi
    
    log_success "Base packages installed"
}

install_cyberxp() {
    log_info "Installing CyberXP-OS Dashboard..."
    
    # Create dashboard directory
    mkdir -p "$BUILD_DIR/rootfs/opt/cyberxp-dashboard"
    
    # Copy dashboard files if they exist
    if [[ -d "config/desktop/cyberxp-dashboard" ]]; then
        log_info "Copying dashboard files from config/"
        cp -r config/desktop/cyberxp-dashboard/* "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/"
    else
        log_warn "Dashboard files not found in config/, creating minimal dashboard..."
        
        # Create minimal dashboard
        cat > "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py" <<'PYEOF'
#!/usr/bin/env python3
"""
CyberXP-OS Dashboard
Minimal Flask-based security monitoring dashboard
"""

from flask import Flask, jsonify
import subprocess
import os
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def index():
    """Main dashboard page"""
    return '''
<!DOCTYPE html>
<html>
<head>
    <title>CyberXP-OS Dashboard</title>
    <meta http-equiv="refresh" content="30">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            max-width: 1000px;
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-align: center;
        }
        .subtitle {
            text-align: center;
            font-size: 1.2em;
            opacity: 0.9;
            margin-bottom: 40px;
        }
        .status {
            background: rgba(255, 255, 255, 0.2);
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        .status h2 {
            font-size: 1.5em;
            margin-bottom: 15px;
        }
        .metric {
            background: rgba(0, 0, 0, 0.3);
            padding: 15px;
            border-radius: 8px;
            margin: 10px 0;
        }
        .value {
            font-size: 1.2em;
            font-weight: bold;
            color: #4ade80;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ CyberXP-OS</h1>
        <div class="subtitle">AI-Powered Security Analysis Platform</div>
        
        <div class="status">
            <h2>System Status</h2>
            <div class="metric">
                <div>Status: <span class="value">✅ Online</span></div>
            </div>
            <div class="metric">
                <div>Dashboard: <span class="value">✅ Running</span></div>
            </div>
            <div class="metric">
                <div>Version: <span class="value">0.1.0-alpha</span></div>
            </div>
        </div>
        
        <div class="status">
            <h2>Quick Links</h2>
            <div class="metric">
                <a href="/api/status" style="color: #4ade80;">API Status</a>
            </div>
            <div class="metric">
                <a href="/healthz" style="color: #4ade80;">Health Check</a>
            </div>
        </div>
        
        <div class="footer">
            <p>Page auto-refreshes every 30 seconds</p>
            <p style="margin-top: 10px;">
                <a href="https://github.com/r-abaryan/CyberXP-OS" target="_blank" style="color: #4ade80;">
                    GitHub: github.com/r-abaryan/CyberXP-OS
                </a>
            </p>
        </div>
    </div>
</body>
</html>
'''

@app.route('/api/status')
def api_status():
    """Get system status"""
    try:
        # Get system info
        with open('/proc/loadavg', 'r') as f:
            loadavg = f.read().split()[:3]
        
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.read().split()[0])
            uptime = f"{int(uptime_seconds // 3600)}h {int((uptime_seconds % 3600) // 60)}m"
        
        return jsonify({
            'status': 'online',
            'timestamp': datetime.now().isoformat(),
            'loadavg': loadavg,
            'uptime': uptime
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/healthz')
def healthz():
    """Health check endpoint"""
    return 'ok', 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', '8080'))
    app.run(host='0.0.0.0', port=port, debug=False)
PYEOF
        
        chmod +x "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py"
    fi
    
    # Verify installation
    if [[ ! -f "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py" ]]; then
        log_error "Dashboard installation failed - app.py not found"
        exit 1
    fi
    
    log_success "CyberXP-OS Dashboard installed to /opt/cyberxp-dashboard"
}

create_systemd_services() {
    log_info "Creating systemd services..."
    
    # Create systemd service file
    cat > "$BUILD_DIR/rootfs/etc/systemd/system/cyberxp-dashboard.service" <<'EOF'
[Unit]
Description=CyberXP-OS Security Dashboard
Documentation=https://github.com/r-abaryan/CyberXP-OS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/cyberxp-dashboard
ExecStart=/usr/bin/python3 /opt/cyberxp-dashboard/app.py
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1
Environment=PORT=8080

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cyberxp-dashboard

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable services in chroot
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'CHROOT_EOF'
# Enable SSH
systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || echo "SSH service not found"

# Enable CyberXP Dashboard
if [ -f /etc/systemd/system/cyberxp-dashboard.service ]; then
    systemctl enable cyberxp-dashboard
    echo "✓ CyberXP Dashboard enabled for auto-start"
else
    echo "⚠ Warning: CyberXP Dashboard service not found"
fi

# Enable networking
systemctl enable systemd-networkd
systemctl enable systemd-resolved

echo "✓ Systemd services configured"
CHROOT_EOF
    
    log_success "Systemd services created and enabled"
}

configure_system() {
    log_info "Configuring system..."
    
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'CHROOT_EOF'
# Set hostname
echo "cyberxp-os" > /etc/hostname

# Configure hosts file
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
127.0.1.1   cyberxp-os

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HOSTS

# Configure root password
echo "root:cyberxp" | chpasswd

# Create cyberxp user
useradd -m -s /bin/bash -G sudo cyberxp 2>/dev/null || true
echo "cyberxp:cyberxp" | chpasswd

# Set timezone to UTC
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Configure SSH
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
fi

# Configure network (netplan)
mkdir -p /etc/netplan
cat > /etc/netplan/01-netcfg.yaml <<NETPLAN
network:
  version: 2
  ethernets:
    all:
      match:
        name: "en*"
      dhcp4: true
      dhcp6: false
NETPLAN

# Create MOTD
cat > /etc/motd <<'MOTD'
╔═══════════════════════════════════════════════════════════╗
║          CyberXP-OS v0.1.0-alpha                         ║
║      AI-Powered Security Analysis Platform               ║
╚═══════════════════════════════════════════════════════════╝

Login Credentials:
  Username: cyberxp
  Password: cyberxp
  
  Root access: sudo su (or login as root/cyberxp)

Dashboard:
  Access at: http://<this-ip>:8080
  
  To find your IP: ip addr show

Quick Commands:
  • Check dashboard: sudo systemctl status cyberxp-dashboard
  • View logs: sudo journalctl -u cyberxp-dashboard -f
  • Restart dashboard: sudo systemctl restart cyberxp-dashboard

GitHub: https://github.com/r-abaryan/CyberXP-OS
MOTD

echo "✓ System configured"
CHROOT_EOF
    
    log_success "System configuration complete"
}

setup_bootloader() {
    log_info "Setting up bootloader..."
    
    # Update initramfs and GRUB config in chroot
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'CHROOT_EOF'
# Update initramfs
echo "Updating initramfs..."
update-initramfs -u -k all

# Update GRUB configuration (but don't install to device)
echo "Updating GRUB configuration..."
update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg

echo "✓ Bootloader configured"
echo "Kernel files:"
ls -lh /boot/vmlinuz-* 2>/dev/null || echo "  No kernel found!"
ls -lh /boot/initrd.img-* 2>/dev/null || echo "  No initramfs found!"
CHROOT_EOF
    
    # Verify kernel files exist (FIXED - proper wildcard handling)
    if ! ls "$BUILD_DIR/rootfs/boot/vmlinuz-"* >/dev/null 2>&1; then
        log_error "Kernel installation failed in chroot"
        log_error "No kernel found in /boot"
        exit 1
    fi
    
    if ! ls "$BUILD_DIR/rootfs/boot/initrd.img-"* >/dev/null 2>&1; then
        log_error "Initramfs creation failed in chroot"
        log_error "No initramfs found in /boot"
        exit 1
    fi
    
    log_success "Bootloader configured (kernel and initramfs verified)"
}

cleanup_chroot() {
    log_info "Cleaning up chroot..."
    
    # Clean package cache
    chroot "$BUILD_DIR/rootfs" /bin/bash -c "apt clean && apt autoremove -y" 2>/dev/null || true
    
    # Remove temporary files
    rm -f "$BUILD_DIR/rootfs/etc/resolv.conf.bak"
    rm -rf "$BUILD_DIR/rootfs/tmp/"*
    rm -rf "$BUILD_DIR/rootfs/var/tmp/"*
    
    # Unmount filesystems
    umount "$BUILD_DIR/rootfs/dev/pts" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/dev" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/proc" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/sys" 2>/dev/null || true
    
    log_success "Chroot cleaned up"
}

create_iso() {
    log_info "Creating bootable ISO (BIOS + UEFI)..."
    
    # Create ISO structure
    mkdir -p "$BUILD_DIR/iso/boot/grub"
    mkdir -p "$BUILD_DIR/iso/EFI/BOOT"
    mkdir -p "$BUILD_DIR/iso/casper"
    
    # Copy kernel and initramfs from rootfs
    log_info "Copying kernel and initramfs..."
    if ls "$BUILD_DIR/rootfs/boot/vmlinuz-"* >/dev/null 2>&1; then
        cp "$BUILD_DIR/rootfs/boot/vmlinuz-"* "$BUILD_DIR/iso/casper/vmlinuz"
        cp "$BUILD_DIR/rootfs/boot/initrd.img-"* "$BUILD_DIR/iso/casper/initrd"
        log_success "Kernel and initramfs copied"
    else
        log_error "Kernel not found! Cannot create bootable ISO"
        exit 1
    fi
    
    # Create SquashFS filesystem
    log_info "Creating compressed filesystem (this may take 5-10 minutes)..."
    mksquashfs "$BUILD_DIR/rootfs" "$BUILD_DIR/iso/casper/filesystem.squashfs" \
        -comp xz -b 1M -noappend -no-progress
    
    # Calculate filesystem size
    printf $(du -sx --block-size=1 "$BUILD_DIR/rootfs" | cut -f1) > "$BUILD_DIR/iso/casper/filesystem.size"
    
    # Create GRUB config
    log_info "Configuring GRUB (BIOS + UEFI)..."
    cat > "$BUILD_DIR/iso/boot/grub/grub.cfg" <<'EOF'
set timeout=10
set default=0

menuentry "CyberXP-OS (Live)" {
    linux /casper/vmlinuz boot=casper quiet splash ---
    initrd /casper/initrd
}

menuentry "CyberXP-OS (Live - Safe Graphics)" {
    linux /casper/vmlinuz boot=casper nomodeset quiet splash ---
    initrd /casper/initrd
}

menuentry "CyberXP-OS (Live - Debug Mode)" {
    linux /casper/vmlinuz boot=casper debug ---
    initrd /casper/initrd
}
EOF
    
    # Create ISO with GRUB bootloader (hybrid BIOS/UEFI)
    local iso_file="$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso"
    
    log_info "Generating hybrid bootable ISO (BIOS + UEFI)..."
    
    # Use grub-mkrescue for hybrid boot
    if grub-mkrescue -o "$iso_file" "$BUILD_DIR/iso" \
        --compress=xz \
        --fonts= \
        --locales= \
        --themes= 2>&1 | grep -v "WARNING"; then
        
        log_success "Hybrid bootable ISO created: $iso_file"
        log_info "Size: $(du -h "$iso_file" | cut -f1)"
        log_info "Boot support: BIOS (Legacy) + UEFI"
    else
        log_error "ISO creation failed"
        exit 1
    fi
}

show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🎉 CyberXP-OS Ubuntu ISO Build Complete!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Output:"
    echo "    ISO: $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso"
    echo "    Size: $(du -h "$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso" 2>/dev/null | cut -f1 || echo "Unknown")"
    echo ""
    echo "  Boot Support:"
    echo "    ✓ BIOS (Legacy)"
    echo "    ✓ UEFI"
    echo "    ✓ Hybrid ISO (works on both)"
    echo ""
    echo "  Login Credentials:"
    echo "    Username: cyberxp"
    echo "    Password: cyberxp"
    echo "    Root: root / cyberxp"
    echo ""
    echo "  Dashboard Access:"
    echo "    URL: http://<vm-ip>:8080"
    echo "    Find IP: ip addr show"
    echo ""
    echo "  Next Steps:"
    echo "    1. Test in VM:"
    echo "       VBoxManage createvm --name \"CyberXP-Test\" --register"
    echo "       VBoxManage modifyvm \"CyberXP-Test\" --memory 2048 --cpus 2"
    echo "       VBoxManage createhd --filename \"CyberXP-Test.vdi\" --size 20000"
    echo "       VBoxManage storagectl \"CyberXP-Test\" --name \"SATA\" --add sata"
    echo "       VBoxManage storageattach \"CyberXP-Test\" --storagectl \"SATA\" --port 0 --type hdd --medium \"CyberXP-Test.vdi\""
    echo "       VBoxManage storageattach \"CyberXP-Test\" --storagectl \"SATA\" --port 1 --type dvddrive --medium \"$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso\""
    echo "       VBoxManage startvm \"CyberXP-Test\""
    echo ""
    echo "    2. Or burn to USB:"
    echo "       Linux:   sudo dd if=$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso of=/dev/sdX bs=4M status=progress"
    echo "       Windows: Use Rufus in DD mode"
    echo "       macOS:   Use balenaEtcher"
    echo ""
    echo "  Documentation:"
    echo "    Quick Start: docs/QUICKSTART.md"
    echo "    User Guide:  docs/USER_GUIDE.md"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

###############################################################################
# Cleanup function
###############################################################################

cleanup() {
    log_info "Cleaning up mounts..."
    # Unmount in reverse order
    umount "$BUILD_DIR/rootfs/dev/pts" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/dev" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/proc" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/sys" 2>/dev/null || true
}

###############################################################################
# Main Build Process
###############################################################################

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CyberXP-OS Ubuntu Server ISO Builder - FIXED VERSION"
    echo "  Version: $ISO_VERSION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_requirements
    
    # Set up cleanup trap
    trap cleanup EXIT INT TERM
    
    create_build_dirs
    download_ubuntu
    setup_chroot
    install_base_packages
    install_cyberxp
    create_systemd_services
    configure_system
    setup_bootloader
    cleanup_chroot
    create_iso
    show_summary
}

# Run main function
main "$@"
