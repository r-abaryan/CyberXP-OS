#!/bin/bash
###############################################################################
# CyberLLM-Agent Installation Script
# Installs the AI analysis engine for CyberXP-OS
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/opt/cyberxp-ai"
REPO_URL="https://github.com/r-abaryan/CyberLLM-Agent.git"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "Run as root: sudo $0"
    exit 1
fi

log_info "Installing CyberLLM-Agent..."

apt update
apt install -y git python3 python3-pip python3-venv

log_info "Cloning CyberLLM-Agent repository..."
if [[ -d "$INSTALL_DIR" ]]; then
    log_info "Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull
else
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

log_info "Installing Python dependencies..."
pip3 install --break-system-packages -r requirements.txt 2>/dev/null || \
    pip3 install -r requirements.txt

log_info "Installing integration bridge..."
cp /opt/cyberxp/scripts/cyberxp-bridge.py /usr/local/bin/cyberxp-analyze
chmod +x /usr/local/bin/cyberxp-analyze

cat >> /etc/bash.bashrc <<'EOF'

# CyberXP AI Analysis
alias analyze='cyberxp-analyze'
EOF

log_success "CyberLLM-Agent installed to $INSTALL_DIR"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🤖 CyberLLM-Agent Installed"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Location: $INSTALL_DIR"
echo ""
echo "  Usage:"
echo "    cyberxp-analyze \"Ransomware detected on file server\""
echo "    analyze \"Suspicious login from unknown IP\""
echo ""
echo "  Direct usage:"
echo "    cd $INSTALL_DIR"
echo "    python3 src/cyber_agent_vec.py --threat \"...\" --enable_ioc"
echo ""
echo "  Web UI:"
echo "    cd $INSTALL_DIR/HF_Space"
echo "    python3 gradio_app.py"
echo ""
echo "═══════════════════════════════════════════════════════════════"
