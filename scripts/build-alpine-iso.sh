#!/bin/bash
###############################################################################
# CyberXP-OS Alpine Linux ISO Builder (FIXED v3 - Black Screen Fix)
# Creates bootable ISO with proper video and console support
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
ISO_LABEL="CYBERXP-OS"

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
    
    local required_tools=("wget" "tar" "gzip" "xorriso" "mksquashfs" "syslinux")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            log_info "Install with: sudo apt install wget tar gzip xorriso squashfs-tools syslinux isolinux"
            exit 1
        fi
    done
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (for chroot)"
        log_info "Run with: sudo ./scripts/build-alpine-iso.sh"
        exit 1
    fi
    
    log_success "All requirements met"
}

create_build_dirs() {
    log_info "Creating build directories..."
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
    
    mount --bind /dev "$BUILD_DIR/rootfs/dev" 2>/dev/null || true
    mount --bind /proc "$BUILD_DIR/rootfs/proc" 2>/dev/null || true
    mount --bind /sys "$BUILD_DIR/rootfs/sys" 2>/dev/null || true
    
    cp /etc/resolv.conf "$BUILD_DIR/rootfs/etc/"
    
    log_success "Chroot environment ready"
}

install_base_packages() {
    log_info "Installing base packages..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/main" > /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories

apk update

# CRITICAL: Install these first for proper boot
apk add --no-cache \
    alpine-base \
    alpine-conf \
    openrc \
    busybox \
    busybox-initscripts

# Essential system packages
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
    openssh \
    doas

# Utilities
apk add --no-cache \
    util-linux \
    coreutils \
    nmap \
    tcpdump

echo "Base packages installed"
CHROOT_EOF

    log_success "Base packages installed"
}

