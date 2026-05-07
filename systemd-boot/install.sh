#!/usr/bin/env bash
set -euo pipefail

MNT="${1:-./mnt}"
LOADER_CONF="${2:-systemd-boot/loader/loader.conf}"
ENTRY_TOKEN="${ENTRY_TOKEN:-cscg-debian}"

ROOT_UUID="$(findmnt -no UUID "$MNT")"

clear_loader_entries() {
	local entries_dir="$MNT/boot/loader/entries"

	mkdir -p "$entries_dir"
	rm -f "$entries_dir"/*.conf
}

mkdir -p "$MNT/etc/kernel"

cat > "$MNT/etc/kernel/install.conf" <<EOF
layout=bls
BOOT_ROOT=/boot
EOF

cat > "$MNT/etc/kernel/entry-token" <<EOF
${ENTRY_TOKEN}
EOF

cat > "$MNT/etc/kernel/cmdline" <<EOF
root=UUID=${ROOT_UUID} rw console=ttyS0,115200 earlycon=uart,io,0x3f8,115200
EOF

chroot "$MNT" bootctl --path=/boot --no-variables install
cp "$LOADER_CONF" "$MNT/boot/loader/loader.conf"
clear_loader_entries

shopt -s nullglob
kernels=("$MNT"/boot/vmlinuz-*)

if ((${#kernels[@]} == 0)); then
	echo "No kernels found in $MNT/boot"
	exit 1
fi

for kernel in "${kernels[@]}"; do
	version="${kernel##*/vmlinuz-}"
	initrd="/boot/initrd.img-${version}"

	if [[ -e "$MNT$initrd" ]]; then
		chroot "$MNT" kernel-install add "$version" "/boot/vmlinuz-${version}" "$initrd"
	else
		chroot "$MNT" kernel-install add "$version" "/boot/vmlinuz-${version}"
	fi
done
