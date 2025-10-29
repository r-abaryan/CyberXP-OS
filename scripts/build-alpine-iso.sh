#!/bin/bash
###############################################################################
# CyberXP-OS Alpine Linux ISO Builder (FIXED v4 - Network & Boot Fix)
# Creates bootable ISO with proper network and bootloader setup
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ALPINE_VERSION="3.18.4"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
BUILD_DIR="$(pwd)/build/alpine"
OUTPUT_DIR="$(pwd)/build/output"
CYBERXP_CORE="../CyberXP"

# ISO Details
ISO_NAME="cyberxp-os"
ISO_VERSION="0.1.0-alpha"
ISO_LABEL="CYBERXP_OS"  # No dashes - ISO 9660 compliance

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
    
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This script must be run on Linux"
        exit 1
    fi
    
    local required_tools=("wget" "tar" "gzip" "xorriso" "mksquashfs")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            log_info "Install with: sudo apt install wget tar gzip xorriso squashfs-tools syslinux isolinux"
            exit 1
        fi
    done
    
    # Check for SYSLINUX files
    if [[ ! -f "/usr/lib/ISOLINUX/isolinux.bin" ]] && [[ ! -f "/usr/lib/syslinux/modules/bios/isolinux.bin" ]]; then
        log_error "SYSLINUX not found"
        log_info "Install with: sudo apt install syslinux isolinux"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (for chroot)"
        log_info "Run with: sudo ./scripts/build-alpine-iso.sh"
        exit 1
    fi
    
    # Test network connectivity
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "No internet connection detected"
        log_info "Please check your network connection"
        exit 1
    fi
    
    log_success "All requirements met"
}

create_build_dirs() {
    log_info "Creating build directories..."
    rm -rf "$BUILD_DIR/iso" "$BUILD_DIR/temp"
    mkdir -p "$BUILD_DIR"/{rootfs,iso,temp}
    mkdir -p "$OUTPUT_DIR"
    log_success "Build directories created"
}

