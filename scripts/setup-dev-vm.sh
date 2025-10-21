#!/bin/bash
###############################################################################
# CyberXP-OS Development VM Setup
# Quick VM for testing CyberXP-OS during development
###############################################################################

set -e

VM_NAME="CyberXP-OS-Dev"
VM_RAM="4096"  # 4GB
VM_CPUS="2"
VM_DISK_SIZE="20480"  # 20GB

echo "Setting up CyberXP-OS development VM..."

# Check if VirtualBox is installed
if ! command -v VBoxManage &> /dev/null; then
    echo "Error: VirtualBox not installed"
    echo "Install from: https://www.virtualbox.org/wiki/Downloads"
    exit 1
fi

# Remove existing VM if present
VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true

# Create VM
echo "Creating VM: $VM_NAME"
VBoxManage createvm --name "$VM_NAME" --ostype "Linux_64" --register

# Configure VM
VBoxManage modifyvm "$VM_NAME" \
    --memory "$VM_RAM" \
    --cpus "$VM_CPUS" \
    --vram 128 \
    --graphicscontroller vmsvga \
    --boot1 dvd \
    --boot2 disk \
    --nic1 nat \
    --natpf1 "ssh,tcp,,2222,,22" \
    --natpf1 "cyberxp,tcp,,7860,,7860"

# Create storage controller
VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci

# Create virtual disk
VM_DIR=$(VBoxManage showvminfo "$VM_NAME" | grep "Config file" | sed 's/.*: *//' | sed 's/\.vbox//')
VBoxManage createhd --filename "${VM_DIR}/${VM_NAME}.vdi" --size "$VM_DISK_SIZE"

# Attach disk
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" \
    --port 0 --device 0 --type hdd --medium "${VM_DIR}/${VM_NAME}.vdi"

# Attach ISO if it exists
ISO_FILE="build/output/cyberxp-os-*.iso"
if ls $ISO_FILE 1> /dev/null 2>&1; then
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA" \
        --port 1 --device 0 --type dvddrive --medium $(ls $ISO_FILE | head -1)
    echo "ISO attached"
else
    echo "No ISO found - attach manually or build first"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Development VM Created: $VM_NAME"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Specifications:"
echo "    RAM: ${VM_RAM}MB"
echo "    CPUs: $VM_CPUS"
echo "    Disk: ${VM_DISK_SIZE}MB"
echo ""
echo "  Port Forwarding:"
echo "    SSH: localhost:2222 → VM:22"
echo "    CyberXP: localhost:7860 → VM:7860"
echo ""
echo "  Start VM:"
echo "    VBoxManage startvm \"$VM_NAME\""
echo ""
echo "  Or use VirtualBox GUI"
echo ""
echo "═══════════════════════════════════════════════════════════════"

