# CyberXP-OS Development VM Setup (PowerShell version)
# Quick VM for testing CyberXP-OS during development

$VM_NAME = "CyberXP-OS-Dev"
$VM_RAM = 4096  # 4GB
$VM_CPUS = 2
$VM_DISK_SIZE = 20480  # 20GB

Write-Host "Setting up CyberXP-OS development VM..." -ForegroundColor Green

# Set VirtualBox path
$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

# Check if VirtualBox is installed
if (-not (Test-Path $VBoxManage)) {
    Write-Host "Error: VirtualBox not installed" -ForegroundColor Red
    Write-Host "Install from: https://www.virtualbox.org/wiki/Downloads" -ForegroundColor Yellow
    exit 1
}

# Remove existing VM if present
Write-Host "Removing existing VM if present..." -ForegroundColor Yellow
& $VBoxManage unregistervm $VM_NAME --delete 2>$null

# Create VM
Write-Host "Creating VM: $VM_NAME" -ForegroundColor Green
& $VBoxManage createvm --name $VM_NAME --ostype "Linux_64" --register

# Configure VM
Write-Host "Configuring VM settings..." -ForegroundColor Green
& $VBoxManage modifyvm $VM_NAME --memory $VM_RAM --cpus $VM_CPUS --vram 128 --graphicscontroller vmsvga --boot1 dvd --boot2 disk --nic1 nat --natpf1 "ssh,tcp,,2222,,22" --natpf1 "dashboard,tcp,,8080,,8080"

# Create storage controller
Write-Host "Creating storage controller..." -ForegroundColor Green
& $VBoxManage storagectl $VM_NAME --name "SATA" --add sata --controller IntelAhci

# Create virtual disk
Write-Host "Creating virtual disk..." -ForegroundColor Green
$VM_DIR = (& $VBoxManage showvminfo $VM_NAME | Select-String "Config file" | ForEach-Object { $_.Line.Split(':')[1].Trim() }).Replace('.vbox', '')
& $VBoxManage createhd --filename "${VM_DIR}\${VM_NAME}.vdi" --size $VM_DISK_SIZE

# Attach disk
Write-Host "Attaching virtual disk..." -ForegroundColor Green
& $VBoxManage storageattach $VM_NAME --storagectl "SATA" --port 0 --device 0 --type hdd --medium "${VM_DIR}\${VM_NAME}.vdi"

# Attach ISO if it exists
$ISO_FILE = "build\output\cyberxp-os-*.iso"
if (Test-Path $ISO_FILE) {
    $ISO_PATH = (Get-ChildItem $ISO_FILE | Select-Object -First 1).FullName
    & $VBoxManage storageattach $VM_NAME --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium $ISO_PATH
    Write-Host "ISO attached: $ISO_PATH" -ForegroundColor Green
} else {
    Write-Host "No ISO found - attach manually or build first" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Development VM Created: $VM_NAME" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Specifications:" -ForegroundColor White
Write-Host "    RAM: ${VM_RAM}MB" -ForegroundColor Gray
Write-Host "    CPUs: $VM_CPUS" -ForegroundColor Gray
Write-Host "    Disk: ${VM_DISK_SIZE}MB" -ForegroundColor Gray
Write-Host ""
Write-Host "  Port Forwarding:" -ForegroundColor White
Write-Host "    SSH: localhost:2222 → VM:22" -ForegroundColor Gray
Write-Host "    Dashboard: localhost:8080 → VM:8080" -ForegroundColor Gray
Write-Host ""
Write-Host "  Start VM:" -ForegroundColor White
Write-Host "    & `$VBoxManage startvm `"$VM_NAME`"" -ForegroundColor Gray
Write-Host ""
Write-Host "  Or use VirtualBox GUI" -ForegroundColor Gray
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan