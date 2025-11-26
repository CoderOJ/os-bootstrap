#!/bin/bash

cat - << EOF
title   Debian Trixie
linux   $(basename $(readlink ./mnt/vmlinuz))
initrd  $(basename $(readlink ./mnt/initrd.img))
options root=UUID=$(findmnt -no UUID ./mnt) rw console=ttyS0,115200 earlyprintk=ttyS0,115200
EOF
