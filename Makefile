DEBIAN_VERSION ?= trixie
HOSTID ?= 1
HOSTNAME ?= i

clean:
	rm -rf target
	${MAKE} util/unmount-kernelfs
	${MAKE} util/unmount
	rm -rf mnt 
	rm -rf qemu-run

util/mount:
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)

	mount --mkdir `lsblk -nlo PATH ${DISK} | awk 'NR==3 {print}'` ./mnt
	mount --mkdir -o fmask=027,umask=027 `lsblk -nlo PATH ${DISK} | awk 'NR==2 {print}'` ./mnt/boot

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
	apt install gdisk btrfs-progs parted dosfstools debootstrap qemu-system-x86 ovmf arch-install-scripts

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

	@echo format ${PART_ROOT} as btrfs
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
	
	@echo "Bootstrapping Debian ${DEBIAN_VERSION} into ./mnt"
	debootstrap \
		--arch=amd64 \
		--variant=minbase \
		${DEBIAN_VERSION} ./mnt

	@echo "Setting kernel cmdline"
	echo "root=UUID=`findmnt -no UUID ./mnt` rw" > ./mnt/etc/kernel/cmdline
	
	@echo "Generating fstab"
	./genfstab -U ./mnt > ./mnt/etc/fstab

	@echo "Setting up APT sources"
	rm ./mnt/etc/apt/sources.list
	cp ./mnt/usr/share/doc/apt/examples/debian.sources ./mnt/etc/apt/sources.list.d

	@echo "Installing necessary packages"
	arch-chroot ./mnt apt update
	arch-chroot ./mnt apt install -y --no-install-recommends --show-progress -V \
		`grep -vE "^\s*#" requires.txt | tr "\n" " "`
	
	@touch $@

target/passwd: target/bootstrap
	@echo "Setting root password"
	echo "root:$y$j9T$owqKSbkFGt/QiF6cL2vn91$9AFWGKvBPYdJYbWz3H6e7YNyRYFPCBk5ZHS2cBCZ1l4" | arch-chroot ./mnt chpasswd -e
	
	@touch $@

target/network: target/bootstrap
	@echo "Setting up networkd and resolved services"
	arch-chroot ./mnt systemctl enable systemd-networkd systemd-resolved
	ln -sf ../run/systemd/resolve/stub-resolv.conf ./mnt/etc/resolv.conf
	cp systemd/network/20-bond0.netdev ./mnt/etc/systemd/network/20-bond0.netdev
	sed 's/$${HOSTID}/${HOSTID}/g' systemd/network/20-bond0.network > ./mnt/etc/systemd/network/20-bond0.network
	cp systemd/network/20-enp-bond0.network ./mnt/etc/systemd/network/20-enp-bond0.network
	
	@echo "Setting hostname"
	echo "${HOSTNAME}${HOSTID}" > ./mnt/etc/hostname
	
	@touch $@

target/all: target/bootstrap

test/boot:
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)

	${MAKE} util/unmount-kernelfs
	${MAKE} util/unmount

	mkdir -p qemu-run
	cp /usr/share/OVMF/OVMF_VARS_4M.fd ./qemu-run/OVMF_VARS_4M.fd
	qemu-system-x86_64 -m 4g -smp 8 -enable-kvm \
		  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
		  -drive if=pflash,format=raw,file=./qemu-run/OVMF_VARS_4M.fd \
		  -drive file=${DISK},format=raw,if=none,id=disk0,cache=directsync \
		  -netdev user,id=net0 \
		  -device virtio-net-pci,netdev=net0 \
		  -device virtio-blk-pci,drive=disk0,bootindex=0

test/chroot:
	${MAKE} util/mount
	${MAKE} util/mount-kernelfs
	chroot ./mnt

test/scrub:
	${MAKE} util/mount
	btrfs scrub start -B mnt