download_alpine() {
    log_info "Downloading Alpine Linux $ALPINE_VERSION..."
    
    local alpine_rootfs="alpine-minirootfs-${ALPINE_VERSION}-x86_64.tar.gz"
    local download_url="${ALPINE_MIRROR}/v${ALPINE_VERSION%.*}/releases/x86_64/${alpine_rootfs}"
    
    if [[ ! -f "$BUILD_DIR/$alpine_rootfs" ]]; then
        wget -O "$BUILD_DIR/$alpine_rootfs" "$download_url"
        log_success "Alpine rootfs downloaded"
    else
        log_info "Alpine rootfs already downloaded (using cache)"
    fi
    
    log_info "Extracting Alpine rootfs..."
    rm -rf "$BUILD_DIR/rootfs"/*
    tar -xzf "$BUILD_DIR/$alpine_rootfs" -C "$BUILD_DIR/rootfs"
    log_success "Alpine rootfs extracted"
}

setup_chroot() {
    log_info "Setting up chroot environment..."
    
    # Unmount if already mounted
    umount "$BUILD_DIR/rootfs/dev" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/proc" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/sys" 2>/dev/null || true
    
    # Mount essential filesystems
    mount --bind /dev "$BUILD_DIR/rootfs/dev"
    mount --bind /proc "$BUILD_DIR/rootfs/proc"
    mount --bind /sys "$BUILD_DIR/rootfs/sys"
    
    # CRITICAL: Copy DNS config for network access
    cp -L /etc/resolv.conf "$BUILD_DIR/rootfs/etc/resolv.conf"
    
    # Ensure DNS is working
    if ! chroot "$BUILD_DIR/rootfs" /bin/sh -c "ping -c 1 dl-cdn.alpinelinux.org" &> /dev/null; then
        log_warn "DNS not working in chroot, using Google DNS"
        echo "nameserver 8.8.8.8" > "$BUILD_DIR/rootfs/etc/resolv.conf"
        echo "nameserver 8.8.4.4" >> "$BUILD_DIR/rootfs/etc/resolv.conf"
    fi
    
    log_success "Chroot environment ready"
}

install_base_packages() {
    log_info "Installing base packages..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
set -e

# Configure Alpine repositories
cat > /etc/apk/repositories <<'REPOS_EOF'
http://dl-cdn.alpinelinux.org/alpine/v3.18/main
http://dl-cdn.alpinelinux.org/alpine/v3.18/community
REPOS_EOF

# Test network connectivity
echo "Testing network connectivity..."
if ! ping -c 1 dl-cdn.alpinelinux.org; then
    echo "ERROR: Cannot reach Alpine mirrors!"
    exit 1
fi

# Update package index with retry
echo "Updating package index..."
apk update || (sleep 5 && apk update) || (sleep 10 && apk update)

# Install base packages
echo "Installing Alpine base system..."
apk add --no-cache \
    alpine-base \
    alpine-conf \
    openrc \
    busybox \
    busybox-openrc \
    busybox-mdev-openrc \
    busybox-extras-openrc

# Install essential tools
echo "Installing essential packages..."
apk add --no-cache \
    bash \
    sudo \
    python3 \
    py3-pip \
    git \
    curl \
    wget \
    nano \
    htop \
    net-tools \
    iproute2 \
    iptables \
    openssh

# Install utilities
echo "Installing utilities..."
apk add --no-cache \
    util-linux \
    coreutils \
    nmap \
    tcpdump

echo "✓ Base packages installed successfully"
CHROOT_EOF

    log_success "Base packages installed"
}

install_cyberxp() {
    log_info "Installing CyberXP-OS Dashboard..."
    
    mkdir -p "$BUILD_DIR/rootfs/opt/cyberxp-dashboard"
    
    # Create minimal dashboard
    cat > "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py" <<'PYEOF'
from flask import Flask, render_template_string
app = Flask(__name__)

HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>CyberXP-OS Dashboard</title>
    <style>
        body { font-family: Arial; background: #1a1a1a; color: #0f0; padding: 20px; }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { border-bottom: 2px solid #0f0; padding-bottom: 10px; }
        .status { background: #2a2a2a; padding: 15px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ CyberXP-OS Dashboard</h1>
        <div class="status">
            <h2>System Status: RUNNING</h2>
            <p>Mode: Live (Diskless)</p>
            <p>Version: 0.1.0-alpha</p>
        </div>
        <div class="status">
            <h3>Quick Start:</h3>
            <ul>
                <li>Network setup: <code>setup-interfaces</code></li>
                <li>Install to disk: <code>setup-alpine</code></li>
                <li>Package manager: <code>apk add &lt;package&gt;</code></li>
            </ul>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def home():
    return render_template_string(HTML)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
PYEOF
    
    # Copy CyberXP core if available
    if [[ -d "$CYBERXP_CORE" ]]; then
        log_info "Installing CyberXP core..."
        mkdir -p "$BUILD_DIR/rootfs/opt/cyberxp"
        cp -r "$CYBERXP_CORE"/* "$BUILD_DIR/rootfs/opt/cyberxp/" 2>/dev/null || true
    fi
    
    # Install Python dependencies
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
pip3 install --break-system-packages --no-cache-dir Flask 2>/dev/null || \
pip3 install --no-cache-dir Flask

if [ -f /opt/cyberxp/requirements.txt ]; then
    pip3 install --break-system-packages --no-cache-dir -r /opt/cyberxp/requirements.txt 2>/dev/null || \
    pip3 install --no-cache-dir -r /opt/cyberxp/requirements.txt || true
fi

echo "✓ Dashboard installed"
CHROOT_EOF

    log_success "CyberXP-OS Dashboard installed"
}

configure_system() {
    log_info "Configuring system..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
# Hostname
echo "cyberxp-os" > /etc/hostname

# Passwords
echo "root:cyberxp" | chpasswd
adduser -D -s /bin/bash cyberxp 2>/dev/null || true
echo "cyberxp:cyberxp" | chpasswd

# Sudo
mkdir -p /etc/sudoers.d
echo "cyberxp ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/cyberxp

# MOTD
cat > /etc/motd <<'MOTD_EOF'

═══════════════════════════════════════════════════════════
    CyberXP-OS v0.1.0-alpha - Live System
    AI-Powered Security Analysis Platform
═══════════════════════════════════════════════════════════

Login: root / cyberxp (password: cyberxp)

Quick Start:
  • Dashboard:  python3 /opt/cyberxp-dashboard/app.py &
  • Network:    setup-interfaces
  • Install:    setup-alpine

GitHub: https://github.com/r-abaryan/CyberXP-OS

MOTD_EOF

# OpenRC services
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add hwclock boot
rc-update add modules boot
rc-update add sysctl boot
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add syslog boot 2>/dev/null || rc-update add busybox-syslog default

echo "✓ System configured"
CHROOT_EOF

    log_success "System configured"
}

setup_bootloader() {
    log_info "Installing kernel and bootloader..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
apk add --no-cache linux-lts linux-firmware mkinitfs

# Generate initramfs
KVER=$(ls /lib/modules/ | head -1)
if [ -n "$KVER" ]; then
    mkinitfs -o /boot/initramfs-lts $KVER
    echo "✓ Initramfs generated for $KVER"
fi
CHROOT_EOF
    
    log_success "Kernel installed"
}

cleanup_chroot() {
    log_info "Cleaning up chroot..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh -c "rm -rf /var/cache/apk/* /tmp/*" || true
    
    umount "$BUILD_DIR/rootfs/dev" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/proc" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/sys" 2>/dev/null || true
    
    log_success "Chroot cleaned"
}

create_iso() {
    log_info "Creating bootable ISO..."
    
    # Create ISO structure
    mkdir -p "$BUILD_DIR/iso/boot/isolinux"
    
    # Copy kernel and initramfs
    log_info "Copying kernel..."
    cp "$BUILD_DIR/rootfs/boot/vmlinuz-lts" "$BUILD_DIR/iso/boot/vmlinuz"
    cp "$BUILD_DIR/rootfs/boot/initramfs-lts" "$BUILD_DIR/iso/boot/initramfs"
    
    # Create SquashFS
    log_info "Creating compressed filesystem (this may take a few minutes)..."
    mksquashfs "$BUILD_DIR/rootfs" "$BUILD_DIR/iso/boot/rootfs.squashfs" \
        -comp xz -b 1M -noappend -e boot
    
    # Copy SYSLINUX files
    log_info "Setting up SYSLINUX bootloader..."
    
    # Find and copy isolinux.bin
    if [[ -f "/usr/lib/ISOLINUX/isolinux.bin" ]]; then
        cp /usr/lib/ISOLINUX/isolinux.bin "$BUILD_DIR/iso/boot/isolinux/"
    elif [[ -f "/usr/lib/syslinux/modules/bios/isolinux.bin" ]]; then
        cp /usr/lib/syslinux/modules/bios/isolinux.bin "$BUILD_DIR/iso/boot/isolinux/"
    else
        cp /usr/share/syslinux/isolinux.bin "$BUILD_DIR/iso/boot/isolinux/"
    fi
    
    # Copy .c32 modules
    if [[ -d "/usr/lib/syslinux/modules/bios" ]]; then
        cp /usr/lib/syslinux/modules/bios/*.c32 "$BUILD_DIR/iso/boot/isolinux/" 2>/dev/null || true
    else
        cp /usr/share/syslinux/*.c32 "$BUILD_DIR/iso/boot/isolinux/" 2>/dev/null || true
    fi
    
    # Create SYSLINUX config
    cat > "$BUILD_DIR/iso/boot/isolinux/isolinux.cfg" <<'SYSLINUXCFG'
DEFAULT cyberxp
PROMPT 0
TIMEOUT 50
UI menu.c32

MENU TITLE CyberXP-OS Boot Menu

LABEL cyberxp
    MENU LABEL CyberXP-OS Live
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs modules=loop,squashfs,sd-mod,usb-storage nomodeset console=tty1

LABEL verbose
    MENU LABEL CyberXP-OS (Verbose)
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs modules=loop,squashfs,sd-mod,usb-storage nomodeset console=tty0 loglevel=7

LABEL recovery
    MENU LABEL Recovery Shell
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs init=/bin/sh
SYSLINUXCFG
    
    # Build ISO
    local iso_file="$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    
    log_info "Building ISO..."
    
    # Check if isohdpfx.bin exists
    local mbr_file=""
    if [[ -f "/usr/lib/ISOLINUX/isohdpfx.bin" ]]; then
        mbr_file="/usr/lib/ISOLINUX/isohdpfx.bin"
    elif [[ -f "/usr/lib/syslinux/mbr/isohdpfx.bin" ]]; then
        mbr_file="/usr/lib/syslinux/mbr/isohdpfx.bin"
    fi
    
    if [[ -n "$mbr_file" ]]; then
        xorriso -as mkisofs \
            -o "$iso_file" \
            -b boot/isolinux/isolinux.bin \
            -c boot/isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -isohybrid-mbr "$mbr_file" \
            -V "$ISO_LABEL" \
            "$BUILD_DIR/iso" 2>&1 | grep -v "WARNING" || true
    else
        # Fallback without hybrid MBR
        xorriso -as mkisofs \
            -o "$iso_file" \
            -b boot/isolinux/isolinux.bin \
            -c boot/isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -V "$ISO_LABEL" \
            "$BUILD_DIR/iso" 2>&1 | grep -v "WARNING" || true
    fi
    
    if [[ -f "$iso_file" ]]; then
        log_success "✓ ISO created: $iso_file"
        log_info "Size: $(du -h "$iso_file" | cut -f1)"
    else
        log_error "ISO creation failed - check xorriso output above"
        exit 1
    fi
}

show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🎉 CyberXP-OS Build Complete!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Output: $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo "  Size:   $(du -h "$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso" | cut -f1)"
    echo ""
    echo "  Test with QEMU:"
    echo "    qemu-system-x86_64 -m 2048 \\"
    echo "      -cdrom $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo ""
    echo "  Test with VirtualBox:"
    echo "    VBoxManage createvm --name CyberXP --register --ostype Linux_64"
    echo "    VBoxManage modifyvm CyberXP --memory 2048"
    echo "    VBoxManage storagectl CyberXP --name SATA --add sata"
    echo "    VBoxManage storageattach CyberXP --storagectl SATA \\"
    echo "      --port 0 --device 0 --type dvddrive \\"
    echo "      --medium $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo "    VBoxManage startvm CyberXP"
    echo ""
    echo "  Login: root / cyberxp (password: cyberxp)"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

###############################################################################
# Main
###############################################################################

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CyberXP-OS Builder v$ISO_VERSION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_requirements
    create_build_dirs
    download_alpine
    setup_chroot
    install_base_packages
    install_cyberxp
    configure_system
    setup_bootloader
    cleanup_chroot
    create_iso
    show_summary
}

main "$@"
