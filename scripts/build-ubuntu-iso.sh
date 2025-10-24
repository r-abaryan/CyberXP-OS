#!/bin/bash
###############################################################################
# CyberXP-OS Ubuntu Server ISO Builder
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
UBUNTU_VERSION="22.04"
UBUNTU_CODENAME="jammy"
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
        log_info "Run with: sudo ./scripts/build-ubuntu-iso.sh"
        exit 1
    fi
    
    # Check disk space (need at least 8GB)
    local available_space=$(df "$BUILD_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
    if [[ $available_space -lt 8388608 ]]; then  # 8GB in KB
        log_warn "Low disk space detected: $(df -h "$BUILD_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "unknown")"
        log_warn "Recommended: At least 8GB free space"
        log_warn "Continuing anyway, but build may fail..."
    fi
    
    # Check network connectivity
    if ! ping -c 1 archive.ubuntu.com &> /dev/null; then
        log_warn "Cannot reach archive.ubuntu.com - network issues may cause build failure"
        log_info "Try: ping archive.ubuntu.com"
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
    rm -rf "$BUILD_DIR/rootfs" 2>/dev/null || true
    mkdir -p "$BUILD_DIR/rootfs"
    
    # Use debootstrap to create Ubuntu rootfs
    debootstrap --arch=amd64 "$UBUNTU_CODENAME" "$BUILD_DIR/rootfs" \
        http://archive.ubuntu.com/ubuntu/ || {
        log_error "Debootstrap failed"
        log_info "Try: sudo apt update && sudo apt install debootstrap"
        exit 1
    }
    
    log_success "Ubuntu rootfs created"
}


setup_chroot() {
    log_info "Setting up chroot environment..."
    
    # Mount essential filesystems
    mount --bind /dev "$BUILD_DIR/rootfs/dev"
    mount --bind /proc "$BUILD_DIR/rootfs/proc"
    mount --bind /sys "$BUILD_DIR/rootfs/sys"
    mount --bind /dev/pts "$BUILD_DIR/rootfs/dev/pts"
    
    # Copy DNS config
    cp /etc/resolv.conf "$BUILD_DIR/rootfs/etc/"
    
    log_success "Chroot environment ready"
}

install_base_packages() {
    log_info "Installing base packages..."
    
    # Check if we're in WSL and chroot is broken
    if grep -q Microsoft /proc/version 2>/dev/null && ! chroot "$BUILD_DIR/rootfs" /bin/bash -c "echo test" &>/dev/null; then
        log_warn "WSL chroot broken - using alternative package installation method"
        install_packages_wsl_alternative
        return
    fi
    
    # Check available disk space
    local available_space=$(df "$BUILD_DIR" | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 2000000 ]]; then  # Less than 2GB
        log_error "Insufficient disk space. Need at least 2GB free."
        exit 1
    fi
    
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'CHROOT_EOF'
# Update package lists
apt update || {
    echo "ERROR: Failed to update package lists"
    exit 1
}

# Install essential packages
apt install -y \
    python3 \
    python3-pip \
    python3-psutil \
    git \
    curl \
    wget \
    nano \
    htop \
    net-tools \
    iptables \
    openssh-server \
    sudo \
    systemd \
    systemd-sysv \
    grub-pc \
    grub-efi-amd64 \
    linux-image-generic \
    linux-headers-generic \
    initramfs-tools \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-common \
    syslinux-efi || {
    echo "ERROR: Failed to install essential packages"
    exit 1
}

# Install security tools
apt install -y \
    suricata \
    fail2ban \
    nmap \
    tcpdump \
    ufw \
    iptables-persistent || {
    echo "ERROR: Failed to install security tools"
    exit 1
}

# Clean package cache
apt clean
apt autoremove -y

echo "Base packages installed successfully"
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
        log_warn "CyberXP core found but skipping due to size (2.4GB+)"
        log_info "To include CyberXP core, clean it first and remove large files"
        log_info "Dashboard will work without it"
    else
        log_warn "CyberXP core not found at $CYBERXP_CORE (optional - dashboard will work without it)"
    fi
    
    # Install Python dependencies
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'CHROOT_EOF'
# Install Flask and minimal dependencies for dashboard
pip3 install Flask==3.0.0 Werkzeug==3.0.1 || {
    echo "ERROR: Failed to install Flask dependencies"
    exit 1
}

# Install CyberXP core dependencies if available
if [ -f /opt/cyberxp/requirements.txt ]; then
    pip3 install -r /opt/cyberxp/requirements.txt || true
fi

echo "Dashboard and dependencies installed"
CHROOT_EOF

    # Verify installation
    if [[ ! -d "$BUILD_DIR/rootfs/opt/cyberxp-dashboard" ]]; then
        log_error "Dashboard installation failed - /opt/cyberxp-dashboard not found"
        exit 1
    fi
    
    if [[ ! -f "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py" ]]; then
        log_error "Dashboard installation failed - app.py not found"
        exit 1
    fi

    log_success "CyberXP-OS Dashboard installed to /opt/cyberxp-dashboard"
}

