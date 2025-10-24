#!/bin/bash
###############################################################################
# CyberXP-OS Ubuntu Quick Rebuild Script
# Quickly rebuilds the Ubuntu-based ISO after making changes
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (for chroot operations)"
    log_info "Run with: sudo ./scripts/quick-rebuild-ubuntu.sh"
    exit 1
fi

# Check if we're in the right directory
if [[ ! -f "scripts/build-ubuntu-iso.sh" ]]; then
    log_error "Please run this script from the CyberXP-OS root directory"
    log_info "Current directory: $(pwd)"
    exit 1
fi

log_info "Starting CyberXP-OS Ubuntu quick rebuild..."

# Clean previous build
log_info "Cleaning previous build..."
rm -rf build/ubuntu/rootfs build/ubuntu/iso
mkdir -p build/ubuntu/{rootfs,iso,temp}
mkdir -p build/output

# Run the main build script
log_info "Running Ubuntu build process..."
./scripts/build-ubuntu-iso.sh

# Check if ISO was created
ISO_FILE="build/output/cyberxp-os-0.1.0-alpha-ubuntu.iso"
if [[ -f "$ISO_FILE" ]]; then
    log_success "Ubuntu ISO rebuilt successfully!"
    log_info "Location: $ISO_FILE"
    log_info "Size: $(du -h "$ISO_FILE" | cut -f1)"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🚀 Next Steps:"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  1. Copy ISO to Windows (if running in WSL):"
    echo "     cp $ISO_FILE /mnt/c/Users/YourUsername/Desktop/"
    echo ""
    echo "  2. Update VM with new ISO:"
    echo "     ./scripts/update-vm-iso.ps1"
    echo ""
    echo "  3. Or create new VM:"
    echo "     ./scripts/setup-dev-vm.ps1"
    echo ""
    echo "  4. Start VM and test boot:"
    echo "     VBoxManage startvm \"CyberXP-OS-Dev\""
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
else
    log_error "Ubuntu ISO build failed!"
    exit 1
fi
