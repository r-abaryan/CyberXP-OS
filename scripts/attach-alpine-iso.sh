#!/bin/bash
###############################################################################
# Attach Alpine ISO to VirtualBox VM
# Quick script to attach the CyberXP-OS Alpine ISO to a VM
###############################################################################

ISO_PATH="build/output/cyberxp-os-0.1.0-alpha.iso"
VM_NAME="CyberXP-OS-Dev"

# Check if ISO exists
if [[ ! -f "$ISO_PATH" ]]; then
    echo "❌ ERROR: ISO not found at $ISO_PATH"
    echo "Run the build first: sudo ./scripts/build-alpine-iso.sh"
    exit 1
fi

echo "📀 CyberXP-OS Alpine ISO Found: $ISO_PATH"
echo "📦 Size: $(du -h "$ISO_PATH" | cut -f1)"

# Check if VM exists
if ! VBoxManage showvminfo "$VM_NAME" &> /dev/null; then
    echo "Creating new VM: $VM_NAME"
    
    # Create VM
    VBoxManage createvm --name "$VM_NAME" --register
    VBoxManage modifyvm "$VM_NAME" --memory 2048
    VBoxManage modifyvm "$VM_NAME" --vram 32
    VBoxManage modifyvm "$VM_NAME" --graphicscontroller vboxvga
    VBoxManage modifyvm "$VM_NAME" --boot1 dvd
    
    # Add storage controller
    VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata
    
    # Attach ISO
    VBoxManage storageattach "$VM_NAME" \
        --storagectl "SATA Controller" \
        --port 0 \
        --device 0 \
        --type dvddrive \
        --medium "$ISO_PATH"
    
    # Set up port forwarding for dashboard
    VBoxManage modifyvm "$VM_NAME" --natpf1 "dashboard,tcp,,8080,,8080"
    
    echo "✅ VM created and ISO attached"
else
    echo "VM '$VM_NAME' already exists"
    
    # Check if ISO is already attached
    CURRENT_ISO=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep "SATA-0-0" | cut -d'"' -f4)
    
    if [[ "$CURRENT_ISO" == "$ISO_PATH" ]]; then
        echo "✅ ISO already attached"
    else
        echo "Updating ISO..."
        VBoxManage storageattach "$VM_NAME" \
            --storagectl "SATA Controller" \
            --port 0 \
            --device 0 \
            --type dvddrive \
            --medium "$ISO_PATH"
        echo "✅ ISO updated"
    fi
fi

echo ""
echo "🚀 To start the VM:"
echo "   VBoxManage startvm \"$VM_NAME\""
echo ""
echo "🌐 After boot, access dashboard at:"
echo "   http://localhost:8080"
echo ""

