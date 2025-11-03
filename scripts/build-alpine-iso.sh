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
    mkdir -p "$overlay_dir"/{etc/profile.d,etc/network,etc/apk,etc/local.d,root,opt,etc/init.d,etc/runlevels/default}
    
    # Hostname
    echo "cyberxp-os" > "$overlay_dir/etc/hostname"
    
    # Root password (blank password)
    mkdir -p "$overlay_dir/etc"
    cat > "$overlay_dir/etc/shadow" <<'EOF'
root::19000:0:::::
EOF
    
    # Base network config (loopback only - real iface set at boot by startup script)
    mkdir -p "$overlay_dir/etc/network"
    cat > "$overlay_dir/etc/network/interfaces" <<'EOF'
auto lo
iface lo inet loopback
EOF
    
    # Repositories
    mkdir -p "$overlay_dir/etc/apk"
    cat > "$overlay_dir/etc/apk/repositories" <<'EOF'
http://dl-cdn.alpinelinux.org/alpine/v3.18/main
http://dl-cdn.alpinelinux.org/alpine/v3.18/community
EOF
    
    # Local startup script with improved networking and service enablement
    mkdir -p "$overlay_dir/etc/local.d"
    cat > "$overlay_dir/etc/local.d/cyberxp.start" <<'STARTSCRIPT'
#!/bin/sh
# CyberXP-OS startup script

# Enable and start networking
echo "Configuring network..."

IFACE=""
for c in eth0 enp0s3 enp0s8 ens33; do
    if [ -d "/sys/class/net/$c" ]; then IFACE=$c; break; fi
done
if [ -z "$IFACE" ]; then
    IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|enp|ens)' | head -1)
fi

if [ -n "$IFACE" ]; then
    echo "Found interface: $IFACE"
    echo "$IFACE" > /run/cyberxp-iface
    
    # Bring interface up
    ip link set $IFACE up
    
    # Kill any existing udhcpc processes
    killall udhcpc 2>/dev/null || true
    
    # Update /etc/network/interfaces to match detected iface
    cat > /etc/network/interfaces <<EOFCONF
auto lo
iface lo inet loopback

auto $IFACE
iface $IFACE inet dhcp
    hostname cyberxp-os
    udhcpc_opts -t 5 -T 3 -A 1
EOFCONF

    rc-update add networking default 2>/dev/null || true
    rc-service networking restart 2>/dev/null || true

    # Start udhcpc with proper flags for VirtualBox compatibility
    echo "Requesting IPv4 address via DHCP..."
    udhcpc -i $IFACE -f -n -q -t 5 -T 3 -A 1 || {
        echo "DHCP foreground failed, trying background mode..."
        udhcpc -i $IFACE -b -q -t 10 -T 2
    }
    
    # Wait for IP assignment
    sleep 3
    
    # Check if we got IPv4
    IPV4=$(ip -4 addr show $IFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)
    
    if [ -n "$IPV4" ]; then
        echo "✓ Network configured on $IFACE with IP: $IPV4"
        ip addr show $IFACE | grep inet
    else
        echo "⚠ No IPv4 address obtained"
        echo "Current network status:"
        ip addr show $IFACE
        echo ""
        echo "Try manually: udhcpc -i $IFACE -n"
    fi
else
    echo "⚠ No network interface found"
fi

# Install packages on first boot
if [ ! -f /root/.cyberxp-installed ]; then
    echo "Installing CyberXP packages..."
    apk update
    # Prefer distro packages first to avoid pip/network fragility
    apk add python3 py3-pip py3-flask py3-psutil bash nano htop curl git net-tools 2>/dev/null || true
    
    # Fallback to pip if Flask not present
    if ! python3 -c "import flask" 2>/dev/null; then
        echo "Installing Flask via pip..."
        pip3 install --break-system-packages Flask 2>/dev/null || pip3 install Flask || true
    fi
    
    touch /root/.cyberxp-installed
    echo "✓ CyberXP packages installed"
fi

# Ensure OpenRC service is registered
if [ -x /etc/init.d/cyberxp-dashboard ]; then
    rc-update add cyberxp-dashboard default 2>/dev/null || true
fi

# Ensure local scripts run at boot
if [ -x /etc/init.d/local ]; then
    rc-update add local default 2>/dev/null || true
