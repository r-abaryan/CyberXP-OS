#!/bin/bash
###############################################################################
# CyberLLM-Agent Installation Script
# Installs the AI analysis engine for CyberXP-OS
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

INSTALL_DIR="/opt/cyberxp-ai"
REPO_URL="https://github.com/r-abaryan/CyberLLM-Agent.git"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

if [[ $EUID -ne 0 ]]; then
    log_error "Run as root: sudo $0"
    exit 1
fi

log_info "Installing CyberLLM-Agent..."

# Install system dependencies
log_info "Installing system dependencies..."
apt update
apt install -y git python3 python3-pip python3-venv

# Clone or update repository
log_info "Setting up CyberLLM-Agent repository..."
if [[ -d "$INSTALL_DIR" ]]; then
    log_info "Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull
else
    log_info "Cloning CyberLLM-Agent repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

# Install Python dependencies system-wide
log_info "Installing Python dependencies..."
pip3 install --break-system-packages -r requirements.txt || {
    log_error "Failed to install dependencies"
    exit 1
}

# Download AI model
log_info "Downloading CyberXP AI model (this may take several minutes)..."
log_warn "Model size: ~1.2GB - please be patient"
python3 << 'PYEOF'
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

print("Downloading model: abaryan/CyberXP_Agent_Llama_3.2_1B")
model_name = "abaryan/CyberXP_Agent_Llama_3.2_1B"

# Download tokenizer
tokenizer = AutoTokenizer.from_pretrained(model_name)
print("✓ Tokenizer downloaded")

# Download model
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    torch_dtype=torch.float32,
    low_cpu_mem_usage=True
)
print("✓ Model downloaded and cached")
PYEOF

# Create wrapper script
log_info "Creating wrapper script..."
cat > /usr/local/bin/cyberxp-analyze << 'WRAPPER'
#!/bin/bash
# Find and call the bridge script
BRIDGE_SCRIPT="/opt/cyberxp/scripts/internal/cyberxp-bridge.py"

if [ ! -f "$BRIDGE_SCRIPT" ]; then
    # Try alternative locations
    for loc in "/opt/cyberxp/scripts/cyberxp-bridge.py" "$(dirname "$0")/../scripts/internal/cyberxp-bridge.py"; do
        if [ -f "$loc" ]; then
            BRIDGE_SCRIPT="$loc"
            break
        fi
    done
fi

if [ ! -f "$BRIDGE_SCRIPT" ]; then
    echo "Error: cyberxp-bridge.py not found"
    exit 1
fi

python3 "$BRIDGE_SCRIPT" "$@"
WRAPPER

chmod +x /usr/local/bin/cyberxp-analyze

# Add alias to bashrc if not already present
if ! grep -q "alias analyze=" /etc/bash.bashrc; then
    cat >> /etc/bash.bashrc << 'EOF'

# CyberXP AI Analysis
alias analyze='cyberxp-analyze'
EOF
fi

log_success "CyberLLM-Agent installed to $INSTALL_DIR"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  🤖 CyberLLM-Agent Installed Successfully"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Location: $INSTALL_DIR"
echo "  Model: CyberXP_Agent_Llama_3.2_1B (cached)"
echo ""
echo "  CLI Usage (Direct):"
echo "    cyberxp-analyze \"Suspicious login from unknown IP\""
echo ""
echo "  Dashboard Usage (Menu):"
echo "    cyberxp  (then press 'a' for AI Assistant)"
echo ""
echo "  Web UI:"
echo "    cd $INSTALL_DIR/HF_Space"
echo "    python3 gradio_app.py"
echo "    # Access at http://localhost:7860"
echo ""
echo "═══════════════════════════════════════════════════════════════"
