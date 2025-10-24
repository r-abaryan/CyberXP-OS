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
echo "  ISO Location:"
echo "    $(ls -la build/output/cyberxp-os-*.iso)"
echo ""
echo "  Next Steps (Choose One):"
echo ""
echo "  Option A - Manual Copy (Recommended):"
echo "    1. Open Windows File Explorer"
echo "    2. Navigate to: D:\\AI-ML\\CyberXP-OS\\build\\output\\"
echo "    3. Copy the new ISO file"
echo "    4. In PowerShell, run: .\\scripts\\update-vm-iso.ps1"
echo ""
echo "  Option B - WSL Copy (if /mnt/d works):"
echo "    1. Try: cp build/output/cyberxp-os-*.iso /mnt/d/AI-ML/CyberXP-OS/build/output/"
echo "    2. If successful, run: .\\scripts\\update-vm-iso.ps1"
echo ""
echo "  Option C - Direct VM Update:"
echo "    1. In PowerShell, run: .\\scripts\\update-vm-iso.ps1"
echo "    2. The script will look for the ISO in build\\output\\"
echo ""
echo "  Start VM:"
echo "    & \"C:\\Program Files\\Oracle\\VirtualBox\\VBoxManage.exe\" startvm \"CyberXP-OS-Dev\""
echo ""
echo "═══════════════════════════════════════════════════════════════"
