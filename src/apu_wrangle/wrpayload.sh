#!/bin/bash                                                                     

set -o errexit

export PATH=/sbin:/usr/sbin:/bin:/usr/bin
export LOCALE=C

DEVICE="$1"
EXTPART="${DEVICE}${2:-1}"

if [ -z "${DEVICE}" ]; then
    echo "usage: $0 device [extpart]" 2>&1
    exit 1
fi

if [ \! -e "${DEVICE}" ]; then
    echo "$0: ${DEVICE} does not exist" 2>&1
    exit 1
fi

echo "Erasing."
blockdev --flushbufs "${DEVICE}"
hdparm --user-master u --security-disable pass "${DEVICE}" 2>/dev/null || :;
hdparm --user-master u --security-set-pass pass "${DEVICE}"
hdparm --user-master u --security-erase-enhanced pass "${DEVICE}" 
hdparm --user-master u --security-disable pass "${DEVICE}" 2>/dev/null || :;

echo "Unplug and replug the drive."
read dummy

if [ \! -e "${DEVICE}" ]; then
    echo "$0: ${DEVICE} does not exist" 2>&1
    exit 1
fi

# Write mbr/grub.
echo "Writing MBR."
dd if=mbrgrub.raw of="${DEVICE}" status=none

echo "Writing part table."
sfdisk --no-tell-kernel "${DEVICE}" < part.sfdisk


blockdev --rereadpt "${DEVICE}"

if [ \! -e "${EXTPART}" ]; then
    echo "$0: ${EXTPART} does not exist" 2>&1
    exit 1
fi

e2image -ra -p fs.raw "${EXTPART}"

exit 0
