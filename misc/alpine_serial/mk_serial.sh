#!/bin/bash

HERE="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

xorriso \
    -indev "$1" -outdev "$2" \
    -compliance no_emul_toc \
    -update "${HERE}/syslinux.cfg"  /boot/syslinux/syslinux.cfg \
    -update "${HERE}/grub.cfg" /boot/grub/grub.cfg \
    -boot_image any replay \
