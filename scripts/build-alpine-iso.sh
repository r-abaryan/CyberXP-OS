#!/bin/bash
###############################################################################
# CyberXP-OS Alpine Linux ISO Builder
# Creates bootable ISO with CyberXP AI security agent pre-installed
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
    local required_tools=("wget" "tar" "gzip" "xorriso" "mksquashfs")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            log_info "Install with: sudo apt install wget tar gzip xorriso squashfs-tools"
            exit 1
        fi
    done
    
    # Check for root (needed for chroot)
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
    
    # Extract rootfs
    log_info "Extracting Alpine rootfs..."
    tar -xzf "$BUILD_DIR/$alpine_rootfs" -C "$BUILD_DIR/rootfs"
    log_success "Alpine rootfs extracted"
}

setup_chroot() {
    log_info "Setting up chroot environment..."
    
    # Mount essential filesystems
    mount --bind /dev "$BUILD_DIR/rootfs/dev"
    mount --bind /proc "$BUILD_DIR/rootfs/proc"
    mount --bind /sys "$BUILD_DIR/rootfs/sys"
    
    # Copy DNS config
    cp /etc/resolv.conf "$BUILD_DIR/rootfs/etc/"
    
    log_success "Chroot environment ready"
}

install_base_packages() {
    log_info "Installing base packages..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
# Setup Alpine package manager
echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/main" > /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories

# Update package index
apk update

# Install essential packages
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

# Install system services
apk add --no-cache \
    openrc \
    util-linux \
    coreutils

# Install security tools (lightweight)
apk add --no-cache \
    suricata \
    fail2ban \
    nmap \
    tcpdump

echo "Base packages installed"
CHROOT_EOF

    log_success "Base packages installed"
}

