#!/bin/bash
#
# Adds Netdata's stable apt repository.  sbin/install-netdata.sh installs
# and configures netdata from it.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

main() {
  apt_repo::init

  local id codename
  id="$(
    # shellcheck source=/dev/null
    . /etc/os-release
    if [[ "${ID}" == raspbian ]]; then
      echo "${ID_LIKE}"
    else
      echo "${ID}"
    fi
  )"
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
  apt_repo::update
}

main "$@"