install_cyberxp() {
    log_info "Installing CyberXP-OS Dashboard..."
    
    mkdir -p "$BUILD_DIR/rootfs/opt/cyberxp-dashboard"
    
    if [[ ! -d "config/desktop/cyberxp-dashboard" ]]; then
        log_warn "Dashboard config not found, creating minimal version..."
        cat > "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py" <<'PYEOF'
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return '<h1>CyberXP-OS Dashboard</h1><p>System running in live mode</p>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
PYEOF
    else
        cp -r config/desktop/cyberxp-dashboard/* "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/"
    fi
    
    if [[ -d "$CYBERXP_CORE" ]]; then
        log_info "Installing CyberXP core..."
        mkdir -p "$BUILD_DIR/rootfs/opt/cyberxp"
        cp -r "$CYBERXP_CORE"/* "$BUILD_DIR/rootfs/opt/cyberxp/"
    fi
    
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
pip3 install --break-system-packages --no-cache-dir Flask==3.0.0 Werkzeug==3.0.1 2>/dev/null || \
pip3 install --no-cache-dir Flask==3.0.0 Werkzeug==3.0.1

if [ -f /opt/cyberxp/requirements.txt ]; then
    pip3 install --break-system-packages --no-cache-dir -r /opt/cyberxp/requirements.txt 2>/dev/null || \
    pip3 install --no-cache-dir -r /opt/cyberxp/requirements.txt || true
fi
CHROOT_EOF

    log_success "CyberXP-OS Dashboard installed"
}

configure_system() {
    log_info "Configuring system for live mode..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
# Set hostname
echo "cyberxp-os" > /etc/hostname

# Configure root password
echo "root:cyberxp" | chpasswd

# Create cyberxp user
adduser -D -s /bin/bash cyberxp || true
echo "cyberxp:cyberxp" | chpasswd
adduser cyberxp wheel || true

# Configure sudo
mkdir -p /etc/sudoers.d
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Set timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Create welcome message
cat > /etc/motd <<'MOTD_EOF'

╔══════════════════════════════════════════════════════════════╗
║                    CyberXP-OS Live System                    ║
║                  AI-Powered Security Analysis                ║
╚══════════════════════════════════════════════════════════════╝

Welcome to CyberXP-OS v0.1.0-alpha (Live Mode)

Login: root / cyberxp (password: cyberxp)

Quick Start:
  • Start dashboard: python3 /opt/cyberxp-dashboard/app.py &
  • Network setup:   setup-interfaces
  • Install system:  setup-alpine

Docs: https://github.com/r-abaryan/CyberXP-OS

MOTD_EOF

# Configure OpenRC runlevels (minimal for live boot)
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add hwclock boot
rc-update add modules boot
rc-update add sysctl boot
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add syslog boot 2>/dev/null || rc-update add busybox-syslog boot

echo "System configured for live mode"
CHROOT_EOF

    log_success "System configuration complete"
}

cleanup_chroot() {
    log_info "Cleaning up chroot..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh -c "rm -rf /var/cache/apk/*" || true
    
    umount "$BUILD_DIR/rootfs/dev" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/proc" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/sys" 2>/dev/null || true
    
    log_success "Chroot cleaned up"
}

setup_bootloader() {
    log_info "Setting up bootloader packages..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
apk add --no-cache \
    linux-lts \
    linux-firmware \
    mkinitfs

# Generate initramfs with essential modules
KVER=$(ls /lib/modules/ | head -1)
if [ -n "$KVER" ]; then
    # Add essential features to initramfs
    cat >> /etc/mkinitfs/mkinitfs.conf <<'INITFS_EOF'
features="ata base ide scsi usb virtio"
INITFS_EOF
    mkinitfs -o /boot/initramfs-lts $KVER
    echo "Initramfs generated for kernel $KVER"
fi
CHROOT_EOF
    
    log_success "Bootloader packages installed"
}

create_iso() {
    log_info "Creating bootable live ISO with SYSLINUX..."
    
    # Create ISO structure
    mkdir -p "$BUILD_DIR/iso/boot"
    mkdir -p "$BUILD_DIR/iso/boot/isolinux"
    
    # Copy kernel and initramfs
    log_info "Copying kernel and initramfs..."
    if [[ -f "$BUILD_DIR/rootfs/boot/vmlinuz-lts" ]]; then
        cp "$BUILD_DIR/rootfs/boot/vmlinuz-lts" "$BUILD_DIR/iso/boot/"
        cp "$BUILD_DIR/rootfs/boot/initramfs-lts" "$BUILD_DIR/iso/boot/"
        log_success "Kernel and initramfs copied"
    else
        log_error "Kernel not found!"
        exit 1
    fi
    
    # Create SquashFS root filesystem
    log_info "Creating compressed root filesystem (this may take a while)..."
    mksquashfs "$BUILD_DIR/rootfs" "$BUILD_DIR/iso/boot/rootfs.squashfs" \
        -comp xz -b 1M -noappend -e boot
    
    # Copy SYSLINUX bootloader files
    log_info "Setting up SYSLINUX bootloader..."
    cp /usr/lib/ISOLINUX/isolinux.bin "$BUILD_DIR/iso/boot/isolinux/" 2>/dev/null || \
    cp /usr/lib/syslinux/modules/bios/isolinux.bin "$BUILD_DIR/iso/boot/isolinux/" 2>/dev/null || \
    cp /usr/share/syslinux/isolinux.bin "$BUILD_DIR/iso/boot/isolinux/"
    
    cp /usr/lib/syslinux/modules/bios/*.c32 "$BUILD_DIR/iso/boot/isolinux/" 2>/dev/null || \
    cp /usr/share/syslinux/*.c32 "$BUILD_DIR/iso/boot/isolinux/"
    
    # CRITICAL: Create SYSLINUX config with proper boot parameters
    log_info "Configuring SYSLINUX with safe video parameters..."
cat > "$BUILD_DIR/iso/boot/isolinux/isolinux.cfg" <<'SYSLINUXCFG'
DEFAULT cyberxp
PROMPT 1
TIMEOUT 50
UI menu.c32

MENU TITLE CyberXP-OS Boot Menu
MENU COLOR border 30;44 #40ffffff #a0000000 std
MENU COLOR title  1;36;44 #9033ccff #a0000000 std
MENU COLOR sel    7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel  37;44 #50ffffff #a0000000 std

LABEL cyberxp
    MENU LABEL CyberXP-OS Live (Safe Mode)
    KERNEL /boot/vmlinuz-lts
    APPEND initrd=/boot/initramfs-lts modules=loop,squashfs,sd-mod,usb-storage nomodeset console=tty0 console=ttyS0,115200
    TEXT HELP
    Boot CyberXP-OS in safe graphics mode (recommended for VMs)
    ENDTEXT

LABEL verbose
    MENU LABEL CyberXP-OS Live (Verbose)
    KERNEL /boot/vmlinuz-lts
    APPEND initrd=/boot/initramfs-lts modules=loop,squashfs,sd-mod,usb-storage nomodeset console=tty0 loglevel=7
    TEXT HELP
    Boot with detailed kernel messages for troubleshooting
    ENDTEXT

LABEL vesa
    MENU LABEL CyberXP-OS Live (VESA Graphics)
    KERNEL /boot/vmlinuz-lts
    APPEND initrd=/boot/initramfs-lts modules=loop,squashfs,sd-mod,usb-storage vga=791 nomodeset
    TEXT HELP
    Boot with VESA framebuffer (1024x768)
    ENDTEXT

LABEL recovery
    MENU LABEL Recovery Shell
    KERNEL /boot/vmlinuz-lts
    APPEND initrd=/boot/initramfs-lts modules=loop,squashfs,sd-mod,usb-storage init=/bin/sh
    TEXT HELP
    Boot directly to emergency shell
    ENDTEXT
SYSLINUXCFG
    
    # Build the ISO with xorriso
    local iso_file="$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    
    log_info "Building bootable ISO with ISOLINUX..."
    xorriso -as mkisofs \
        -o "$iso_file" \
        -b boot/isolinux/isolinux.bin \
        -c boot/isolinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/isolinux/efiboot.img \
        -no-emul-boot \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -isohybrid-gpt-basdat \
        -V "$ISO_LABEL" \
        "$BUILD_DIR/iso" 2>&1 | grep -v "WARNING: -isohybrid-mbr" | grep -v "efiboot.img" || true
    
    if [[ -f "$iso_file" ]]; then
        log_success "✓ Bootable ISO created: $iso_file"
        log_info "Size: $(du -h "$iso_file" | cut -f1)"
        
        # Make ISO hybrid for USB boot
        if command -v isohybrid &> /dev/null; then
            isohybrid "$iso_file" 2>/dev/null || true
            log_success "ISO made hybrid (USB bootable)"
        fi
    else
        log_error "ISO creation failed"
        exit 1
    fi
}

show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🎉 CyberXP-OS Live ISO Build Complete!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Output:"
    echo "    ISO: $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo "    Root: $BUILD_DIR/iso/boot/rootfs.squashfs"
    echo ""
    echo "  ✓ BLACK SCREEN FIX APPLIED:"
    echo "    • nomodeset parameter added (disables graphics mode setting)"
    echo "    • SYSLINUX bootloader (more compatible than GRUB)"
    echo "    • Safe graphics mode by default"
    echo "    • Multiple boot options for troubleshooting"
    echo ""
    echo "  Testing in QEMU:"
    echo "    qemu-system-x86_64 -m 2048 -cdrom \\"
    echo "      $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo ""
    echo "  Testing in VirtualBox:"
    echo "    VBoxManage createvm --name CyberXP-Test --register --ostype Linux_64"
    echo "    VBoxManage modifyvm CyberXP-Test --memory 2048 --vram 16"
    echo "    VBoxManage modifyvm CyberXP-Test --graphicscontroller vmsvga"
    echo "    VBoxManage storagectl CyberXP-Test --name IDE --add ide"
    echo "    VBoxManage storageattach CyberXP-Test --storagectl IDE \\"
    echo "      --port 0 --device 0 --type dvddrive \\"
    echo "      --medium $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo "    VBoxManage startvm CyberXP-Test"
    echo ""
    echo "  Boot Menu Options:"
    echo "    1. CyberXP-OS Live (Safe Mode) - DEFAULT"
    echo "    2. CyberXP-OS Live (Verbose) - Shows detailed boot messages"
    echo "    3. CyberXP-OS Live (VESA Graphics) - For stubborn hardware"
    echo "    4. Recovery Shell - Emergency access"
    echo ""
    echo "  Login:"
    echo "    Username: root"
    echo "    Password: cyberxp"
    echo ""
    echo "  After successful boot:"
    echo "    • Check network: ip addr"
    echo "    • Start dashboard: python3 /opt/cyberxp-dashboard/app.py &"
    echo "    • Install to disk: setup-alpine"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

###############################################################################
# Main Build Process
###############################################################################

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CyberXP-OS Alpine Linux Live ISO Builder"
    echo "  Version: $ISO_VERSION (Black Screen Fixed)"
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