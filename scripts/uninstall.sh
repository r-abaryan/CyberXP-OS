#!/bin/bash
###############################################################################
# CyberXP-OS Uninstall/Reinstall Script
# Removes CyberXP-OS installation and optionally reinstalls
#
# Usage: 
#   sudo ./scripts/uninstall.sh              # Uninstall only
#   sudo ./scripts/uninstall.sh --reinstall  # Uninstall and reinstall
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "Must run as root: sudo $0"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  CyberXP-OS Uninstaller"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Confirm uninstall
read -p "Are you sure you want to uninstall CyberXP-OS? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

echo ""
log_info "Uninstalling CyberXP-OS..."
echo ""

# Stop services
log_info "Stopping services..."
systemctl stop cyberxp-dashboard 2>/dev/null || true
systemctl stop cyberxp-ai-monitor 2>/dev/null || true

# Disable services
log_info "Disabling services..."
systemctl disable cyberxp-dashboard 2>/dev/null || true
systemctl disable cyberxp-ai-monitor 2>/dev/null || true

# Remove service files
log_info "Removing service files..."
rm -f /etc/systemd/system/cyberxp-dashboard.service
rm -f /etc/systemd/system/cyberxp-ai-monitor.service
systemctl daemon-reload

# Remove binaries
log_info "Removing binaries..."
rm -f /usr/local/bin/cyberxp-status
rm -f /usr/local/bin/cyberxp
rm -f /usr/local/bin/cyberxp-analyze

# Remove directories
log_info "Removing installation directories..."
rm -rf /opt/cyberxp
rm -rf /opt/cyberxp-dashboard
rm -rf /opt/cyberxp-ai

# Remove bash aliases (from /etc/bash.bashrc)
log_info "Removing shell aliases..."
if [ -f /etc/bash.bashrc ]; then
    # Remove CyberXP section from bash.bashrc
    sed -i '/# CyberXP-OS Status Monitor/,/^$/d' /etc/bash.bashrc 2>/dev/null || true
    sed -i '/# Auto-launch CyberXP dashboard/,/^fi$/d' /etc/bash.bashrc 2>/dev/null || true
fi

# Remove MOTD
log_info "Removing MOTD..."
if [ -f /etc/motd ]; then
    # Only remove if it's CyberXP MOTD
    if grep -q "CyberXP-OS" /etc/motd 2>/dev/null; then
        rm -f /etc/motd
    fi
fi

# Optional: Remove Python packages
read -p "Remove Python packages (Flask, psutil)? [y/N]: " remove_packages
if [[ "$remove_packages" =~ ^[Yy]$ ]]; then
    log_info "Removing Python packages..."
    pip3 uninstall -y Flask Werkzeug psutil 2>/dev/null || true
fi

# Optional: Remove system packages
read -p "Remove system packages (python3-pip, etc)? [y/N]: " remove_system
if [[ "$remove_system" =~ ^[Yy]$ ]]; then
    log_info "Removing system packages..."
    apt remove -y python3-pip htop net-tools 2>/dev/null || true
    apt autoremove -y
fi

echo ""
log_success "CyberXP-OS uninstalled successfully!"
echo ""

# Check if reinstall requested
if [[ "$1" == "--reinstall" ]]; then
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Starting Reinstallation"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Check if install.sh exists
    if [ ! -f "scripts/install.sh" ]; then
        log_error "install.sh not found. Please run from CyberXP-OS directory."
        exit 1
    fi
    
    # Run installer
    log_info "Running installer..."
    sleep 2
    ./scripts/install.sh
else
    echo "To reinstall, run:"
    echo "  sudo ./scripts/uninstall.sh --reinstall"
    echo ""
    echo "Or install fresh:"
    echo "  sudo ./scripts/install.sh"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════════"
