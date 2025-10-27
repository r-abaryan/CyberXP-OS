# Building CyberXP-OS Alpine ISO

Complete guide to building a bootable CyberXP-OS ISO using Alpine Linux.

## Prerequisites

### Running on Ubuntu VM (VirtualBox)

You're running the build inside an Ubuntu VirtualBox VM. Here's what you need:

```bash
# Install all required build tools (IMPORTANT: Install mtools for bootable ISO)
sudo apt update
sudo apt install -y \
    wget \
    tar \
    gzip \
    xorriso \
    squashfs-tools \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    util-linux \
    file

# Verify installation
which grub-mkrescue xorriso mksquashfs
# Should show paths to all three tools
```

### Alternative: Minimal Install

If you only want the filesystem (not bootable ISO):

```bash
sudo apt install -y xorriso squashfs-tools wget tar gzip
```

## Build Process

### 1. Setup Project

```bash
cd /path/to/CyberXP-OS
```

### 2. Run Build

```bash
# Make script executable
chmod +x scripts/build-alpine-iso.sh

# Run as root
sudo ./scripts/build-alpine-iso.sh
```

### Build Steps

The script will:

1. **Download Alpine** (~5MB, 30 seconds)
   - Downloads Alpine Linux 3.18.4 rootfs
   - Extracts to `build/alpine/rootfs/`

2. **Install Packages** (2-5 minutes)
   - Installs Python 3, psutil, networking tools
   - Installs dashboard files
   - Configures OpenRC services
   - Creates user accounts

3. **Build Filesystem** (1-2 minutes)
   - Creates SquashFS compressed filesystem
   - Compresses to ~500MB
   - Stores in `build/alpine/iso/cyberxp-os.squashfs`

4. **Create ISO** (30 seconds - 2 minutes)
   - If `grub-mkrescue` available: Creates **bootable ISO**
   - If `xorriso` only available: Creates **data ISO** (not bootable)

### Output

**Successful bootable build:**
```
build/output/
└── cyberxp-os-0.1.0-alpha.iso  (~600MB, bootable)
```

**Filesystem only build:**
```
build/alpine/iso/
└── cyberxp-os.squashfs  (~500MB, filesystem)
build/output/
└── cyberxp-os-0.1.0-alpha.iso  (~600MB, data ISO)
```

## Creating Bootable ISO

### Option 1: Full Bootable ISO (Recommended)

**Requires GRUB tools:**
```bash
# On HOST Ubuntu VM
sudo apt install -y grub-pc-bin grub-efi-amd64-bin mtools

# Then run build
sudo ./scripts/build-alpine-iso.sh
```

Result: Bootable ISO with GRUB bootloader

### Option 2: Data ISO + Manual Boot

**If you don't have grub-mkrescue:**

1. Build creates data ISO automatically
2. Extract squashfs filesystem
3. Boot from existing Alpine
4. Mount the squashfs filesystem

**Extract and use:**
```bash
# Extract squashfs
unsquashfs build/alpine/iso/cyberxp-os.squashfs -d /mnt/cyberxp

# Chroot into it
chroot /mnt/cyberxp /bin/sh

# Now you have CyberXP-OS environment
python3 /opt/cyberxp-dashboard/app.py
```

## Boot Support

### With `grub-mkrescue` Installed

✅ **Boots natively** on:
- BIOS systems (Legacy boot)
- UEFI systems
- VirtualBox
- VMware
- Physical hardware
- USB sticks

### Without `grub-mkrescue`

⚠️ **Data ISO only** - Not directly bootable
- Contains complete filesystem
- Must be extracted and used separately
- Good for testing filesystem contents
- Can be mounted in existing Alpine system

## Troubleshooting

### Error: "mformat invocation failed"

**Problem**: Missing `mtools`

**Solution**:
```bash
sudo apt install -y mtools
```

### Error: "grub-mkrescue not found"

**Problem**: GRUB not installed

**Solution**:
```bash
# Install GRUB
sudo apt install -y grub-pc-bin grub-efi-amd64-bin mtools

# Verify
grub-mkrescue --version
```

### Error: "Failed to install packages"

**Problem**: Network issues or package not available

**Solution**: 
- Script automatically retries with multiple mirrors
- Some packages are optional (continues anyway)
- Check network connectivity

### SquashFS creation succeeds, ISO fails

**Problem**: GRUB boot files missing

**Solution**: This is expected if `grub-mkrescue` not installed
- Build will create data ISO
- Use the squashfs filesystem directly
- Or install GRUB tools for bootable ISO

## Testing the ISO

### Bootable ISO

```bash
# Create VM
./scripts/setup-dev-vm.sh

# Or manually
VBoxManage createvm --name "CyberXP-OS-Dev" --register
VBoxManage modifyvm "CyberXP-OS-Dev" --memory 2048
VBoxManage storagectl "CyberXP-OS-Dev" --name "SATA" --add sata
VBoxManage storageattach "CyberXP-OS-Dev" \
    --storagectl "SATA" \
    --port 0 \
    --type dvddrive \
    --medium build/output/cyberxp-os-0.1.0-alpha.iso

# Boot VM
VBoxManage startvm "CyberXP-OS-Dev"
```

### Data ISO / SquashFS

```bash
# Boot existing Alpine or Ubuntu
# Mount the squashfs
sudo mount -o loop build/alpine/iso/cyberxp-os.squashfs /mnt

# Chroot into it
sudo chroot /mnt /bin/sh

# Start dashboard
python3 /opt/cyberxp-dashboard/app.py &
```

## What's Inside

The ISO contains:

### Filesystem (~500MB compressed)
- Alpine Linux base (~5MB)
- Python 3 + psutil
- CyberXP Dashboard
- OpenRC init system
- Network tools
- Security tools (if available)

### Kernel & Boot
- Linux kernel (latest LTS)
- Initramfs
- GRUB bootloader (if bootable)
- Live boot configuration

## Build Time

- **Network**: Fast (10-15 minutes total)
- **Network**: Slow (15-30 minutes total)
- **ISO Size**: 600MB - 2GB (depends on packages)

## Next Steps

1. **Test ISO** - Boot in VirtualBox
2. **Test Dashboard** - Access at http://localhost:8080
3. **Document Issues** - Report any problems
4. **Iterate** - Make improvements

## Comparison: Alpine vs Ubuntu Build

| Feature | Alpine Build | Ubuntu Build |
|---------|-------------|--------------|
| **Base Size** | ~5MB | ~200MB |
| **Final ISO** | ~600MB | ~2GB |
| **Build Time** | 10-15 min | 20-45 min |
| **Boot Speed** | < 10s | 20-30s |
| **Memory** | ~50-100MB | ~200MB |
| **Advantage** | Ultra-lightweight | More compatible |

## Quick Reference

```bash
# Install tools
sudo apt install -y grub-pc-bin grub-efi-amd64-bin xorriso squashfs-tools mtools

# Run build
sudo ./scripts/build-alpine-iso.sh

# Test ISO
VBoxManage startvm "CyberXP-OS-Dev"

# Access dashboard
curl http://localhost:8080
```

## Need Help?

- Check `README.md` for overview
- Check logs in `build/alpine/` for errors
- Install missing tools from Ubuntu repos
- Use Ubuntu build if Alpine has issues

