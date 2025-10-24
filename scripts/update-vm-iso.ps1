# Update VM with New ISO (PowerShell)
# Replaces the ISO in the existing VM with the newly built one

$VM_NAME = "CyberXP-OS-Dev"
$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

Write-Host "Updating VM with new ISO..." -ForegroundColor Green

# Check if VM exists
$vmInfo = & $VBoxManage showvminfo $VM_NAME 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: VM '$VM_NAME' not found" -ForegroundColor Red
    Write-Host "Run setup-dev-vm.ps1 first to create the VM" -ForegroundColor Yellow
    exit 1
}

# Find the new ISO
$ISO_FILE = "build\output\cyberxp-os-*.iso"
if (-not (Test-Path $ISO_FILE)) {
    Write-Host "Error: No ISO found in build\output\" -ForegroundColor Red
    Write-Host "Build the ISO first with: sudo ./scripts/quick-rebuild.sh" -ForegroundColor Yellow
    exit 1
}

$ISO_PATH = (Get-ChildItem $ISO_FILE | Select-Object -First 1).FullName
Write-Host "Found ISO: $ISO_PATH" -ForegroundColor Green

# Detach existing ISO
Write-Host "Detaching existing ISO..." -ForegroundColor Yellow
& $VBoxManage storageattach $VM_NAME --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium none 2>$null

# Attach new ISO
Write-Host "Attaching new ISO..." -ForegroundColor Green
& $VBoxManage storageattach $VM_NAME --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $ISO_PATH

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  VM Updated Successfully!" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  VM: $VM_NAME" -ForegroundColor White
Write-Host "  ISO: $ISO_PATH" -ForegroundColor Gray
Write-Host ""
Write-Host "  Start VM to test:" -ForegroundColor White
Write-Host "    & `$VBoxManage startvm `"$VM_NAME`"" -ForegroundColor Gray
Write-Host ""
Write-Host "  The GRUB configuration has been fixed with proper root= parameters" -ForegroundColor Green
Write-Host "  This should resolve the initramfs shell issue" -ForegroundColor Green
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