fi

    # Start dashboard if it exists
    if [ -f /opt/cyberxp-dashboard/app.py ]; then
        cd /opt/cyberxp-dashboard
        # Start service (avoid restart to prevent stop errors when not running)
        rc-service cyberxp-dashboard start >/dev/null 2>&1 || \
            python3 /opt/cyberxp-dashboard/app.py > /var/log/cyberxp-dashboard.log 2>&1 &
        echo "✓ CyberXP Dashboard should be running on port 8080"

        # Allow inbound 8080 if iptables exists and rule not present (non-fatal)
        if command -v iptables >/dev/null 2>&1; then
            iptables -C INPUT -p tcp --dport 8080 -j ACCEPT >/dev/null 2>&1 || \
                iptables -I INPUT -p tcp --dport 8080 -j ACCEPT >/dev/null 2>&1 || true
        fi

        # Health check (guest-local)
        for i in 1 2 3 4 5; do
            wget -qO- http://127.0.0.1:8080/healthz >/dev/null 2>&1 && { echo "✓ Dashboard health: OK"; break; }
            sleep 1
        done

        # Show IP address for dashboard access
        IPV4=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)
        if [ -n "$IPV4" ]; then
            echo "✓ Dashboard available at: http://$IPV4:8080"
            echo "✓ From host (NAT): Setup port forwarding or use http://localhost:8080"
        else
            echo "⚠ No IPv4 - Dashboard running but network needs configuration"
        fi
    fi
STARTSCRIPT
    chmod +x "$overlay_dir/etc/local.d/cyberxp.start"
    
    # MOTD with network instructions
    cat > "$overlay_dir/etc/motd" <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║          CyberXP-OS v0.1.0-alpha (Live)                  ║
║      AI-Powered Security Analysis Platform               ║
╚═══════════════════════════════════════════════════════════╝

Login:    root
Password: (blank - just press Enter)

Network Status:
EOF
    
    # Add a script to show network status in MOTD
    mkdir -p "$overlay_dir/etc/profile.d"
    cat > "$overlay_dir/etc/profile.d/network-status.sh" <<'NETSCRIPT'
# Show network status on login
if [ "$PS1" ]; then
    echo ""
    echo "Network Interfaces:"
    ip -br addr show | grep -v "lo.*127.0.0.1" || echo "  No network configured"

    # Determine likely interface to suggest commands with
    IFACE=""
    if [ -f /run/cyberxp-iface ]; then
        IFACE=$(cat /run/cyberxp-iface)
    fi
    if [ -z "$IFACE" ]; then
        for c in eth0 enp0s3 enp0s8 ens33; do
            if [ -d "/sys/class/net/$c" ]; then IFACE=$c; break; fi
        done
    fi
    if [ -z "$IFACE" ]; then
        IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|enp|ens)' | head -1)
    fi

    IPV4=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1 | head -1)
    if [ -n "$IPV4" ]; then
        echo ""
        echo "✓ Dashboard: http://$IPV4:8080"
        echo "✓ From host (with NAT): http://localhost:8080 (setup port forwarding first)"
    else
        echo ""
        echo "⚠ No IPv4 configured. Try:"
        if [ -n "$IFACE" ]; then
            echo "   • ip link set $IFACE up"
            echo "   • udhcpc -i $IFACE -n"
        else
            echo "   • ip link"
            echo "   • udhcpc -i <iface> -n"
        fi
        echo "   • setup-interfaces -r"
    fi
    echo ""
fi
NETSCRIPT
    chmod 644 "$overlay_dir/etc/profile.d/network-status.sh"
    
    cat >> "$overlay_dir/etc/motd" <<'EOF'

Quick Start:
  • Fix IPv4:          udhcpc -i eth0 -n
  • Configure network: setup-interfaces -r
  • Install to disk:   setup-alpine
  • View dashboard:    See IP above

Troubleshooting:
  • Check interface:   ip addr show eth0
  • Test DHCP:         udhcpc -i eth0 -f -n -v
  • Manual IP:         ip addr add 10.0.2.15/24 dev eth0

GitHub: https://github.com/r-abaryan/CyberXP-OS
EOF
    
    # CyberXP Dashboard
    mkdir -p "$overlay_dir/opt/cyberxp-dashboard"
    cat > "$overlay_dir/opt/cyberxp-dashboard/app.py" <<'PYEOF'
from flask import Flask, render_template_string
import subprocess
import os

app = Flask(__name__)

def get_network_info():
    try:
        result = subprocess.run(['ip', '-4', 'addr', 'show'],
                               capture_output=True, text=True)
        return result.stdout
    except Exception:
        return "Network info unavailable"

