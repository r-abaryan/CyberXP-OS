#!/bin/bash
###############################################################################
# CyberXP-OS Lightweight Installation Script for Ubuntu
# Installs terminal-based status monitor instead of web dashboard
#
# Usage: sudo ./install-cyberxp-ubuntu-lite.sh
#
# This script:
# - Installs minimal dependencies (no Flask/web server)
# - Sets up terminal-based status monitor
# - Configures basic system monitoring
# - Much lighter weight than web dashboard
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/cyberxp"
STATUS_SCRIPT="/usr/local/bin/cyberxp-status"

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
    log_info "Checking requirements..."
    
    # Check for root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Run with: sudo $0"
        exit 1
    fi
    
    # Check network connectivity
    if ! ping -c 1 -W 3 8.8.8.8 &> /dev/null; then
        log_error "No internet connection detected"
        exit 1
    fi
    
    log_success "Requirements check passed"
}

update_system() {
    log_info "Updating system packages..."
    apt update || {
        log_error "Failed to update package lists"
        exit 1
    }
    log_success "System updated"
}

install_dependencies() {
    log_info "Installing minimal dependencies..."
    
    # Install only essential tools (no web server!)
    DEBIAN_FRONTEND=noninteractive apt install -y \
        python3 \
        python3-pip \
        curl \
        wget \
        htop \
        net-tools \
        iproute2 \
        iputils-ping || {
        log_error "Failed to install dependencies"
        exit 1
    }
    
    log_success "Dependencies installed"
}

install_status_monitor() {
    log_info "Installing CyberXP Status Monitor..."
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    mkdir -p /opt/cyberxp/scripts
    
    # Copy status script
    if [[ -f "scripts/internal/cyberxp-status.py" ]]; then
        cp scripts/internal/cyberxp-status.py "$STATUS_SCRIPT"
    else
        log_error "Status script not found at scripts/internal/cyberxp-status.py"
        exit 1
    fi
    
    # Copy integration bridge
    if [[ -f "scripts/internal/cyberxp-bridge.py" ]]; then
        cp scripts/internal/cyberxp-bridge.py /opt/cyberxp/scripts/
    fi
    
    # Copy CyberLLM install script
    if [[ -f "scripts/install-cyberxp-dependencies.sh" ]]; then
        cp scripts/install-cyberxp-dependencies.sh /opt/cyberxp/scripts/
        chmod +x /opt/cyberxp/scripts/install-cyberxp-dependencies.sh
    fi
    
    # Make executable
    chmod +x "$STATUS_SCRIPT"
    
    log_success "Status monitor installed to $STATUS_SCRIPT"
}

create_alias() {
    log_info "Creating command alias and auto-launch..."
    
    # Add alias to bashrc for all users
    cat >> /etc/bash.bashrc <<'EOF'

# CyberXP-OS Status Monitor
alias cyberxp='sudo /usr/local/bin/cyberxp-status'
alias cyberxp-status='sudo /usr/local/bin/cyberxp-status'

# Auto-launch CyberXP dashboard on login (only for interactive shells)
if [[ $- == *i* ]] && [[ -z "$CYBERXP_LAUNCHED" ]] && [[ -n "$SSH_CONNECTION" || "$USER" == "cyberxp" ]]; then
    export CYBERXP_LAUNCHED=1
    echo "Launching CyberXP Dashboard..."
    sleep 1
    cyberxp
fi
EOF
    
    log_success "Alias and auto-launch configured"
}

configure_motd() {
    log_info "Configuring MOTD..."
    
    # Create custom MOTD
    cat > /etc/motd <<'EOF'
╔═══════════════════════════════════════════════════════════╗
║          CyberXP-OS v0.1.0-alpha (Lite)                  ║
║      AI-Powered Security Analysis Platform               ║
╚═══════════════════════════════════════════════════════════╝

Quick Commands:
  • Status Monitor:  cyberxp
  • System Info:     htop
  • Network Info:    ip addr show

To view CyberXP status, run: cyberxp

GitHub: https://github.com/r-abaryan/CyberXP-OS
EOF
    
    log_success "MOTD configured"
}

show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  🎉 CyberXP-OS Terminal Dashboard Installed!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  ✓ Installation Complete"
    echo ""
    echo "  📋 HOW TO USE:"
    echo ""
    echo "  Option 1 (Recommended for beginners):"
    echo "    1. Close this terminal window"
    echo "    2. Open a new terminal"
    echo "    3. Type: cyberxp"
    echo "    4. Dashboard will appear!"
    echo ""
    echo "  Option 2 (Advanced - no need to close terminal):"
    echo "    1. Type: source /etc/bash.bashrc"
    echo "    2. Type: cyberxp"
    echo ""
    echo "  🎯 Dashboard Commands:"
    echo "    • Press 'q' to quit"
    echo "    • Press 'r' to refresh"
    echo "    • Press 's' to manage services"
    echo "    • Press 'l' to view logs"
    echo "    • Press 'a' for AI analysis (install AI first)"
    echo ""
    echo "  🤖 Optional - Install AI Analysis:"
    echo "    sudo /opt/cyberxp/scripts/install-cyberxp-dependencies.sh"
    echo ""
    echo "  💡 Auto-Launch:"
    echo "    Dashboard will automatically launch when you:"
    echo "    • SSH into the system"
    echo "    • Login as 'cyberxp' user"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  👉 NEXT: Close this terminal and open a new one, then type: cyberxp"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  CyberXP-OS Lite Installation for Ubuntu"
    echo "  Terminal-Based Status Monitor (No Web Server)"
    echo "  Version: 0.1.0-alpha"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    check_requirements
    update_system
    install_dependencies
    install_status_monitor
    create_alias
    configure_motd
    show_summary
    
    echo ""
    log_success "Installation complete! Run 'cyberxp' to start the status monitor"
    echo ""
}

# Run main function
main "$@"
