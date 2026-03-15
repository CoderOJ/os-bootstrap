DEBIAN_VERSION ?= trixie

clean:
	rm -rf target
	${MAKE} util/unmount-kernelfs
	${MAKE} util/unmount
	rm -rf mnt 
	rm -rf qemu-run

util/mount:
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)

	mount --mkdir `lsblk -nlo PATH ${DISK} | awk 'NR==3 {print}'` ./mnt
	mount --mkdir -o fmask=077,umask=077 `lsblk -nlo PATH ${DISK} | awk 'NR==2 {print}'` ./mnt/boot

util/mount-kernelfs:
	mount --mkdir --bind /dev  ./mnt/dev
	mount --mkdir --bind /proc ./mnt/proc
	mount --mkdir --bind /sys  ./mnt/sys

util/unmount:
	umount ./mnt/boot 	|| true
	umount ./mnt 		|| true

util/unmount-kernelfs:
	umount ./mnt/dev	|| true
	umount ./mnt/proc 	|| true
	umount ./mnt/sys 	|| true

target/dependency:
	apt install gdisk btrfs-progs parted dosfstools mmdebstrap qemu-system-x86 ovmf debian-keyring debian-archive-keyring arch-install-scripts

	mkdir -p target
	@touch $@

target/partition-disk: target/dependency
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)
	@read -p "Partition ${DISK}? (y/N): " c && [ "$$c" = y ] || { echo "Canceled"; exit 1; }

	# 1. 清空磁盘分区表
	sgdisk -Z "${DISK}"
	# 2. 创建 GPT (Clear)
	sgdisk -o "${DISK}"
	# 3. 创建 EFI 分区（FAT32）1G
	sgdisk -n 1:0:+1G -t 1:EF00 -c 1:"EFI System" "${DISK}"
	# 4. 创建 Btrfs 根分区（剩余全部）
	sgdisk -n 2:0:0 -t 2:8304 -c 2:"Linux root (btrfs)" "${DISK}"
	# 重新加载分区表
	partprobe "${DISK}"

	@touch $@

target/format-efi:
	@test "${PART_EFI}" != "" || (echo "Specify PART_EFI"; exit 1)

	@echo format ${PART_EFI} as FAT
	mkfs.fat -F32 ${PART_EFI}

	@touch $@

target/format-root:
	@test "${PART_ROOT}" != "" || (echo "Specify PART_ROOT"; exit 1)

	@echo format ${PART_EFI} as btrfs
	mkfs.btrfs -f ${PART_ROOT}

	@touch $@

target/format: target/partition-disk
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)

	mkdir -p ./mnt
	${MAKE} target/format-root "PART_ROOT=`lsblk -nlo PATH ${DISK} | awk 'NR==3 {print}'`"
	${MAKE} target/format-efi  "PART_EFI=`lsblk -nlo PATH ${DISK} | awk 'NR==2 {print}'`"
	
	@touch $@

target/subvolume: target/format
	${MAKE} util/mount

	btrfs su create mnt/home
	btrfs su create mnt/var
	btrfs su create mnt/var/cache
	btrfs su create mnt/opt
	chattr +C mnt/var/cache

	@touch $@

target/bootstrap: target/subvolume
	mmdebstrap \
		--arch=amd64 \
		--variant=apt \
		--include=linux-image-amd64,login,systemd,systemd-sysv,systemd-resolved,systemd-boot,sudo,btrfs-progs,openssh-client,openssh-server,locales,vim \
		--skip=check/empty \
		${DEBIAN_VERSION} ./mnt

	genfstab -U ./mnt > ./mnt/etc/fstab

	${MAKE} util/mount-kernelfs

	@touch $@

target/all: target/bootstrap target/systemd-boot

test/boot:
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)

	${MAKE} util/unmount-kernelfs
	${MAKE} util/unmount

	mkdir -p qemu-run
	cp /usr/share/OVMF/OVMF_VARS_4M.fd ./qemu-run/OVMF_VARS_4M.fd
	qemu-system-x86_64 -nographic -m 4g -smp 8 \
		  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
		  -drive file=${DISK},format=raw,if=none,id=disk0,cache=directsync \
		  -netdev user,id=net0 \
		  -device virtio-net-pci,netdev=net0 \
		  -device virtio-blk-pci,drive=disk0

test/chroot:
	${MAKE} util/mount
	${MAKE} util/mount-kernelfs
	chroot ./mnt

test/scrub:
	${MAKE} util/mount
	btrfs scrub start -B mnt
