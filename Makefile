clean:
	rm -rf target
	${MAKE} util/unmount-kernelfs
	${MAKE} util/unmount
	rm -rf mnt
	rm -rf qemu-run

util/mount:
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)

	mkdir -p ./mnt
	mount `lsblk -nlo PATH ${DISK} | awk 'NR==3 {print}'` ./mnt
	mkdir -p ./mnt/boot
	mount `lsblk -nlo PATH ${DISK} | awk 'NR==2 {print}'` ./mnt/boot

util/mount-kernelfs:
	mkdir -p ./mnt/dev
	mount --bind /dev  ./mnt/dev
	mkdir -p ./mnt/proc
	mount --bind /proc ./mnt/proc
	mkdir -p ./mnt/sys
	mount --bind /sys  ./mnt/sys

util/unmount:
	umount ./mnt/boot 	|| true
	umount ./mnt 		|| true

util/unmount-kernelfs:
	umount ./mnt/dev	|| true
	umount ./mnt/proc 	|| true
	umount ./mnt/sys 	|| true

target/dependency:
	apt install gdisk btrfs-progs parted dosfstools debootstrap systemd-boot qemu-system-x86 ovmf

	mkdir -p target
	@touch $@

target/partition-disk: target/dependency
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)
	@read -p "Partition ${DISK}? (y/N): " c && [ "$$c" = y ] || { echo "Canceled"; exit 1; }

	# 1. 清空磁盘分区表
	sgdisk -Z "${DISK}"
	# 2. 创建 GPT
	sgdisk -o "${DISK}"
	# 3. 创建 EFI 分区（FAT32）512MB
	sgdisk -n 1:0:+1G -t 1:EF00 -c 1:"EFI System" "${DISK}"
	# 4. 创建 Btrfs 根分区（剩余全部）
	sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux root (btrfs)" "${DISK}"
	# 重新加载分区表
	partprobe "${DISK}"

	@touch $@

target/partition-disk-ci: target/dependency
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)

	# 1. 清空磁盘分区表
	sgdisk -Z "${DISK}"
	# 2. 创建 GPT
	sgdisk -o "${DISK}"
	# 3. 创建 EFI 分区（FAT32）512MB
	sgdisk -n 1:0:+1G -t 1:EF00 -c 1:"EFI System" "${DISK}"
	# 4. 创建 Btrfs 根分区（剩余全部）
	sgdisk -n 2:0:0 -t 2:8300 -c 2:"Linux root (btrfs)" "${DISK}"
	# 重新加载分区表
	partprobe "${DISK}"
	# Wait for partitions to appear
	sleep 2
	partprobe "${DISK}"
	sleep 2

	@touch target/partition-disk

target/format-efi:
	@test "${PART_EFI}" != "" || (echo "Specify PART_EFI"; exit 1)

	@echo format ${PART_EFI} as FAT
	mkfs.fat -F32 ${PART_EFI}

	@touch $@

target/format-root:
	@test "${PART_ROOT}" != "" || (echo "Specify PART_ROOT"; exit 1)

	@echo format ${PART_EFI} as btrfs
	mkfs.btrfs -f -L "rootfs" ${PART_ROOT}

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
	debootstrap --arch=amd64 trixie ./mnt https://mirrors.tuna.tsinghua.edu.cn/debian/

	${MAKE} util/mount-kernelfs
	chroot ./mnt apt install -y -o Dpkg::Options::="--force-confnew" linux-image-amd64 cloud-init btrfs-progs openssh-client openssh-server locales


	# Configure cloud-init nocloud datasource
	mkdir -p ./mnt/var/lib/cloud/seed/nocloud
	cp cloud-init/nocloud/meta-data ./mnt/var/lib/cloud/seed/nocloud/meta-data
	cp cloud-init/nocloud/user-data ./mnt/var/lib/cloud/seed/nocloud/user-data
	cp cloud-init/nocloud/network-config ./mnt/var/lib/cloud/seed/nocloud/network-config
	cp cloud-init/99-local.cfg 	./mnt/etc/cloud/cloud.cfg.d/99-local.cfg

	@touch $@

