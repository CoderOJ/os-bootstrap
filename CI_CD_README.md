# OS Bootstrap CI/CD

This repository includes an automated CI/CD pipeline that builds and tests a Debian-based OS installation using a loopback device and QEMU/KVM.

## CI/CD Workflow Overview

The GitHub Actions workflow (`.github/workflows/ci.yml`) performs the following steps:

### 1. Build Phase
- **Create Loopback Device**: Creates a 10GB virtual disk image as a loopback device
- **Partition Disk**: Creates GPT partitions (1GB EFI + remaining for root)
- **Format Partitions**: Formats EFI as FAT32 and root as Btrfs
- **Create Subvolumes**: Creates Btrfs subvolumes for /home, /var, /opt, etc.

### 2. Installation Phase
- **Bootstrap Debian**: Uses debootstrap to install Debian Trixie
- **Install Packages**: Installs kernel, cloud-init, SSH, and other essential packages
- **Configure Cloud-Init**: Sets up cloud-init with nocloud datasource
- **Install Bootloader**: Installs systemd-boot as the UEFI bootloader

### 3. Test Phase
- **SSH Key Setup**: Generates SSH key pair for automated testing
- **Configure User**: Adds SSH key to the `cscg` user's authorized_keys
- **Boot with QEMU/KVM**: Starts the system in QEMU with KVM acceleration
- **SSH Connection Test**: Validates SSH connectivity to the cscg user
- **System Validation**: Runs comprehensive tests inside the VM

### 4. Validation Tests

The test script verifies:
- System hostname and uptime
- Disk mount points
- Btrfs subvolumes
- User configuration and permissions
- Network configuration
- Systemd services (networkd, sshd)

## Local Testing

You can run the build process locally using the Makefile:

```bash
# Install dependencies
sudo make target/dependency

# Create and partition a loopback device
sudo dd if=/dev/zero of=/tmp/disk.img bs=1M count=10240
sudo losetup -fP /tmp/disk.img
export DISK=$(losetup -j /tmp/disk.img | cut -d: -f1)

# Run the installation
sudo make target/all DISK=$DISK

# Boot and test
sudo make test/boot DISK=$DISK
```

## Cloud-Init Configuration

The system uses cloud-init for initial configuration:

- **User**: `cscg` with sudo privileges (password: `cscg`, hash in user-data)
- **Network**: Configured via systemd-networkd
- **SSH**: Password authentication disabled, key-based authentication only
- **Locale**: en_US.UTF-8
- **Timezone**: Asia/Shanghai

### CI-Specific Network Config

For CI testing, a simplified network configuration (`cloud-init/nocloud/network-config.ci`) is used that:
- Matches all ethernet interfaces with pattern `e*`
- Enables DHCP on all matched interfaces
- Works in both VM and physical environments

## SSH Access in CI

The CI workflow:
1. Generates an ED25519 SSH key pair
2. Adds the public key to `/home/cscg/.ssh/authorized_keys`
3. Uses port forwarding (host:2222 → guest:22) to connect via SSH
4. Runs validation tests over SSH

## Workflow Triggers

The CI/CD workflow runs on:
- Push to `main` or `master` branches
- Pull requests to `main` or `master` branches
- Manual workflow dispatch

## Troubleshooting

If the CI workflow fails:

1. Check the workflow logs in GitHub Actions
2. Review the uploaded QEMU output artifact (available on failure)
3. Common issues:
   - Boot timeout: Increase sleep time in "Boot with QEMU/KVM" step
   - SSH connection failure: Check cloud-init logs and network configuration
   - Disk space: Ensure sufficient space for 10GB disk image

## Architecture

- **Boot**: UEFI with systemd-boot
- **Filesystem**: Btrfs with subvolumes
- **Init**: systemd
- **Network**: systemd-networkd
- **Configuration**: cloud-init

## Security Notes

- SSH password authentication is disabled by default
- The `cscg` user has passwordless sudo (suitable for development/testing)
- For production use, remove passwordless sudo and use SSH keys only
- The CI workflow generates ephemeral SSH keys that are not committed

## License

See the main repository license.