HTML = """
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
            margin-bottom: 30px;
        }
        .status h2 {
            font-size: 1.5em;
            margin-bottom: 15px;
        }
        .network-info {
            background: rgba(0, 0, 0, 0.3);
            padding: 15px;
            border-radius: 8px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            overflow-x: auto;
            white-space: pre;
        }
        .commands {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        .cmd {
            background: rgba(0, 0, 0, 0.3);
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #4ade80;
        }
        .cmd h3 {
            font-size: 1.1em;
            margin-bottom: 8px;
            color: #4ade80;
        }
        .cmd code {
            background: rgba(0, 0, 0, 0.5);
            padding: 5px 10px;
            border-radius: 4px;
            display: inline-block;
            font-family: 'Courier New', monospace;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            opacity: 0.8;
        }
        .footer a {
            color: #4ade80;
            text-decoration: none;
        }
        .refresh-note {
            text-align: center;
            font-size: 0.9em;
            opacity: 0.7;
            margin-top: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛡️ CyberXP-OS</h1>
        <div class="subtitle">AI-Powered Security Analysis Platform</div>
        
        <div class="status">
            <h2>System Status</h2>
            <p>✓ Alpine Linux Live Environment</p>
            <p>✓ Dashboard Running on Port 8080</p>
            <p>⚠ Live Mode - Changes will be lost on reboot</p>
            <div class="refresh-note">Page auto-refreshes every 30 seconds</div>
        </div>
        
        <div class="status">
            <h2>Network Configuration</h2>
            <div class="network-info">{{ network_info }}</div>
        </div>
        
        <div class="commands">
            <div class="cmd">
                <h3>Fix IPv4 DHCP</h3>
                <code>udhcpc -i eth0 -n</code>
            </div>
            <div class="cmd">
                <h3>Network Setup</h3>
                <code>setup-interfaces</code>
            </div>
            <div class="cmd">
                <h3>Install to Disk</h3>
                <code>setup-alpine</code>
            </div>
            <div class="cmd">
                <h3>Install Packages</h3>
                <code>apk add &lt;pkg&gt;</code>
            </div>
            <div class="cmd">
                <h3>Check Network</h3>
                <code>ip addr show</code>
            </div>
            <div class="cmd">
                <h3>Restart Network</h3>
                <code>rc-service networking restart</code>
            </div>
        </div>
        
        <div class="footer">
            <p><strong>About:</strong> CyberXP-OS is a specialized Linux distribution designed for security analysis and AI-powered threat detection. This is a live system running entirely from RAM.</p>
            <p style="margin-top: 10px;">
                <strong>VirtualBox NAT Users:</strong> Setup port forwarding (Host Port 8080 → Guest Port 8080) to access this dashboard from your host machine at http://localhost:8080
            </p>
            <p style="margin-top: 10px;">
                <a href="https://github.com/r-abaryan/CyberXP-OS" target="_blank">GitHub: github.com/r-abaryan/CyberXP-OS</a>
            </p>
        </div>
    </div>
</body>
</html>
"""

@app.route('/')
def home():
    network_info = get_network_info()
    return render_template_string(HTML, network_info=network_info)

@app.route('/healthz')
def healthz():
    return 'ok', 200

if __name__ == '__main__':
    port = int(os.environ.get('PORT', '8080'))
    app.run(host='0.0.0.0', port=port, debug=False)
PYEOF
    
    # OpenRC service for dashboard
    cat > "$overlay_dir/etc/init.d/cyberxp-dashboard" <<'SVC'
#!/sbin/openrc-run
description="CyberXP Dashboard (Flask)"

command="/usr/bin/env"
command_args="python3 /opt/cyberxp-dashboard/app.py"
command_background="yes"
pidfile="/run/cyberxp-dashboard.pid"
start_stop_daemon_args="--make-pidfile --pidfile ${pidfile}"
output_log="/var/log/cyberxp-dashboard.log"
error_log="/var/log/cyberxp-dashboard.log"

depend() {
    need net
    after firewall local
}

start_pre() {
    command -v python3 >/dev/null 2>&1 || {
        eerror "python3 not found"
        return 1
    }
    python3 -c 'import flask' >/dev/null 2>&1 || {
        eerror "Flask not installed"
        return 1
    }
    mkdir -p /var/log
}
SVC
    chmod +x "$overlay_dir/etc/init.d/cyberxp-dashboard"

    # Enable services in default runlevel via symlinks
    ln -sf /etc/init.d/cyberxp-dashboard "$overlay_dir/etc/runlevels/default/cyberxp-dashboard"
    # Ensure local.d scripts run on boot as well
    ln -sf /etc/init.d/local "$overlay_dir/etc/runlevels/default/local"
    
    # Package overlay as apkovl tarball
    log_info "Packaging overlay..."
    cd "$overlay_dir"
    tar czf "$BUILD_DIR/cyberxp.apkovl.tar.gz" *
    cd - > /dev/null
    
    log_success "Overlay created: $BUILD_DIR/cyberxp.apkovl.tar.gz"
}

