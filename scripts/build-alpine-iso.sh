#!/bin/bash
###############################################################################
# CyberXP-OS Alpine Linux ISO Builder
# Creates bootable ISO with CyberXP AI security agent pre-installed
# Improved version with better error handling and network resilience
###############################################################################

set -e  # Exit on error for critical failures
set -o pipefail  # Fail on piped commands

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
    local required_tools=("wget" "tar" "gzip" "xorriso" "mksquashfs" "grub-mkrescue" "mount" "umount")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            log_info "Install with: sudo apt install wget tar gzip xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin util-linux"
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
# Setup Alpine package manager with multiple mirrors
echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/main" > /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/v3.18/community" >> /etc/apk/repositories
echo "http://mirror.math.princeton.edu/pub/alpinelinux/v3.18/main" >> /etc/apk/repositories
echo "http://mirror.math.princeton.edu/pub/alpinelinux/v3.18/community" >> /etc/apk/repositories

# Update package index (with retry)
echo "Updating Alpine package index..."
for i in 1 2 3; do
    apk update && break
    echo "Attempt $i failed, retrying..."
    sleep 2
done

# Install essential packages (these must succeed)
echo "Installing essential packages..."
apk add --no-cache \
    bash \
    python3 \
    py3-psutil \
    curl \
    wget \
    nano \
    htop \
    net-tools \
    iproute2 \
    iptables \
    openssh \
    doas

# Install system services (these must succeed)
echo "Installing system services..."
apk add --no-cache \
    openrc \
    util-linux \
    coreutils

# Install pip if available (optional)
echo "Installing pip..."
apk add --no-cache py3-pip 2>/dev/null || echo "WARNING: pip not available (will use basic Python)"

# Install security tools (optional)
echo "Installing security tools..."
apk add --no-cache suricata fail2ban nmap tcpdump 2>/dev/null || echo "WARNING: Some security tools not available"

# Install additional packages for live boot (optional)
echo "Installing live boot packages..."
apk add --no-cache squashfs-tools loop 2>/dev/null || echo "WARNING: Some live boot packages not available"

echo "Base packages installed"
CHROOT_EOF

    log_success "Base packages installed"
}

