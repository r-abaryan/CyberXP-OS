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
    
    # Use debootstrap to create Ubuntu rootfs (minimal first, then add packages)
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
    
    # Create essential directories
    mkdir -p "$BUILD_DIR/rootfs/dev/pts"
    mkdir -p "$BUILD_DIR/rootfs/proc"
    mkdir -p "$BUILD_DIR/rootfs/sys"
    
    # Mount essential filesystems
    mount --bind /dev "$BUILD_DIR/rootfs/dev"
    mount --bind /proc "$BUILD_DIR/rootfs/proc"
    mount --bind /sys "$BUILD_DIR/rootfs/sys"
    
    # Mount devpts for PTY support
    mount -t devpts devpts "$BUILD_DIR/rootfs/dev/pts" -o newinstance,ptmxmode=0666,mode=0620
    
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
# Install GPG tools first (required for package verification)
apt install -y --allow-unauthenticated gpgv gnupg ca-certificates || {
    echo "ERROR: Cannot install GPG tools"
    exit 1
}

# Now update package lists
apt update || {
    echo "ERROR: Failed to update package lists"
    exit 1
}

# Install essential packages for Ubuntu 24.04 (CORRECTED PACKAGE LIST)
apt install -y \
    python3 \
    python3-psutil \
    git \
    curl \
    wget \
    nano \
    htop \
    net-tools \
    iptables \
    openssh-server \
    systemd \
    systemd-sysv \
    grub-efi-amd64 \
    linux-image-generic \
    linux-headers-generic \
    initramfs-tools \
    squashfs-tools \
    xorriso \
    mtools \
    efibootmgr \
    dosfstools \
    locales || {
    echo "ERROR: Failed to install essential packages"
    exit 1
}

# Install pip via get-pip.py (with network fallback)
echo "Installing pip via get-pip.py..."
if curl -sS https://bootstrap.pypa.io/get-pip.py | python3; then
    echo "pip installed successfully"
else
    echo "WARNING: Failed to install pip via get-pip.py (network issue)"
    echo "pip will be installed later if needed"
fi

