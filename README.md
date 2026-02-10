# OS Bootstrap

A Debian Linux system bootstrap tool that automates the process of creating a fully configured Debian system from scratch. This tool handles disk partitioning, filesystem creation, system installation, and bootloader configuration.

## Features

- **GPT Partitioning**: Automated disk partitioning with EFI System Partition and Btrfs root partition
- **Btrfs Filesystem**: Uses Btrfs with optimized subvolume layout for better management
- **systemd-boot**: Modern UEFI bootloader configuration
- **cloud-init**: Automated initial system configuration
- **Minimal Base System**: Clean Debian installation with essential packages
- **Helper Scripts**: Post-installation configuration scripts included

## System Architecture

### Partition Layout
- **Partition 1 (EFI)**: 1GB FAT32 filesystem for UEFI boot
- **Partition 2 (Root)**: Btrfs filesystem using remaining disk space

### Btrfs Subvolumes
- `/home` - User home directories
- `/home/cscg` - Specific user subvolume
- `/var` - Variable data
- `/var/cache` - Cache data (Copy-on-Write disabled for better performance)
- `/opt` - Optional software

## Requirements

### Host System Dependencies
The following packages are required on the host system:

```bash
apt install gdisk btrfs-progs parted dosfstools mmdebstrap systemd-boot qemu-system-x86 ovmf
```

### Supported Debian Versions
- Default: `trixie` (Debian 13)
- Configurable via `DEBIAN_VERSION` variable

## Usage

### Basic Workflow

1. **Install dependencies**:
```bash
make target/dependency
```

2. **Partition the disk** (⚠️ **DESTRUCTIVE OPERATION**):
```bash
make target/partition-disk DISK=/dev/sdX
```

3. **Format partitions**:
```bash
make target/format DISK=/dev/sdX
```

4. **Create Btrfs subvolumes**:
```bash
make target/subvolume DISK=/dev/sdX
```

5. **Bootstrap Debian system**:
```bash
make target/bootstrap DISK=/dev/sdX
```

6. **Install bootloader**:
```bash
make target/systemd-boot DISK=/dev/sdX
```

7. **Complete installation** (runs bootstrap + systemd-boot):
```bash
make target/all DISK=/dev/sdX
```

### Testing

**Boot system in QEMU**:
```bash
make test/boot DISK=/dev/sdX
```

**Enter chroot environment**:
```bash
make test/chroot DISK=/dev/sdX
```

**Run Btrfs scrub**:
```bash
make test/scrub DISK=/dev/sdX
```

### Using a Different Debian Version

```bash
make target/all DISK=/dev/sdX DEBIAN_VERSION=bookworm
```

## Configuration

### APT Sources
The system uses Tsinghua University mirrors for faster downloads in China. Configuration is in `apt/sources.list.template`.

### cloud-init
Initial system configuration is handled by cloud-init with the NoCloud datasource:
- `cloud-init/nocloud/meta-data` - Instance metadata
- `cloud-init/nocloud/user-data` - User data and scripts
- `cloud-init/nocloud/network-config` - Network configuration

### systemd-boot
Bootloader configuration:
- `systemd-boot/loader/loader.conf` - Loader settings
- `systemd-boot/loader/entries/debian.conf.sh` - Boot entry generator

## Helper Scripts

The following post-installation scripts are included in `/home/cscg/scripts/`:

- **debian-nvidia-driver.sh**: Install NVIDIA proprietary drivers
- **enable-mdns.sh**: Enable mDNS (multicast DNS) support
- **ldap-sssd-client.sh**: Configure LDAP authentication with SSSD

## Included Packages

The base system includes:
- `linux-image-amd64` - Linux kernel
- `systemd`, `systemd-sysv`, `systemd-resolved` - System and service manager
- `login`, `sudo` - User authentication
- `cloud-init` - Instance initialization
- `netplan.io` - Network configuration
- `btrfs-progs` - Btrfs filesystem utilities
- `openssh-client`, `openssh-server` - SSH connectivity
- `locales` - Localization support

## Utility Commands

### Mount/Unmount Operations

**Mount partitions**:
```bash
make util/mount DISK=/dev/sdX
```

**Mount kernel filesystems** (dev, proc, sys):
```bash
make util/mount-kernelfs
```

**Unmount partitions**:
```bash
make util/unmount
```

**Unmount kernel filesystems**:
```bash
make util/unmount-kernelfs
```

### Clean Up

**Remove all build artifacts and unmount**:
```bash
make clean
```

## ⚠️ Important Warnings

1. **Data Loss**: The partitioning and formatting operations will **DESTROY ALL DATA** on the target disk
2. **Device Verification**: Always double-check the `DISK` variable to ensure you're targeting the correct device
3. **Confirmation Required**: The `target/partition-disk` target requires explicit confirmation
4. **Root Privileges**: Most operations require root/sudo privileges

## Project Structure

```
.
├── Makefile                      # Main build system
├── apt/
│   └── sources.list.template     # APT repository configuration
├── cloud-init/
│   ├── 99-local.cfg             # cloud-init local configuration
│   └── nocloud/                  # NoCloud datasource files
│       ├── meta-data
│       ├── user-data
│       └── network-config
├── scripts/                      # Post-installation helper scripts
│   ├── debian-nvidia-driver.sh
│   ├── enable-mdns.sh
│   └── ldap-sssd-client.sh
└── systemd-boot/
    └── loader/                   # Bootloader configuration
        ├── loader.conf
        └── entries/
            └── debian.conf.sh
```

## Troubleshooting

### Partition Table Issues
If `partprobe` fails, try:
```bash
partprobe /dev/sdX
# or reboot the system
```

### Mount Issues
Ensure all filesystems are unmounted before repartitioning:
```bash
make util/unmount-kernelfs
make util/unmount
```

### QEMU Boot Issues
Ensure OVMF firmware files are installed:
```bash
apt install ovmf
```

## License

This project is provided as-is for educational and deployment purposes.

## Contributing

Contributions are welcome! Please ensure all changes are tested before submitting.
