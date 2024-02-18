#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

. /etc/os-release

KEYRING="/usr/share/keyrings/netdata-keyring.gpg"

curl https://repo.netdata.cloud/netdatabot.gpg.key | gpg --dearmor > "${KEYRING}"  || :;

cat <<EOF >/etc/apt/sources.list.d/netdata.list 
deb [signed-by=${KEYRING}] https://repo.netdata.cloud/repos/stable/${ID}/ ${VERSION_CODENAME}/
EOF

set -o xtrace

apt update

apt purge -y netdata\* </dev/null
rm -fr /var/lib/netdata
rm -fr /etc/netdata

apt install -y netdata

CLOUD_DIR="/etc/netdata/cloud.d"
CLOUD_CONF="${CLOUD_DIR}/cloud.conf"
mkdir -p "${CLOUD_DIR}"
cat <<EOF >"${CLOUD_CONF}"
[global]
  enabled = no
EOF
chown -R netdata:netdata "${CLOUD_DIR}"
chmod 0775 "${CLOUD_DIR}"
chmod 0664 "${CLOUD_CONF}"

systemctl restart netdata
