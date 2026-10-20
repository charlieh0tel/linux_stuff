#!/bin/bash
#
# Adds Netdata's stable apt repository and installs netdata with Netdata
# Cloud and anonymous statistics turned off.
#
# Usage: apt-repo-netdata.sh [--reset]
#   --reset  purge netdata and its config and data first

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

readonly ETC="${APT_REPO_ROOT:-}/etc/netdata"
readonly VAR="${APT_REPO_ROOT:-}/var/lib/netdata"
readonly CLOUD_DIR="${ETC}/cloud.d"
readonly CLOUD_CONF="${CLOUD_DIR}/cloud.conf"

main() {
  local reset=0
  case "${1:-}" in
    "") ;;
    --reset) reset=1 ;;
    *) apt_repo::die "usage: ${0##*/} [--reset]" ;;
  esac

  apt_repo::init

  local id codename
  id="$(apt_repo::os_release ID)"
  if [[ "${id}" == raspbian ]]; then
    id="$(apt_repo::os_release ID_LIKE)"
  fi
  codename="$(apt_repo::codename)"

  apt_repo::install_key netdata https://repo.netdata.cloud/netdatabot.gpg.key \
    6E155DC153906B73765A74A99DD4A74CECFA8F4F
  # A flat repository: the suite is a path and there are no components.
  apt_repo::write_sources netdata \
    "URIs: https://repo.netdata.cloud/repos/stable/${id}/" \
    "Suites: ${codename}/"
  apt_repo::remove_legacy netdata "repo.netdata.cloud/repos/stable/${id}" "*" \
    /usr/share/keyrings/netdata-keyring.gpg \
    /usr/share/keyrings/netdata-archive-keyring.gpg
  apt_repo::remove_legacy netdata "repo.netdata.cloud/repos/edge/${id}" "*"
  apt_repo::remove_legacy netdata "packagecloud.io/netdata/netdata/${id}" "*"

  if (( reset )); then
    apt-get purge -y 'netdata*' < /dev/null
    rm -rf "${VAR}" "${ETC}"
  fi
  apt_repo::install_packages netdata

  # netdata owns cloud.d, so never write through a path in it: build the file
  # as root and let install replace whatever is there, symlinks included.
  install -m 0775 -o netdata -g netdata -d "${CLOUD_DIR}"
  cat > "${APT_REPO_TMP}/cloud.conf" << 'EOF'
[global]
  enabled = no
EOF
  install -m 0664 -o netdata -g netdata "${APT_REPO_TMP}/cloud.conf" \
    "${CLOUD_CONF}"
  touch "${ETC}/.opt-out-from-anonymous-statistics"

  systemctl restart netdata
}

main "$@"
