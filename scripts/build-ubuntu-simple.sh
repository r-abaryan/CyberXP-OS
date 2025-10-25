#!/bin/bash

# CyberXP-OS Simple Ubuntu ISO Builder
# This version avoids chroot complications by using a different approach

set -e

# Configuration
UBUNTU_VERSION="24.04"
UBUNTU_CODENAME="noble"
ISO_VERSION="1.0.0"
BUILD_DIR="build"
OUTPUT_DIR="output"
ISO_NAME="cyberxp-os"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check requirements
check_requirements() {
    log_info "Checking requirements..."
    
    local missing_packages=()
    
    if ! command -v wget &> /dev/null; then
        missing_packages+=("wget")
    fi
    
    if ! command -v tar &> /dev/null; then
        missing_packages+=("tar")
    fi
    
    if ! command -v gzip &> /dev/null; then
        missing_packages+=("gzip")
    fi
    
    if ! command -v xorriso &> /dev/null; then
        missing_packages+=("xorriso")
    fi
    
    if ! command -v mksquashfs &> /dev/null; then
        missing_packages+=("squashfs-tools")
    fi
    
    if ! command -v grub-mkrescue &> /dev/null; then
        missing_packages+=("grub-pc-bin")
    fi
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        log_error "Missing required packages: ${missing_packages[*]}"
        log_info "Install with: sudo apt install ${missing_packages[*]}"
        exit 1
    fi
    
    log_success "All requirements met"
}

# Create build directories
create_build_dirs() {
    log_info "Creating build directories..."
    mkdir -p "$BUILD_DIR"
    mkdir -p "$OUTPUT_DIR"
    log_success "Build directories created"
}

# Download Ubuntu Server ISO
download_ubuntu() {
    log_info "Downloading Ubuntu Server ${UBUNTU_VERSION}..."
    
    local iso_file="ubuntu-${UBUNTU_VERSION}-server-amd64.iso"
    local iso_url="https://releases.ubuntu.com/${UBUNTU_VERSION}/${iso_file}"
    
    if [[ -f "$BUILD_DIR/$iso_file" ]]; then
        log_info "Ubuntu ISO already exists, skipping download"
        return
    fi
    
    wget -O "$BUILD_DIR/$iso_file" "$iso_url" || {
        log_error "Failed to download Ubuntu ISO"
        exit 1
    }
    
    log_success "Ubuntu ISO downloaded"
}

