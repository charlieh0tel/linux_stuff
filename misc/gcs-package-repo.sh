#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

PATH=/bin:/usr/bin:/sbin:/usr/sbin
CACHE=/var/cache/somewhere/packages
GCLOUD_CONFIG=/home/somebody/.config/gcloud
GCS_URL=gs://somebucket/packages

export CLOUDSDK_CONFIG="${GCLOUD_CONFIG}"

if (( EUID != 0 )); then
    echo "$0: please run as root" 2>&1
    exit 99
fi

cd "$CACHE"
gsutil -m rsync "$GCS_URL" .
dpkg-scanpackages --multiversion . /dev/null | gzip -9c > Packages.gz
