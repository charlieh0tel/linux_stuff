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

if [ \! -e "${EXTPART}" ]; then
    echo "$0: ${EXTPART} does not exist" 2>&1
    exit 1
fi

partx "${DEVICE}"
sfdisk -d "${DEVICE}" > part.sfdisk
dd if="${DEVICE}" of=mbrgrub.raw count=2048 status=none
e2image -ra -p "${EXTPART}" fs.raw

exit 0