install_cyberxp() {
    log_info "Installing CyberXP-OS Dashboard..."
    
    # Install dashboard with fallback
    mkdir -p "$BUILD_DIR/rootfs/opt/cyberxp-dashboard"
    
    if [[ -d "config/desktop/cyberxp-dashboard" ]]; then
        cp -r config/desktop/cyberxp-dashboard/* "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/"
    else
        log_warn "Dashboard files not found, creating minimal dashboard..."
        # Create minimal dashboard that works without Flask
        cat > "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py" << 'EOF'
#!/usr/bin/env python3
"""
CyberXP-OS Simple Dashboard
Basic HTTP server for system monitoring
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
    
    # Make executable
    chmod +x "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py"
    
    # Optionally copy CyberXP core for backend analysis (if available)
    if [[ -d "$CYBERXP_CORE" ]]; then
        log_warn "CyberXP core found but skipping due to size (2.4GB+)"
        log_info "Dashboard will work without it"
    else
        log_warn "CyberXP core not found at $CYBERXP_CORE (optional)"
    fi
    
    # Try to install Flask (optional - dashboard has fallback)
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
# Try to install Flask if pip is available
if command -v pip3 &> /dev/null; then
    echo "Installing Flask (optional)..."
    pip3 install --no-cache-dir Flask==3.0.0 Werkzeug==3.0.1 2>/dev/null || echo "WARNING: Flask not installed (will use basic HTTP server)"
else
    echo "pip3 not available, dashboard will use basic HTTP server"
fi

echo "Dashboard configured"
CHROOT_EOF

    # Verify installation
    if [[ ! -d "$BUILD_DIR/rootfs/opt/cyberxp-dashboard" ]]; then
        log_error "Dashboard installation failed"
        exit 1
    fi
    
    if [[ ! -f "$BUILD_DIR/rootfs/opt/cyberxp-dashboard/app.py" ]]; then
        log_error "Dashboard app.py not found"
        exit 1
    fi

    log_success "Dashboard installed to /opt/cyberxp-dashboard"
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

# Create cyberxp user (if useradd not available, use adduser)
adduser -D -s /bin/bash cyberxp 2>/dev/null || {
    echo "Creating cyberxp user..."
    echo "cyberxp:x:1000:1000:CyberXP:/home/cyberxp:/bin/bash" >> /etc/passwd
    echo "cyberxp:x:1000:" >> /etc/group
    mkdir -p /home/cyberxp
    chown -R 1000:1000 /home/cyberxp
}

echo "cyberxp:cyberxp" | chpasswd 2>/dev/null || {
    # Fallback password setting
    python3 -c "import crypt; print('cyberxp:' + crypt.crypt('cyberxp', crypt.mksalt()))" > /tmp/pw.txt
    # Manual password hash would need to be added here
}

# Try to add cyberxp to wheel group
addgroup wheel 2>/dev/null || true
adduser cyberxp wheel 2>/dev/null || true

# Configure doas (Alpine's sudo alternative)
mkdir -p /etc/doas.d
echo "permit :wheel" > /etc/doas.conf
echo "permit cyberxp" > /etc/doas.d/cyberxp

# Set timezone to UTC
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Create log directory for dashboard
mkdir -p /var/log
touch /var/log/cyberxp-dashboard.log /var/log/cyberxp-dashboard.err
chown cyberxp:cyberxp /var/log/cyberxp-dashboard.* 2>/dev/null || true

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

setup_bootloader() {
    log_info "Setting up bootloader (BIOS + UEFI)..."
    
    # Install GRUB and kernel in chroot
    chroot "$BUILD_DIR/rootfs" /bin/sh <<'CHROOT_EOF'
# Install kernel first (try multiple sources)
apk add --no-cache linux-lts 2>/dev/null || {
    echo "WARNING: linux-lts not available, trying linux"
    apk add --no-cache linux 2>/dev/null || {
        echo "ERROR: No kernel packages available"
        exit 1
    }
}

# Find installed kernel
KERNEL_VER=$(ls /lib/modules/ | head -1)
echo "Found kernel: $KERNEL_VER"

# Install initramfs tools (optional)
apk add --no-cache mkinitfs 2>/dev/null || echo "WARNING: mkinitfs not available"

# Generate initramfs (optional)
if [ -n "$KERNEL_VER" ] && command -v mkinitfs &> /dev/null; then
    mkinitfs -o /boot/initramfs-lts "$KERNEL_VER" 2>/dev/null || echo "WARNING: Initramfs generation failed"
else
    echo "Skipping initramfs (not available)"
fi

# Try to install GRUB (optional for now)
apk add --no-cache grub 2>/dev/null || echo "WARNING: GRUB not available, will use simple boot"

# List kernel files
echo "=== Kernel Files ==="
ls -la /boot/ | grep -E "vmlinuz|initramfs" || echo "No kernel files found"
echo "==================="

echo "Bootloader setup complete"
CHROOT_EOF
    
    # Check what kernel files we have
    log_info "Checking for kernel files..."
    if [[ -f "$BUILD_DIR/rootfs/boot/vmlinuz-lts" ]]; then
        log_success "Found kernel: vmlinuz-lts"
    elif [[ -f "$BUILD_DIR/rootfs/boot/vmlinuz" ]]; then
        log_success "Found kernel: vmlinuz"
    else
        log_warn "No kernel found in /boot, checking for any kernel files..."
        find "$BUILD_DIR/rootfs/boot/" -name "vmlinuz*" -o -name "vmlinuz" | head -5
    fi
    
    if [[ -f "$BUILD_DIR/rootfs/boot/initramfs-lts" ]]; then
        log_success "Found initramfs"
    else
        log_warn "No initramfs found (boot may still work)"
    fi
    
    log_success "Bootloader setup complete"
}

create_iso() {
    log_info "Creating bootable ISO (BIOS + UEFI)..."
    
    # Create ISO structure
    mkdir -p "$BUILD_DIR/iso/boot/grub"
    mkdir -p "$BUILD_DIR/iso/EFI/BOOT"
    
    # Copy kernel and initramfs from rootfs (handle multiple variants)
    log_info "Copying kernel and initramfs..."
    
    KERNEL_FILE=""
    INITRAMFS_FILE=""
    
    # Try to find kernel
    if [[ -f "$BUILD_DIR/rootfs/boot/vmlinuz-lts" ]]; then
        KERNEL_FILE="$BUILD_DIR/rootfs/boot/vmlinuz-lts"
        INITRAMFS_FILE="$BUILD_DIR/rootfs/boot/initramfs-lts"
    elif [[ -f "$BUILD_DIR/rootfs/boot/vmlinuz" ]]; then
        KERNEL_FILE="$BUILD_DIR/rootfs/boot/vmlinuz"
        INITRAMFS_FILE="$BUILD_DIR/rootfs/boot/initramfs"
    else
        # Search for any kernel
        KERNEL_FILE=$(find "$BUILD_DIR/rootfs/boot/" -name "vmlinuz*" | head -1)
        if [[ -z "$KERNEL_FILE" ]]; then
            log_error "No kernel found! Run setup_bootloader first"
            exit 1
        fi
        INITRAMFS_FILE=$(find "$BUILD_DIR/rootfs/boot/" -name "initramfs*" | head -1)
    fi
    
    cp "$KERNEL_FILE" "$BUILD_DIR/iso/boot/"
    log_success "Kernel copied: $(basename "$KERNEL_FILE")"
    
    if [[ -n "$INITRAMFS_FILE" && -f "$INITRAMFS_FILE" ]]; then
        cp "$INITRAMFS_FILE" "$BUILD_DIR/iso/boot/"
        log_success "Initramfs copied: $(basename "$INITRAMFS_FILE")"
    else
        log_warn "No initramfs found (boot may still work)"
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
    local iso_file="$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    
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
    echo "  🎉 CyberXP-OS Build Complete!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Output:"
    echo "    ISO: $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
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
    echo "    Linux:   sudo dd if=$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso of=/dev/sdX bs=4M"
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
    setup_bootloader
    cleanup_chroot
    create_iso
    show_summary
}

# Run main function
main "$@"