install_cyberxp() {
    log_info "Installing CyberXP-OS Dashboard..."
    
    # Install lightweight Flask dashboard
    mkdir -p "$BUILD_DIR/rootfs/opt/cyberxp-dashboard"
    cp -r config/desktop/cyberxp-dashboard/* "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/"
    
    # Optionally copy CyberXP core for backend analysis (if available)
    if [[ -d "$CYBERXP_CORE" ]]; then
        log_info "Installing CyberXP core for backend analysis..."
        mkdir -p "$BUILD_DIR/rootfs/opt/cyberxp"
        cp -r "$CYBERXP_CORE"/* "$BUILD_DIR/rootfs/opt/cyberxp/"
    else
        log_warn "CyberXP core not found at $CYBERXP_CORE (optional - dashboard will work without it)"
    fi
    
    # Install Python dependencies
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
# Install Flask and minimal dependencies for dashboard
pip3 install --no-cache-dir Flask==3.0.0 Werkzeug==3.0.1

# Install CyberXP core dependencies if available
if [ -f /opt/cyberxp/requirements.txt ]; then
    pip3 install --no-cache-dir -r /opt/cyberxp/requirements.txt || true
fi

echo "Dashboard and dependencies installed"
CHROOT_EOF

    log_success "CyberXP-OS Dashboard installed to /opt/cyberxp-dashboard"
}

create_openrc_services() {
    log_info "Creating OpenRC services..."
    
    # Copy OpenRC init scripts from config
    cp config/services/cyberxp-agent "$BUILD_DIR/rootfs/etc/init.d/" 2>/dev/null || true
    chmod +x "$BUILD_DIR/rootfs/etc/init.d/cyberxp-agent" 2>/dev/null || true
    
    # Enable services in chroot
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
# Enable OpenRC boot services
rc-update add devfs boot
rc-update add dmesg boot
rc-update add mdev boot
rc-update add hwclock boot
rc-update add modules boot

# Enable networking services
rc-update add hostname boot
rc-update add networking boot
rc-update add sshd default

# Enable CyberXP Dashboard
if [ -f /etc/init.d/cyberxp-agent ]; then
    chmod +x /etc/init.d/cyberxp-agent
    rc-update add cyberxp-agent default
    echo "✓ CyberXP Dashboard enabled for auto-start"
else
    echo "⚠ Warning: CyberXP Dashboard init script not found"
fi

# Enable security services
rc-update add iptables default 2>/dev/null || true
rc-update add fail2ban default 2>/dev/null || true

echo "OpenRC services configured"
CHROOT_EOF

    log_success "OpenRC services created and enabled"
}

configure_system() {
    log_info "Configuring system..."
    
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
# Set hostname
echo "cyberxp-os" > /etc/hostname

# Configure root password (change in production!)
echo "root:cyberxp" | chpasswd

# Create cyberxp user
adduser -D -s /bin/bash cyberxp
echo "cyberxp:cyberxp" | chpasswd
adduser cyberxp wheel

# Configure sudo
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Set timezone to UTC
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

echo "System configured"
CHROOT_EOF

    log_success "System configuration complete"
}

cleanup_chroot() {
    log_info "Cleaning up chroot..."
    
    # Clean package cache
    chroot "$BUILD_DIR/rootfs" /bin/sh -c "rm -rf /var/cache/apk/*"
    
    # Unmount filesystems
    umount "$BUILD_DIR/rootfs/dev" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/proc" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/sys" 2>/dev/null || true
    
    log_success "Chroot cleaned up"
}

create_iso() {
    log_info "Creating bootable ISO..."
    
    # Create ISO structure
    mkdir -p "$BUILD_DIR/iso/boot/grub"
    
    # Copy kernel and initramfs
    cp "$BUILD_DIR/rootfs/boot/vmlinuz-lts" "$BUILD_DIR/iso/boot/" 2>/dev/null || \
        log_warn "Kernel not found (will add bootloader setup later)"
    
    # Create GRUB config
    cat > "$BUILD_DIR/iso/boot/grub/grub.cfg" <<'GRUB_EOF'
set default=0
set timeout=5

menuentry "CyberXP-OS Live" {
    linux /boot/vmlinuz-lts quiet splash
    initrd /boot/initramfs-lts
}

menuentry "CyberXP-OS Safe Mode" {
    linux /boot/vmlinuz-lts single
    initrd /boot/initramfs-lts
}
GRUB_EOF

    # Create SquashFS filesystem
    log_info "Creating compressed filesystem..."
    mksquashfs "$BUILD_DIR/rootfs" "$BUILD_DIR/iso/cyberxp-os.squashfs" \
        -comp xz -b 1M -noappend
    
    # Generate ISO
    local iso_file="$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    
    log_info "Generating ISO image..."
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "$ISO_LABEL" \
        -output "$iso_file" \
        -eltorito-boot boot/grub/grub.cfg \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        "$BUILD_DIR/iso" 2>/dev/null || log_warn "ISO creation incomplete (bootloader setup needed)"
    
    if [[ -f "$iso_file" ]]; then
        log_success "ISO created: $iso_file"
        log_info "Size: $(du -h "$iso_file" | cut -f1)"
    else
        log_warn "ISO file not created (Phase 1: filesystem only)"
        log_info "SquashFS filesystem created at: $BUILD_DIR/iso/cyberxp-os.squashfs"
    fi
}

show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CyberXP-OS Build Complete!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Output:"
    echo "    ISO: $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo "    Filesystem: $BUILD_DIR/iso/cyberxp-os.squashfs"
    echo ""
    echo "  Next Steps:"
    echo "    1. Test in VM: ./scripts/test-vm.sh"
    echo "    2. Burn to USB: sudo dd if=<iso> of=/dev/sdX bs=4M"
    echo "    3. Boot and login with: cyberxp / cyberxp"
    echo ""
    echo "  Note: This is Phase 1 (MVP)"
    echo "    - Bootloader setup incomplete"
    echo "    - GUI not yet implemented"
    echo "    - Use for testing only"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

###############################################################################
# Main Build Process
###############################################################################

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CyberXP-OS Alpine Linux ISO Builder"
    echo "  Version: $ISO_VERSION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_requirements
    create_build_dirs
    download_alpine
    setup_chroot
    install_base_packages
    install_cyberxp
    create_openrc_services
    configure_system
    cleanup_chroot
    create_iso
    show_summary
}

# Run main function
main "$@"