# Extract Ubuntu ISO
extract_ubuntu() {
    log_info "Extracting Ubuntu ISO..."
    
    local iso_file="ubuntu-${UBUNTU_VERSION}-server-amd64.iso"
    local mount_point="$BUILD_DIR/mount"
    local extract_dir="$BUILD_DIR/extract"
    
    # Create mount point
    mkdir -p "$mount_point"
    mkdir -p "$extract_dir"
    
    # Mount ISO
    mount -o loop "$BUILD_DIR/$iso_file" "$mount_point" || {
        log_error "Failed to mount Ubuntu ISO"
        exit 1
    }
    
    # Copy files
    cp -r "$mount_point"/* "$extract_dir/" || {
        log_error "Failed to extract Ubuntu ISO"
        umount "$mount_point"
        exit 1
    }
    
    # Unmount
    umount "$mount_point"
    
    log_success "Ubuntu ISO extracted"
}

# Create custom filesystem
create_custom_fs() {
    log_info "Creating custom filesystem..."
    
    local extract_dir="$BUILD_DIR/extract"
    local custom_dir="$BUILD_DIR/custom"
    
    # Copy extracted files
    cp -r "$extract_dir" "$custom_dir"
    
    # Create CyberXP directory structure
    mkdir -p "$custom_dir/opt/cyberxp"
    mkdir -p "$custom_dir/etc/systemd/system"
    
    # Create simple Flask dashboard
    cat > "$custom_dir/opt/cyberxp/dashboard.py" << 'EOF'
#!/usr/bin/env python3
from flask import Flask, render_template_string
import psutil
import json

app = Flask(__name__)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>CyberXP-OS Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; text-align: center; }
        .metric { background: #ecf0f1; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .metric h3 { margin: 0 0 10px 0; color: #34495e; }
        .value { font-size: 18px; font-weight: bold; color: #27ae60; }
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
            <div class="value">{{ cpu_percent }}%</div>
        </div>
        
        <div class="metric">
            <h3>Memory Usage</h3>
            <div class="value">{{ memory_percent }}%</div>
        </div>
        
        <div class="metric">
            <h3>Disk Usage</h3>
            <div class="value">{{ disk_percent }}%</div>
        </div>
        
        <div class="metric">
            <h3>Uptime</h3>
            <div class="value">{{ uptime }}</div>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def dashboard():
    cpu_percent = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    import time
    uptime_seconds = time.time() - psutil.boot_time()
    uptime_hours = int(uptime_seconds // 3600)
    uptime_minutes = int((uptime_seconds % 3600) // 60)
    uptime = f"{uptime_hours}h {uptime_minutes}m"
    
    return render_template_string(HTML_TEMPLATE,
        cpu_percent=cpu_percent,
        memory_percent=memory.percent,
        disk_percent=disk.percent,
        uptime=uptime
    )

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)
EOF

    # Create systemd service
    cat > "$custom_dir/etc/systemd/system/cyberxp-dashboard.service" << 'EOF'
[Unit]
Description=CyberXP Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cyberxp
ExecStart=/usr/bin/python3 /opt/cyberxp/dashboard.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Create startup script
    cat > "$custom_dir/opt/cyberxp/start.sh" << 'EOF'
#!/bin/bash
echo "Starting CyberXP-OS services..."

# Install Python packages if not already installed
if ! python3 -c "import flask" 2>/dev/null; then
    echo "Installing Flask..."
    pip3 install flask psutil
fi

# Start dashboard service
systemctl enable cyberxp-dashboard.service
systemctl start cyberxp-dashboard.service

echo "CyberXP-OS Dashboard started on http://localhost:8080"
echo "System ready!"
EOF

    chmod +x "$custom_dir/opt/cyberxp/start.sh"
    
    log_success "Custom filesystem created"
}

# Create ISO
create_iso() {
    log_info "Creating bootable ISO..."
    
    local custom_dir="$BUILD_DIR/custom"
    local iso_output="$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso"
    
    # Create GRUB configuration
    mkdir -p "$custom_dir/boot/grub"
    cat > "$custom_dir/boot/grub/grub.cfg" << 'EOF'
set timeout=10
set default=0

menuentry "CyberXP-OS" {
    linux /casper/vmlinuz boot=casper quiet splash root=live:LABEL=CYBERXP-OS
    initrd /casper/initrd
}

menuentry "CyberXP-OS (Recovery)" {
    linux /casper/vmlinuz boot=casper quiet splash root=live:LABEL=CYBERXP-OS init=/bin/bash
    initrd /casper/initrd
}
EOF

    # Create squashfs filesystem
    log_info "Creating squashfs filesystem..."
    mksquashfs "$custom_dir" "$BUILD_DIR/filesystem.squashfs" -comp xz -e boot
    
    # Create ISO with GRUB
    log_info "Creating ISO image..."
    grub-mkrescue -o "$iso_output" "$BUILD_DIR/filesystem.squashfs" || {
        log_error "Failed to create ISO"
        exit 1
    }
    
    log_success "ISO created: $iso_output"
}

# Main execution
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CyberXP-OS Simple Ubuntu ISO Builder"
    echo "  Version: $ISO_VERSION"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_requirements
    create_build_dirs
    download_ubuntu
    extract_ubuntu
    create_custom_fs
    create_iso
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Build Complete!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "ISO Location: $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso"
    echo ""
    echo "To test:"
    echo "  VirtualBox: Create new VM and boot from ISO"
    echo "  Physical:   sudo dd if=$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}-ubuntu.iso of=/dev/sdX bs=4M"
    echo ""
    echo "Dashboard: http://localhost:8080 (after boot)"
    echo ""
}

# Run main function
main "$@"