integrate_overlay_into_iso() {
    log_info "Integrating overlay into ISO..."
    
    # Copy overlay to ISO root
    cp "$BUILD_DIR/cyberxp.apkovl.tar.gz" "$BUILD_DIR/iso/"
    
    # Modify boot configuration to auto-load overlay (both BIOS and UEFI)
    local syslinux_cfg="$BUILD_DIR/iso/boot/syslinux/syslinux.cfg"
    local grub_cfg="$BUILD_DIR/iso/boot/grub/grub.cfg"

    # BIOS: Syslinux
    if [[ -f "$syslinux_cfg" ]]; then
        cp "$syslinux_cfg" "${syslinux_cfg}.bak"
        # Try to update a default kernel opts variable if present
        sed -i 's/default_kernel_opts\(.*\)$/default_kernel_opts\1 apkovl=LABEL=CYBERXP_OS:\/cyberxp.apkovl.tar.gz net.ifnames=0 biosdevname=0/' "$syslinux_cfg" || true
        # Also patch any explicit append lines
        sed -i 's/\(\<append\>\.*\)/\1 apkovl=LABEL=CYBERXP_OS:\\/cyberxp.apkovl.tar.gz net.ifnames=0 biosdevname=0/' "$syslinux_cfg" || true
        # As a fallback, replace first occurrence of "quiet"
        sed -i '0,/: quiet/s//: quiet apkovl=LABEL=CYBERXP_OS:\\\/cyberxp.apkovl.tar.gz net.ifnames=0 biosdevname=0/' "$syslinux_cfg" || true
        log_success "Syslinux updated to load overlay"
    else
        log_warn "syslinux.cfg not found, BIOS path unchanged"
    fi

    # UEFI: GRUB
    if [[ -f "$grub_cfg" ]]; then
        cp "$grub_cfg" "${grub_cfg}.bak"
        # Append param to linux lines
        sed -i 's/\(linux\s\+[^\n]*\)$/\1 apkovl=LABEL=CYBERXP_OS:\/cyberxp.apkovl.tar.gz net.ifnames=0 biosdevname=0/' "$grub_cfg" || true
        log_success "GRUB updated to load overlay"
    else
        log_warn "grub.cfg not found, UEFI path unchanged"
    fi
}

build_iso() {
    log_info "Building custom ISO..."
    
    mkdir -p "$OUTPUT_DIR"
    local output_iso="$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    
    xorriso -as mkisofs \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "$ISO_LABEL" \
        -eltorito-boot boot/syslinux/isolinux.bin \
        -eltorito-catalog boot/syslinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -output "$output_iso" \
        "$BUILD_DIR/iso" 2>&1 | grep -v "xorriso : UPDATE" || true
    
    if [[ -f "$output_iso" ]]; then
        log_success "ISO built: $output_iso"
        log_info "ISO size: $(du -h "$output_iso" | cut -f1)"
    else
        log_error "ISO build failed"
        exit 1
    fi
}

cleanup() {
    log_info "Cleaning up..."
    
    # Unmount if still mounted
    if mountpoint -q "$BUILD_DIR/mnt" 2>/dev/null; then
        umount "$BUILD_DIR/mnt"
    fi
    
    log_success "Cleanup complete"
}

show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✓ CyberXP-OS ISO Build Complete${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "ISO Location: $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo ""
    echo "Next Steps:"
    echo "  1. Test in VM: qemu-system-x86_64 -m 2048 -cdrom $OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso"
    echo "  2. Burn to USB: sudo dd if=$OUTPUT_DIR/${ISO_NAME}-${ISO_VERSION}.iso of=/dev/sdX bs=4M status=progress"
    echo "  3. Boot and login with username 'root' (no password)"
    echo ""
    echo "VirtualBox Setup:"
    echo "  • Network: NAT mode (default)"
    echo "  • Port Forward: Host Port 8080 → Guest Port 8080"
    echo "  • Access: http://localhost:8080 (from host)"
    echo ""
    echo "If IPv4 doesn't work:"
    echo "  • Run: udhcpc -i eth0 -n"
    echo "  • Or: setup-interfaces -r"
    echo ""
    echo "Features:"
    echo "  ✓ Enhanced DHCP client with VirtualBox compatibility"
    echo "  ✓ Auto-network configuration (IPv4 via DHCP)"
    echo "  ✓ Web dashboard on port 8080 with live network status"
    echo "  ✓ Troubleshooting commands in MOTD"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

###############################################################################
# Main Execution
###############################################################################

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║        CyberXP-OS Alpine Linux ISO Builder               ║"
    echo "║         Version 5.1 - IPv4 Network Enhanced              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    check_requirements
    download_alpine_iso
    create_apkovl_overlay
    integrate_overlay_into_iso
    build_iso
    cleanup
    show_summary
}

# Trap errors
trap 'log_error "Build failed at line $LINENO"' ERR

# Run
main "$@"
