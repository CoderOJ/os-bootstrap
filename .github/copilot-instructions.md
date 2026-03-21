# Project Guidelines

## Code Style
- Keep shell commands and Make targets explicit and reproducible.
- Prefer extending existing targets in Makefile instead of adding ad-hoc scripts.
- Use relative paths from repo root, matching current conventions (for example ./mnt and ./target).

## Architecture
- This repository bootstraps a Debian system image onto a target disk.
- Makefile is the source of truth for workflow orchestration:
  - target/dependency -> target/partition-disk -> target/format -> target/subvolume -> target/bootstrap -> target/all.
- mnt/ is the target root filesystem mountpoint used during bootstrap/chroot.
- target/ contains stamp files that represent completed pipeline stages.
- systemd/network/ contains network templates copied into the bootstrapped system.
- requires.txt defines Debian packages installed by mmdebstrap during bootstrap.

## Build and Test
- Main end-to-end bootstrap command:
  - make target/all DISK=/dev/sdX HOSTID=1
- Test boot in QEMU (UEFI):
  - make test/boot DISK=/dev/sdX
- Enter chroot for inspection:
  - make test/chroot
- Filesystem scrub check:
  - make test/scrub
- Cleanup:
  - make clean

## Conventions
- Treat DISK as mandatory for any disk operation target; fail early if omitted.
- Run from repository root because Make targets rely on relative paths.
- Network config assumes bond0 with static addressing template 10.1.1.${HOSTID}/22.
- Hostname is generated as ${HOSTNAME}${HOSTID} (defaults to i + HOSTID).
- Bootstrapping includes interactive steps (partition confirmation and root password prompt).

## Safety and Pitfalls
- Commands may irreversibly wipe target disks; verify DISK before execution.
- Most targets require root privileges (mount, partition, mkfs, chroot, mmdebstrap).
- QEMU test target expects OVMF firmware files in /usr/share/OVMF.
- Keep package list changes in requires.txt minimal and justified because they alter base image composition.