#!/bin/bash
###############################################################################
# CyberXP-OS Alpine Linux ISO Builder (v5 - Native Alpine Live Boot)
# Uses Alpine's standard live boot method with apkovl overlays
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ALPINE_VERSION="3.18.4"
ALPINE_MIRROR="https://dl-cdn.alpinelinux.org/alpine"
BUILD_DIR="$(pwd)/build/alpine"
OUTPUT_DIR="$(pwd)/build/output"

ISO_NAME="cyberxp-os"
ISO_VERSION="0.1.0-alpha"
ISO_LABEL="CYBERXP_OS"

###############################################################################
# Helper Functions
###############################################################################

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_requirements() {
    log_info "Checking requirements..."
    
    if [[ $EUID -ne 0 ]]; then
        log_error "Must run as root"
        exit 1
    fi
    
    local tools=("wget" "tar" "xorriso" "mksquashfs")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Missing: $tool"
            log_info "Install: sudo apt install wget tar xorriso squashfs-tools syslinux isolinux"
            exit 1
        fi
    done
    
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "No internet connection"
        exit 1
    fi
    
    log_success "Requirements OK"
}

download_alpine_iso() {
    log_info "Downloading official Alpine ISO..."
    
    local alpine_iso="alpine-standard-${ALPINE_VERSION}-x86_64.iso"
    local download_url="${ALPINE_MIRROR}/v${ALPINE_VERSION%.*}/releases/x86_64/${alpine_iso}"
    
    mkdir -p "$BUILD_DIR"
    
    if [[ ! -f "$BUILD_DIR/$alpine_iso" ]]; then
        wget -O "$BUILD_DIR/$alpine_iso" "$download_url"
        log_success "Alpine ISO downloaded"
    else
        log_info "Alpine ISO exists (cached)"
    fi
    
    # Extract ISO
    log_info "Extracting Alpine ISO..."
    rm -rf "$BUILD_DIR/iso"
    mkdir -p "$BUILD_DIR/iso"
    
    # Mount and copy ISO contents
    mkdir -p "$BUILD_DIR/mnt"
    mount -o loop "$BUILD_DIR/$alpine_iso" "$BUILD_DIR/mnt" 2>/dev/null || true
    
    if mountpoint -q "$BUILD_DIR/mnt"; then
        cp -a "$BUILD_DIR/mnt/"* "$BUILD_DIR/iso/"
        umount "$BUILD_DIR/mnt"
        log_success "ISO extracted"
    else
        log_error "Failed to mount ISO"
        exit 1
    fi
}

