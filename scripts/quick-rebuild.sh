#!/bin/bash
###############################################################################
# Quick ISO Rebuild Script
# Rebuilds CyberXP-OS ISO with updated GRUB configuration
###############################################################################

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "  CyberXP-OS Quick Rebuild"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (for chroot)"
    echo "[INFO] Run with: sudo ./scripts/quick-rebuild.sh"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "scripts/build-alpine-iso.sh" ]; then
    echo "[ERROR] Please run this script from the CyberXP-OS root directory"
    exit 1
fi

echo "[INFO] Starting ISO rebuild with updated GRUB configuration..."
echo "[INFO] This will fix the boot issues you encountered"
echo ""

# Run the main build script
./scripts/build-alpine-iso.sh

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Rebuild Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Next steps:"
echo "    1. Copy the new ISO to Windows:"
echo "       cp build/output/cyberxp-os-*.iso /mnt/d/AI-ML/CyberXP-OS/build/output/"
echo ""
echo "    2. Update VM with new ISO:"
echo "       # In Windows PowerShell:"
echo "       .\scripts\update-vm-iso.ps1"
echo ""
echo "    3. Start VM and test boot:"
echo "       # In Windows PowerShell:"
echo "       & \"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe\" startvm \"CyberXP-OS-Dev\""
echo ""
echo "═══════════════════════════════════════════════════════════════"
