#!/bin/bash
#
# Reinstalls netdata from Netdata's stable repository, with cloud and
# anonymous statistics turned off.

set -o errexit -o nounset -o pipefail

readonly CLOUD_DIR=/etc/netdata/cloud.d
readonly CLOUD_CONF="${CLOUD_DIR}/cloud.conf"

main() {
  if (( EUID != 0 )); then
    echo "${0##*/}: run as root." >&2
    exit 1
  fi
  export DEBIAN_FRONTEND=noninteractive

  "$(dirname "$(readlink -f "$0")")/apt-repo-netdata.sh"

  set -o xtrace

  apt-get purge -y 'netdata*' < /dev/null
  rm -rf /var/lib/netdata /etc/netdata

  apt-get install -y netdata

  mkdir -p "${CLOUD_DIR}"
  cat << 'EOF' > "${CLOUD_CONF}"
[global]
  enabled = no
EOF
  chown -R netdata:netdata "${CLOUD_DIR}"
  chmod 0775 "${CLOUD_DIR}"
  chmod 0664 "${CLOUD_CONF}"

  touch /etc/netdata/.opt-out-from-anonymous-statistics

  systemctl restart netdata
}

main "$@"