target/systemd-boot: target/format
	bootctl --path=`realpath ./mnt/boot` install
	cp systemd-boot/loader/loader.conf mnt/boot/loader/loader.conf
	bash systemd-boot/loader/entries/debian.conf.sh > mnt/boot/loader/entries/debian.conf

target/all: target/bootstrap target/systemd-boot

test/boot: target/dependency
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)

	${MAKE} util/unmount
	${MAKE} util/unmount-kernelfs

	mkdir -p qemu-run
	cp /usr/share/OVMF/OVMF_VARS_4M.fd ./qemu-run/OVMF_VARS_4M.fd
	qemu-system-x86_64 -nographic -m 4g -smp 8 \
		  -drive if=pflash,format=raw,readonly,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
		  -drive if=pflash,format=raw,file=./qemu-run/OVMF_VARS_4M.fd \
		  -drive file=${DISK},format=raw,if=none,id=disk0,cache=none \
		  -device virtio-blk-pci,drive=disk0 \
		  -boot order=c

# CI-specific targets
target/format-ci: target/partition-disk-ci
	@test "${DISK}" != "" || (echo "Specify DISK=/dev/..."; exit 1)

	mkdir -p ./mnt
	${MAKE} target/format-root "PART_ROOT=`lsblk -nlo PATH ${DISK} | awk 'NR==3 {print}'`"
	${MAKE} target/format-efi  "PART_EFI=`lsblk -nlo PATH ${DISK} | awk 'NR==2 {print}'`"
	
	@touch target/format

target/ci-setup-ssh:
	@test -f "${SSH_PUB_KEY}" || (echo "Specify SSH_PUB_KEY=path/to/key.pub"; exit 1)
	
	mkdir -p ./mnt/home/cscg/.ssh
	cp "${SSH_PUB_KEY}" ./mnt/home/cscg/.ssh/authorized_keys
	chroot ./mnt chown -R 1000:1000 /home/cscg/.ssh
	chroot ./mnt chmod 700 /home/cscg/.ssh
	chroot ./mnt chmod 600 /home/cscg/.ssh/authorized_keys

target/ci-setup-test-script:
	@test -f test-script.sh || (echo "test-script.sh not found"; exit 1)
	
	cp test-script.sh ./mnt/home/cscg/test-script.sh
	chmod +x ./mnt/home/cscg/test-script.sh
	chroot ./mnt chown 1000:1000 /home/cscg/test-script.sh

target/bootstrap-ci: target/subvolume
	debootstrap --arch=amd64 trixie ./mnt https://mirrors.tuna.tsinghua.edu.cn/debian/

	${MAKE} util/mount-kernelfs
	chroot ./mnt apt install -y -o Dpkg::Options::="--force-confnew" linux-image-amd64 cloud-init btrfs-progs openssh-client openssh-server locales

	# Configure cloud-init nocloud datasource (use CI config if available)
	mkdir -p ./mnt/var/lib/cloud/seed/nocloud
	cp cloud-init/nocloud/meta-data ./mnt/var/lib/cloud/seed/nocloud/meta-data
	cp cloud-init/nocloud/user-data ./mnt/var/lib/cloud/seed/nocloud/user-data
	if [ -f cloud-init/nocloud/network-config.ci ]; then \
		cp cloud-init/nocloud/network-config.ci ./mnt/var/lib/cloud/seed/nocloud/network-config; \
	else \
		cp cloud-init/nocloud/network-config ./mnt/var/lib/cloud/seed/nocloud/network-config; \
	fi
	cp cloud-init/99-local.cfg 	./mnt/etc/cloud/cloud.cfg.d/99-local.cfg

	@touch target/bootstrap

target/all-ci: target/bootstrap-ci target/systemd-boot target/ci-setup-ssh target/ci-setup-test-script