create_apkovl_overlay() {
    log_info "Creating CyberXP overlay..."
    
    local overlay_dir="$BUILD_DIR/overlay"
    rm -rf "$overlay_dir"
    mkdir -p "$overlay_dir"/{etc,root,opt}
    
    # Hostname
    echo "cyberxp-os" > "$overlay_dir/etc/hostname"
    
    # Root password
    mkdir -p "$overlay_dir/etc"
    # Pre-hashed password for 'cyberxp' (mkpasswd -m sha-512 cyberxp)
    cat > "$overlay_dir/etc/shadow" <<'EOF'
root:$6$rounds=656000$YgFj0d8PD8W0yrG0$XQPmXFHgVK8xVUvLqr5VlKlN.jBQD9N0X8jKGR6YjqN1YZNyh0cB3Kv8zN7x1VbU9pQx2LjQ8FqVRPmN1KzJ9/:19000:0:::::
EOF
    
    # Network config
    mkdir -p "$overlay_dir/etc/network"
    cat > "$overlay_dir/etc/network/interfaces" <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    hostname cyberxp-os
EOF
    
    # Repositories
    mkdir -p "$overlay_dir/etc/apk"
    cat > "$overlay_dir/etc/apk/repositories" <<'EOF'
http://dl-cdn.alpinelinux.org/alpine/v3.18/main
http://dl-cdn.alpinelinux.org/alpine/v3.18/community
EOF
    
    # Local startup script
    mkdir -p "$overlay_dir/etc/local.d"
    cat > "$overlay_dir/etc/local.d/cyberxp.start" <<'STARTSCRIPT'
#!/bin/sh
# CyberXP-OS startup script

# Install packages on first boot
if [ ! -f /root/.cyberxp-installed ]; then
    echo "Installing CyberXP packages..."
    apk update
    apk add python3 py3-pip bash nano htop curl git
    
    # Install Flask
    pip3 install --break-system-packages Flask 2>/dev/null || pip3 install Flask
    
    touch /root/.cyberxp-installed
    echo "✓ CyberXP packages installed"
fi

# Start dashboard if it exists
if [ -f /opt/cyberxp-dashboard/app.py ]; then
    cd /opt/cyberxp-dashboard
    python3 app.py > /var/log/cyberxp-dashboard.log 2>&1 &
    echo "✓ CyberXP Dashboard started on port 8080"
fi
STARTSCRIPT
    chmod +x "$overlay_dir/etc/local.d/cyberxp.start"
    
    # MOTD
    cat > "$overlay_dir/etc/motd" <<'EOF'

╔═══════════════════════════════════════════════════════════╗
║             CyberXP-OS v0.1.0-alpha (Live)                ║
║           AI-Powered Security Analysis Platform           ║
╚═══════════════════════════════════════════════════════════╝

Login: root
Password: cyberxp

Quick Start:
  • Network: setup-interfaces
  • Install: setup-alpine
  • Packages: apk add <package>

Dashboard: http://$(hostname -i 2>/dev/null || echo "localhost"):8080

GitHub: https://github.com/r-abaryan/CyberXP-OS

EOF
    
    # CyberXP Dashboard
    mkdir -p "$overlay_dir/opt/cyberxp-dashboard"
    cat > "$overlay_dir/opt/cyberxp-dashboard/app.py" <<'PYEOF'
from flask import Flask, render_template_string

app = Flask(__name__)

HTML = """
<!DOCTYPE html>
<html>
<head>
    <title>CyberXP-OS Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Courier New', monospace;
            background: linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 100%);
            color: #0f0;
            min-height: 100vh;
            padding: 20px;
        }
        .container { 
            max-width: 1200px; 
            margin: 0 auto;
            background: rgba(0,0,0,0.7);
            border: 2px solid #0f0;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 0 20px rgba(0,255,0,0.3);
        }
        h1 { 
            text-align: center;
            font-size: 2.5em;
            margin-bottom: 30px;
            text-shadow: 0 0 10px #0f0;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .card {
            background: rgba(0,40,0,0.5);
            border: 1px solid #0f0;
            border-radius: 8px;
            padding: 20px;
        }
        .card h2 {
            color: #0f0;
            margin-bottom: 15px;
            border-bottom: 1px solid #0f0;
            padding-bottom: 10px;
        }
        .status-line {
            display: flex;
            justify-content: space-between;
            margin: 10px 0;
            padding: 5px;
        }
        .status-ok { color: #0f0; }
        .status-warn { color: #ff0; }
        code {
            background: rgba(0,0,0,0.5);
            padding: 2px 6px;
            border-radius: 3px;
            color: #0ff;
        }
        .blink { animation: blink 1s infinite; }
        @keyframes blink {
            0%, 50% { opacity: 1; }
            51%, 100% { opacity: 0.3; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ CyberXP-OS Dashboard</h1>
        
        <div class="status-grid">
            <div class="card">
                <h2>System Status</h2>
                <div class="status-line">
                    <span>Mode:</span>
                    <span class="status-ok blink">● LIVE (Diskless)</span>
                </div>
                <div class="status-line">
                    <span>Version:</span>
                    <span>0.1.0-alpha</span>
                </div>
                <div class="status-line">
                    <span>Base:</span>
                    <span>Alpine Linux 3.18</span>
                </div>
            </div>
            
            <div class="card">
                <h2>Quick Commands</h2>
                <div style="line-height: 2;">
                    <div>Network: <code>setup-interfaces</code></div>
                    <div>Install: <code>setup-alpine</code></div>
                    <div>Packages: <code>apk add &lt;pkg&gt;</code></div>
                    <div>Reboot: <code>reboot</code></div>
                </div>
            </div>
            
            <div class="card">
                <h2>Security Features</h2>
                <div class="status-line">
                    <span>AI Analysis:</span>
                    <span class="status-warn">⚠ Not Configured</span>
                </div>
                <div class="status-line">
                    <span>Firewall:</span>
                    <span class="status-ok">✓ Available</span>
                </div>
                <div class="status-line">
                    <span>Network Tools:</span>
                    <span class="status-ok">✓ Ready</span>
                </div>
            </div>
        </div>
        
        <div class="card" style="margin-top: 20px;">
            <h2>About CyberXP-OS</h2>
            <p style="line-height: 1.8;">
                CyberXP-OS is a specialized Linux distribution designed for security analysis 
                and AI-powered threat detection. This is a live system running entirely from 
                RAM - all changes will be lost on reboot unless you install to disk.
            </p>
            <p style="margin-top: 15px;">
                GitHub: <a href="https://github.com/r-abaryan/CyberXP-OS" style="color: #0ff;">
                    github.com/r-abaryan/CyberXP-OS
                </a>
            </p>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def home():
    return render_template_string(HTML)

if __name__ == '__main__':
    print("Starting CyberXP Dashboard on http://0.0.0.0:8080")
    app.run(host='0.0.0.0', port=8080, debug=False)
PYEOF
    
    # Package the overlay as apkovl
    log_info "Creating apkovl archive..."
    cd "$overlay_dir"
    tar czf "$BUILD_DIR/iso/cyberxp.apkovl.tar.gz" .
    cd - > /dev/null
    
    log_success "CyberXP overlay created"
}

customize_boot() {
    log_info "Customizing boot configuration..."
    
    # Find syslinux config location
    local syslinux_dir=""
    if [[ -d "$BUILD_DIR/iso/boot/syslinux" ]]; then
        syslinux_dir="$BUILD_DIR/iso/boot/syslinux"
    elif [[ -d "$BUILD_DIR/iso/syslinux" ]]; then
        syslinux_dir="$BUILD_DIR/iso/syslinux"
    else
        log_warn "Syslinux directory not found, using default Alpine boot"
        return
    fi
    
    log_info "Found syslinux at: $syslinux_dir"
    
    # Backup original
    cp "$syslinux_dir/syslinux.cfg" "$syslinux_dir/syslinux.cfg.orig" 2>/dev/null || true
    
    # Create custom config (simpler, no menu.c32 dependency)
    cat > "$syslinux_dir/syslinux.cfg" <<'SYSLINUX'
SERIAL 0 115200
DEFAULT cyberxp
PROMPT 1
TIMEOUT 50

LABEL cyberxp
    MENU LABEL CyberXP-OS Live
    KERNEL /boot/vmlinuz-lts
    INITRD /boot/initramfs-lts
    APPEND modules=loop,squashfs,sd-mod,usb-storage nomodeset quiet

LABEL cyberxp-verbose
    MENU LABEL CyberXP-OS Live (Verbose)
    KERNEL /boot/vmlinuz-lts
    INITRD /boot/initramfs-lts
    APPEND modules=loop,squashfs,sd-mod,usb-storage nomodeset console=tty0

LABEL recovery
    MENU LABEL Recovery Shell
    KERNEL /boot/vmlinuz-lts
    INITRD /boot/initramfs-lts
    APPEND modules=loop,squashfs,sd-mod,usb-storage init=/bin/sh
SYSLINUX
    
    log_success "Boot configuration customized (menu.c32 removed)"
}

create_iso() {
    log_info "Creating final ISO..."
    
    local iso_file="$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    mkdir -p "$OUTPUT_DIR"
    
    # Use xorriso to create bootable ISO
    if [[ -f "$BUILD_DIR/iso/boot/syslinux/isolinux.bin" ]]; then
        xorriso -as mkisofs \
            -o "$iso_file" \
            -isohybrid-mbr "$BUILD_DIR/iso/boot/syslinux/isohdpfx.bin" \
            -c boot/syslinux/boot.cat \
            -b boot/syslinux/isolinux.bin \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -V "$ISO_LABEL" \
            "$BUILD_DIR/iso" 2>&1 | grep -v "WARNING" || true
    else
        # Fallback for different Alpine versions
        xorriso -as mkisofs \
            -o "$iso_file" \
            -V "$ISO_LABEL" \
            "$BUILD_DIR/iso" 2>&1 | grep -v "WARNING" || true
    fi
    
    if [[ -f "$iso_file" ]]; then
        log_success "✓ ISO created: $iso_file"
        log_info "Size: $(du -h "$iso_file" | cut -f1)"
    else
        log_error "ISO creation failed"
        exit 1
    fi
}

show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🎉 CyberXP-OS Live ISO Ready!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  ISO: $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo ""
    echo "  This ISO uses Alpine's native live boot system with"
    echo "  CyberXP customizations applied via apkovl overlay."
    echo ""
    echo "  Test with QEMU:"
    echo "    qemu-system-x86_64 -m 2048 -enable-kvm \\"
    echo "      -cdrom $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo ""
    echo "  Test with VirtualBox:"
    echo "    VBoxManage createvm --name CyberXP --ostype Linux_64 --register"
    echo "    VBoxManage modifyvm CyberXP --memory 2048"
    echo "    VBoxManage storagectl CyberXP --name SATA --add sata"
    echo "    VBoxManage storageattach CyberXP --storagectl SATA \\"
    echo "      --port 0 --device 0 --type dvddrive \\"
    echo "      --medium $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo "    VBoxManage startvm CyberXP"
    echo ""
    echo "  Login: root"
    echo "  Password: cyberxp"
    echo ""
    echo "  Dashboard will auto-start after packages install"
    echo "  Access at: http://<vm-ip>:8080"
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
    echo "  Based on Alpine Linux (Native Live Boot)"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_requirements
    download_alpine_iso
    create_apkovl_overlay
    customize_boot
    create_iso
    show_summary
}

main "$@"