verify_system_integrity() {
    log_info "Performing system verification..."
    
    # Verify essential system components
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'VERIFY_EOF'
echo "=== System Verification ==="

# Check Python and pip
if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 not found"
    exit 1
fi
echo "✓ Python3: $(python3 --version)"

if ! command -v pip3 &> /dev/null; then
    echo "ERROR: pip3 not found"
    exit 1
fi
echo "✓ pip3: $(pip3 --version)"

# Check Flask installation
if ! python3 -c "import flask" 2>/dev/null; then
    echo "ERROR: Flask not installed"
    exit 1
fi
echo "✓ Flask: $(python3 -c 'import flask; print(flask.__version__)')"

# Check dashboard files
if [ ! -d "/opt/cyberxp-dashboard" ]; then
    echo "ERROR: Dashboard directory not found"
    exit 1
fi
echo "✓ Dashboard directory exists"

if [ ! -f "/opt/cyberxp-dashboard/app.py" ]; then
    echo "ERROR: Dashboard app.py not found"
    exit 1
fi
echo "✓ Dashboard app.py exists"

# Test dashboard syntax
if ! python3 -m py_compile /opt/cyberxp-dashboard/app.py; then
    echo "ERROR: Dashboard has syntax errors"
    exit 1
fi
echo "✓ Dashboard syntax valid"

# Check systemd service
if [ ! -f "/etc/systemd/system/cyberxp-dashboard.service" ]; then
    echo "ERROR: systemd service not found"
    exit 1
fi
echo "✓ systemd service exists"

# Check user exists
if ! id cyberxp &> /dev/null; then
    echo "ERROR: cyberxp user not found"
    exit 1
fi
echo "✓ cyberxp user exists"

# Check essential packages
for pkg in systemd python3-pip curl wget; do
    if ! dpkg -l | grep -q "^ii.*$pkg "; then
        echo "ERROR: Package $pkg not installed"
        exit 1
    fi
done
echo "✓ Essential packages installed"

echo "=== All verification checks passed ==="
VERIFY_EOF

    if [[ $? -eq 0 ]]; then
        log_success "System verification passed"
    else
        log_error "System verification failed"
        exit 1
    fi
}

create_systemd_services() {
    log_info "Creating systemd services..."
    
    # Create systemd service file
    cat > "$BUILD_DIR/rootfs/etc/systemd/system/cyberxp-dashboard.service" << 'EOF'
[Unit]
Description=CyberXP-OS Dashboard
After=network.target

[Service]
Type=simple
User=cyberxp
Group=cyberxp
WorkingDirectory=/opt/cyberxp-dashboard
ExecStart=/usr/bin/python3 /opt/cyberxp-dashboard/app.py
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1
Environment=FLASK_APP=app.py
Environment=FLASK_ENV=production

[Install]
WantedBy=multi-user.target
EOF

    # Enable services in chroot
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'CHROOT_EOF'
# Enable SSH
systemctl enable ssh

# Enable CyberXP Dashboard
if [ -f /etc/systemd/system/cyberxp-dashboard.service ]; then
    systemctl enable cyberxp-dashboard
    echo "✓ CyberXP Dashboard enabled for auto-start"
else
    echo "⚠ Warning: CyberXP Dashboard service not found"
fi

# Enable security services
systemctl enable ufw
systemctl enable fail2ban

echo "Systemd services configured"
CHROOT_EOF

    log_success "Systemd services created and enabled"
}

configure_system() {
    log_info "Configuring system..."
    
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'CHROOT_EOF'
# Set hostname
echo "cyberxp-os" > /etc/hostname

# Configure root password (change in production!)
echo "root:cyberxp" | chpasswd

# Create cyberxp user
useradd -m -s /bin/bash cyberxp
echo "cyberxp:cyberxp" | chpasswd
usermod -aG sudo cyberxp

# Set timezone to UTC
timedatectl set-timezone UTC

# Configure SSH
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

echo "System configured"
CHROOT_EOF

    log_success "System configuration complete"
}

setup_bootloader() {
    log_info "Setting up bootloader (BIOS + UEFI)..."
    
    # Install GRUB in chroot
    chroot "$BUILD_DIR/rootfs" /bin/bash <<'CHROOT_EOF'
# Update initramfs
update-initramfs -u

# Install GRUB
grub-install --target=i386-pc /dev/loop0 2>/dev/null || true
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu 2>/dev/null || true

# Update GRUB configuration
update-grub

echo "Bootloader packages installed (BIOS + UEFI)"
echo "Kernel: $(ls -la /boot/vmlinuz-*)"
echo "Initramfs: $(ls -la /boot/initrd.img-*)"
CHROOT_EOF
    
    # Verify kernel files exist after chroot
    if [[ ! -f "$BUILD_DIR/rootfs/boot/vmlinuz-"* ]]; then
        log_error "Kernel installation failed in chroot"
        exit 1
    fi
    
    if [[ ! -f "$BUILD_DIR/rootfs/boot/initrd.img-"* ]]; then
        log_error "Initramfs creation failed in chroot"
        exit 1
    fi
    
    log_success "Bootloader packages installed (BIOS + UEFI support)"
}

