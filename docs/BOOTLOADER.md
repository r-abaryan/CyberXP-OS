# GRUB Bootloader Implementation

## How It Works

### Boot Chain
```
BIOS/UEFI
    ↓
GRUB Stage 1 (MBR/EFI)
    ↓
GRUB Stage 2 (reads grub.cfg)
    ↓
Loads: vmlinuz-lts (kernel) + initramfs-lts (ramdisk)
    ↓
Kernel mounts SquashFS
    ↓
OpenRC init starts services
    ↓
Dashboard runs (port 8080)
```

### Files Required

```
ISO Structure:
├── boot/
│   ├── grub/
│   │   ├── grub.cfg              ← Menu config
│   │   └── i386-pc/eltorito.img  ← BIOS boot image
│   ├── vmlinuz-lts               ← Linux kernel (~7MB)
│   └── initramfs-lts             ← Initial ramdisk (~15MB)
└── cyberxp-os.squashfs           ← Root filesystem (~500MB-1GB)
```

## GRUB Config Explained

```bash
# config/boot/grub.cfg

set timeout=5          # Wait 5 seconds
set default=0          # Boot first entry

menuentry "CyberXP-OS (Default)" {
    linux /boot/vmlinuz-lts \
        modules=loop,squashfs,sd-mod,usb-storage \  # Load drivers
        quiet                                        # Minimal output
        rootfstype=auto                             # Auto-detect FS
    
    initrd /boot/initramfs-lts  # Load ramdisk
}
```

### Boot Options

1. **Default**: Normal boot, quiet
2. **Verbose**: Shows all kernel messages
3. **Safe Mode**: Single-user mode (troubleshooting)
4. **Recovery**: Drops to shell (expert mode)

## Build Process Changes

### Before (Phase 1)
```bash
# Created filesystem only
mksquashfs rootfs/ → cyberxp-os.squashfs
# No kernel, no bootloader
```

### After (Phase 2)
```bash
# Install kernel + GRUB in chroot
apk add linux-lts grub grub-bios mkinitfs

# Generate initramfs
mkinitfs -o /boot/initramfs-lts

# Copy to ISO
cp rootfs/boot/vmlinuz-lts → iso/boot/
cp rootfs/boot/initramfs-lts → iso/boot/
cp config/boot/grub.cfg → iso/boot/grub/

# Create bootable ISO
grub-mkrescue -o cyberxp-os.iso iso/
```

## Testing

### VirtualBox
```bash
VBoxManage startvm "CyberXP-OS-Dev"
# Should show GRUB menu
# Select boot option
# Should boot to Alpine + Dashboard
```

### Physical USB
```bash
# Burn ISO
sudo dd if=cyberxp-os-0.1.0-alpha.iso of=/dev/sdX bs=4M

# Boot from USB
# GRUB menu appears
# Select boot option
```

## Kernel Parameters

### Critical Modules
```
modules=loop,squashfs,sd-mod,usb-storage
```
- `loop`: Mount loop devices (ISO)
- `squashfs`: Read compressed filesystem
- `sd-mod`: SCSI disk support
- `usb-storage`: USB drive support

### Boot Modes
```
quiet           # Minimal output
console=tty0    # Verbose output
single          # Single-user mode
init=/bin/sh    # Recovery shell
```

## Troubleshooting

### ISO won't boot
```bash
# Check GRUB install
grub-mkrescue --version

# Manually test kernel
qemu-system-x86_64 -kernel vmlinuz-lts \
                   -initrd initramfs-lts \
                   -m 2048
```

### Kernel panic
```
Cause: Missing modules or wrong rootfs
Fix: Boot with "verbose" option, check error
```

### No GRUB menu
```
Cause: BIOS vs UEFI mismatch
Fix: 
- BIOS: Use grub-pc-bin
- UEFI: Use grub-efi-amd64-bin
- Hybrid: Install both
```

## Dependencies Added

```bash
# Alpine packages (in rootfs)
apk add linux-lts grub grub-bios mkinitfs syslinux

# Host tools (for build)
apt install grub-pc-bin grub-efi-amd64-bin
```

## Size Impact

```
Before: ~500MB (filesystem only)
After:  ~550MB (+ kernel ~7MB + initramfs ~15MB + GRUB ~5MB)
```

## UEFI Support

### Added Packages
```bash
apk add grub-efi efibootmgr dosfstools
```

### ISO Structure (Hybrid)
```
iso/
├── boot/
│   └── grub/
│       └── i386-pc/         # BIOS boot files
├── EFI/
│   └── BOOT/
│       ├── grub.cfg         # UEFI GRUB config
│       └── bootx64.efi      # UEFI bootloader
└── cyberxp-os.squashfs
```

### Hybrid Boot
```bash
# grub-mkrescue creates hybrid ISO:
# - BIOS: Uses MBR + boot/grub/
# - UEFI: Uses GPT + EFI/BOOT/

# Result: One ISO boots on both!
```

## What Works

- ✅ BIOS boot (Legacy)
- ✅ UEFI boot (Modern)
- ✅ Hybrid ISO (one file for both)
- ⏳ Secure Boot (future - needs signed kernel)
- ⏳ Persistence (future - save configs)

---

**Status**: Phase 2 complete  
**Boot**: BIOS + UEFI ready  
**Testing**: Ready for physical/VM