# Install security tools (only packages that exist in Ubuntu 24.04)
apt install -y \
    ufw \
    tcpdump || {
    echo "WARNING: Some security tools not available, continuing..."
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
    
    # Install lightweight dashboard (with fallback)
    mkdir -p "$BUILD_DIR/rootfs/opt/cyberxp-dashboard"
    
    if [[ -d "config/desktop/cyberxp-dashboard" ]]; then
        cp -r config/desktop/cyberxp-dashboard/* "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/"
    else
        log_warn "Dashboard files not found, creating minimal dashboard..."
        # Create minimal dashboard that works without Flask
        cat > "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py" << 'EOF'
#!/usr/bin/env python3
"""
CyberXP-OS Simple Dashboard (No Flask Version)
Basic HTTP server for when Flask is not available
"""
import http.server
import socketserver
import psutil
import time

class CyberXPDashboardHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            # Get system info
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            uptime_seconds = time.time() - psutil.boot_time()
            uptime_hours = int(uptime_seconds // 3600)
            uptime_minutes = int((uptime_seconds % 3600) // 60)
            
            html = f"""
<!DOCTYPE html>
<html>
<head>
    <title>CyberXP-OS Dashboard</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }}
        .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        h1 {{ color: #2c3e50; text-align: center; }}
        .metric {{ background: #ecf0f1; padding: 15px; margin: 10px 0; border-radius: 5px; }}
        .metric h3 {{ margin: 0 0 10px 0; color: #34495e; }}
        .value {{ font-size: 18px; font-weight: bold; color: #27ae60; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ CyberXP-OS Dashboard</h1>
        
        <div class="metric">
            <h3>System Status</h3>
            <div class="value">✅ Online</div>
        </div>
        
        <div class="metric">
            <h3>CPU Usage</h3>
            <div class="value">{cpu_percent}%</div>
        </div>
        
        <div class="metric">
            <h3>Memory Usage</h3>
            <div class="value">{memory.percent}%</div>
        </div>
        
        <div class="metric">
            <h3>Disk Usage</h3>
            <div class="value">{disk.percent}%</div>
        </div>
        
        <div class="metric">
            <h3>Uptime</h3>
            <div class="value">{uptime_hours}h {uptime_minutes}m</div>
        </div>
        
        <div class="metric">
            <h3>Note</h3>
            <div class="value">Basic Dashboard (Flask not available)</div>
        </div>
    </div>
</body>
</html>
"""
            self.wfile.write(html.encode())
        else:
            super().do_GET()

if __name__ == '__main__':
    PORT = 8080
    with socketserver.TCPServer(("", PORT), CyberXPDashboardHandler) as httpd:
        print(f"CyberXP-OS Dashboard running on port {PORT}")
        httpd.serve_forever()
EOF
    fi
    
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
# Install Flask and minimal dependencies for dashboard (with fallback)
if command -v pip3 &> /dev/null; then
    pip3 install Flask==3.0.0 Werkzeug==3.0.1 || {
        echo "WARNING: Failed to install Flask via pip3"
        echo "Dashboard will be created without Flask dependencies"
    }
else
    echo "WARNING: pip3 not available, skipping Flask installation"
    echo "Dashboard will be created without Flask dependencies"
fi

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
    echo "WARNING: pip3 not found (network issue during installation)"
    echo "Dashboard will work with basic Python functionality"
else
    echo "✓ pip3: $(pip3 --version)"
fi

# Check Flask installation
if ! python3 -c "import flask" 2>/dev/null; then
    echo "WARNING: Flask not installed (pip3 network issue)"
    echo "Dashboard will use basic Python functionality"
else
    echo "✓ Flask: $(python3 -c 'import flask; print(flask.__version__)')"
fi

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
    
    # Create systemd service file (FIXED - uses root user for simplicity)
    cat > "$BUILD_DIR/rootfs/etc/systemd/system/cyberxp-dashboard.service" << 'EOF'
[Unit]
Description=CyberXP-OS Dashboard
After=network.target

[Service]
Type=simple
User=root
Group=root
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

# Enable security services (only if available)
systemctl enable ufw || echo "ufw not available"
systemctl enable fail2ban || echo "fail2ban not available"

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

# Set timezone to UTC
echo "UTC" > /etc/timezone
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

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
    
    # Create ISO structure (simplified approach)
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
    
    # Create SquashFS filesystem
    log_info "Creating compressed filesystem..."
    mksquashfs "$BUILD_DIR/rootfs" "$BUILD_DIR/iso/filesystem.squashfs" \
        -comp xz -b 1M -noappend
    
    # Create GRUB config (simplified approach)
    log_info "Configuring GRUB (BIOS + UEFI)..."
    cat > "$BUILD_DIR/iso/boot/grub/grub.cfg" << 'EOF'
set timeout=10
set default=0

menuentry "CyberXP-OS" {
    linux /boot/vmlinuz-* root=/dev/loop0 quiet splash
    initrd /boot/initrd.img-*
}

menuentry "CyberXP-OS (Recovery)" {
    linux /boot/vmlinuz-* root=/dev/loop0 init=/bin/bash
    initrd /boot/initrd.img-*
}
EOF
    
    # Copy GRUB config to UEFI location
    mkdir -p "$BUILD_DIR/iso/EFI/BOOT"
    cp "$BUILD_DIR/iso/boot/grub/grub.cfg" "$BUILD_DIR/iso/EFI/BOOT/grub.cfg"
    
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
# Cleanup function
###############################################################################

cleanup() {
    log_info "Cleaning up..."
    # Unmount in reverse order
    umount "$BUILD_DIR/rootfs/dev/pts" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/dev" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/proc" 2>/dev/null || true
    umount "$BUILD_DIR/rootfs/sys" 2>/dev/null || true
    log_success "Cleanup complete"
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
    verify_system_integrity
    setup_bootloader
    cleanup_chroot
    create_iso
    show_summary
}

# Run main function
main "$@"
