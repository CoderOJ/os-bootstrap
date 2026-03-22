#!/bin/bash

cat - << EOF
title   Debian ${DEBIAN_VERSION:-trixie}
linux   $(basename $(readlink ./mnt/vmlinuz))
initrd  $(basename $(readlink ./mnt/initrd.img))
options root=UUID=$(findmnt -no UUID ./mnt) rw console=tty0 console=ttyS0,115200 earlycon=uart,io,0x3f8,115200
EOF