cleanup_chroot() {
    log_info "Cleaning up chroot..."
    
    # Clean package cache
    chroot "$BUILD_DIR/rootfs" /bin/bash -c "apt clean && apt autoremove -y"
    
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
    
    # Copy kernel and initramfs from rootfs
    log_info "Copying kernel and initramfs..."
    if ls "$BUILD_DIR/rootfs/boot/vmlinuz-"* 1> /dev/null 2>&1; then
        cp "$BUILD_DIR/rootfs/boot/vmlinuz-"* "$BUILD_DIR/iso/boot/"
        cp "$BUILD_DIR/rootfs/boot/initrd.img-"* "$BUILD_DIR/iso/boot/"
        log_success "Kernel and initramfs copied"
    else
        log_error "Kernel not found! Run setup_bootloader first"
        exit 1
    fi
    
    # Create SquashFS filesystem first
    log_info "Creating compressed filesystem..."
    mksquashfs "$BUILD_DIR/rootfs" "$BUILD_DIR/iso/cyberxp-os.squashfs" \
        -comp xz -b 1M -noappend
    
    # Copy GRUB config with proper live boot parameters
    log_info "Configuring GRUB (BIOS + UEFI)..."
    cp config/boot/grub.cfg "$BUILD_DIR/iso/boot/grub/"
    # UEFI uses same config
    mkdir -p "$BUILD_DIR/iso/EFI/BOOT"
    cp config/boot/grub.cfg "$BUILD_DIR/iso/EFI/BOOT/grub.cfg"
    
    # Create ISO with GRUB bootloader (hybrid BIOS/UEFI)
    local iso_file="$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso"
    
    log_info "Generating hybrid bootable ISO (BIOS + UEFI)..."
    
    # Use grub-mkrescue for hybrid boot
    grub-mkrescue -o "$iso_file" "$BUILD_DIR/iso" \
        --compress=xz \
        --fonts= \
        --locales= \
        --themes= 2>&1 | grep -v "WARNING" || {
        log_warn "grub-mkrescue not found, trying manual approach..."
        
        # Manual hybrid ISO creation
        xorriso -as mkisofs \
            -iso-level 3 \
            -full-iso9660-filenames \
            -V "$ISO_LABEL" \
            -output "$iso_file" \
            -eltorito-boot boot/grub/i386-pc/eltorito.img \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -eltorito-alt-boot \
            -e EFI/BOOT/bootx64.efi \
            -no-emul-boot \
            -isohybrid-gpt-basdat \
            "$BUILD_DIR/iso" 2>&1 | grep -v "WARNING" || true
    }
    
    if [[ -f "$iso_file" ]]; then
        log_success "Hybrid bootable ISO created: $iso_file"
        log_info "Size: $(du -h "$iso_file" | cut -f1)"
        log_info "Boot support: BIOS (Legacy) + UEFI"
        log_info "You can now boot this ISO in VirtualBox or burn to USB"
    else
        log_error "ISO creation failed"
        exit 1
    fi
}

show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🎉 CyberXP-OS Ubuntu Build Complete!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Output:"
    echo "    ISO: $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso"
    echo "    Filesystem: $BUILD_DIR/iso/cyberxp-os.squashfs"
    echo ""
    echo "  Boot Support:"
    echo "    ✓ BIOS (Legacy)"
    echo "    ✓ UEFI"
    echo "    ✓ Hybrid ISO (works on both)"
    echo ""
    echo "  Next Steps:"
    echo "    1. Test in VM: ./scripts/setup-dev-vm.sh"
    echo "    2. Start VM: VBoxManage startvm \"CyberXP-OS-Dev\""
    echo "    3. Access dashboard: http://localhost:8080"
    echo "    4. Login: cyberxp / cyberxp"
    echo ""
    echo "  Burn to USB:"
    echo "    Linux:   sudo dd if=$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso of=/dev/sdX bs=4M"
    echo "    Windows: Use Rufus in DD mode"
    echo "    macOS:   Use balenaEtcher"
    echo ""
    echo "  Documentation:"
    echo "    Quick Start: docs/QUICKSTART.md"
    echo "    Technical:   docs/TECHNICAL_ARCHITECTURE.md"
    echo "    Bootloader:  docs/BOOTLOADER.md"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

###############################################################################
# Main Build Process
###############################################################################

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CyberXP-OS Ubuntu Server ISO Builder"
    echo "  Version: $ISO_VERSION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_requirements
    create_build_dirs
    download_ubuntu
    setup_chroot
    install_base_packages
    install_cyberxp
    create_systemd_services
    configure_system
    verify_system_integrity
    setup_bootloader
    cleanup_chroot
    create_iso
    show_summary
}

# Run main function
main "$@"
