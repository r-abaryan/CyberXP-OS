###############################################################################
# Attach Alpine ISO to VirtualBox VM (PowerShell)
# Uses same approach as setup-dev-vm.ps1
###############################################################################

$VM_NAME = "CyberXP-OS-Dev"
$ISO_PATH = "build\output\cyberxp-os-0.1.0-alpha.iso"

# Set VirtualBox path
$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

# Check if VirtualBox is installed
if (-not (Test-Path $VBoxManage)) {
    Write-Host "Error: VirtualBox not installed" -ForegroundColor Red
    Write-Host "Install from: https://www.virtualbox.org/wiki/Downloads" -ForegroundColor Yellow
    exit 1
}

# Check if ISO exists
if (-not (Test-Path $ISO_PATH)) {
    Write-Host "❌ ERROR: ISO not found at $ISO_PATH" -ForegroundColor Red
    Write-Host "Run the build first in Ubuntu VM: sudo ./scripts/build-alpine-iso.sh" -ForegroundColor Yellow
    exit 1
}

$isoSize = (Get-Item $ISO_PATH).Length / 1MB
Write-Host "📀 CyberXP-OS Alpine ISO Found" -ForegroundColor Green
Write-Host "📦 Size: $([math]::Round($isoSize, 2)) MB" -ForegroundColor Cyan
Write-Host ""

# Check if VM exists
Write-Host "Checking for existing VM..." -ForegroundColor Yellow
$vmList = & $VBoxManage list vms 2>&1
$vmExists = $vmList -match "`"$VM_NAME`""

# Always check if we can actually access the VM
try {
    $testAccess = & $VBoxManage showvminfo $VM_NAME --machinereadable 2>&1
    $canAccessVm = $testAccess -notmatch "Could not find"
    
    if ($canAccessVm) {
        Write-Host "VM '$VM_NAME' exists and is accessible" -ForegroundColor Green
    } else {
        Write-Host "VM '$VM_NAME' not found or not accessible. Creating new VM..." -ForegroundColor Yellow
        $vmExists = $false
    }
} catch {
    Write-Host "Could not verify VM. Creating new VM..." -ForegroundColor Yellow
    $vmExists = $false
}

if (-not $vmExists) {
    Write-Host "Creating new VM: $VM_NAME" -ForegroundColor Green
    
    # Create VM
    & $VBoxManage createvm --name $VM_NAME --ostype "Linux_64" --register
    
    # Configure VM settings
    Write-Host "Configuring VM settings..." -ForegroundColor Green
    & $VBoxManage modifyvm $VM_NAME --memory 4096 --cpus 2 --vram 128 --graphicscontroller vmsvga --boot1 dvd --boot2 disk --nic1 nat --natpf1 "dashboard,tcp,,8080,,8080"
    
    # Create storage controller
    Write-Host "Creating storage controller..." -ForegroundColor Green
    & $VBoxManage storagectl $VM_NAME --name "SATA" --add sata --controller IntelAhci
    
    # Attach ISO
    Write-Host "Attaching ISO..." -ForegroundColor Green
    try {
        & $VBoxManage storageattach $VM_NAME --storagectl "SATA" --port 0 --device 0 --type dvddrive --medium $ISO_PATH
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ VM created and ISO attached" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Warning: ISO attachment command exited with code $LASTEXITCODE" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "❌ Error attaching ISO: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Updating ISO on existing VM..." -ForegroundColor Yellow
    
    # First, check what's currently attached
    Write-Host "Checking current storage configuration..." -ForegroundColor Yellow
    & $VBoxManage showvminfo $VM_NAME --machinereadable | Select-String "SATA"
    
    # Try to remove existing ISO if attached
    Write-Host "Removing existing DVD drive..." -ForegroundColor Yellow
    & $VBoxManage storageattach $VM_NAME --storagectl "SATA" --port 0 --device 0 --type dvddrive --medium none 2>$null
    
    # Wait a moment
    Start-Sleep -Milliseconds 500
    
    # Attach ISO
    Write-Host "Attaching ISO..." -ForegroundColor Green
    $attachResult = & $VBoxManage storageattach $VM_NAME --storagectl "SATA" --port 0 --device 0 --type dvddrive --medium $ISO_PATH 2>&1
    Write-Host "Attachment result: $attachResult" -ForegroundColor Cyan
    
    # Verify
    Write-Host "Verifying attachment..." -ForegroundColor Green
    $result = & $VBoxManage showvminfo $VM_NAME --machinereadable | Select-String "SATA-0-0"
    Write-Host "Storage result: $result" -ForegroundColor Cyan
    
    if ($result) {
        Write-Host "✅ ISO attached to existing VM" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Could not verify ISO attachment" -ForegroundColor Yellow
        Write-Host "Try attaching manually in VirtualBox GUI:" -ForegroundColor Yellow
        Write-Host "  1. Open VirtualBox" -ForegroundColor Cyan
        Write-Host "  2. Right-click VM → Settings → Storage" -ForegroundColor Cyan
        Write-Host "  3. Add optical drive under SATA Controller" -ForegroundColor Cyan
        Write-Host "  4. Select ISO: $ISO_PATH" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Ready to Boot!" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start VM:" -ForegroundColor White
Write-Host "    & `$VBoxManage startvm `"$VM_NAME`"" -ForegroundColor Gray
Write-Host ""
Write-Host "  Or use VirtualBox GUI" -ForegroundColor Gray
Write-Host ""
Write-Host "  After boot, access dashboard at:" -ForegroundColor White
Write-Host "    http://localhost:8080" -ForegroundColor Gray
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan

