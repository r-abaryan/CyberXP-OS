#!/bin/bash
###############################################################################
# CyberXP-OS Unified Installer
# Choose: Terminal or Web dashboard
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "Run as root: sudo $0"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  CyberXP-OS Installer"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Choose installation type:"
echo ""
echo "  1) Dashboard only (Terminal or Web)"
echo "  2) Dashboard + AI dependencies (includes CyberLLM-Agent)"
echo ""
read -p "Enter choice [1-2]: " install_type

if [[ "$install_type" == "2" ]]; then
    INSTALL_AI=true
else
    INSTALL_AI=false
fi

echo ""
echo "Choose dashboard type:"
echo ""
echo "  1) Terminal - CLI status monitor (lightweight)"
echo "  2) Web - Flask dashboard on port 8080"
echo ""
read -p "Enter choice [1-2]: " choice

case $choice in
    1)
        log_info "Installing Terminal dashboard..."
        ./scripts/internal/install-direct-terminal.sh
        ;;
    2)
        log_info "Installing Web dashboard..."
        ./scripts/internal/install-direct-web.sh
        ;;
    *)
        log_error "Invalid choice"
        exit 1
        ;;
esac

if [[ "$INSTALL_AI" == "true" ]]; then
    log_info "Installing AI dependencies..."
    ./scripts/install-cyberxp-dependencies.sh
fi

log_success "Installation complete!"
