#!/bin/bash
#
# Adds Docker's apt repository and installs Docker CE in place of the
# distribution's packages.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

main() {
  apt_repo::init

  local codename
  codename="$(apt_repo::codename)"
  case "${codename}" in
    jammy | noble | plucky | questing | resolute) ;;
    *) apt_repo::die "unsupported codename '${codename}'." ;;
  esac

  local pkg
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 \
    podman-docker containerd runc; do
    apt-get remove -y "${pkg}" || true
  done

  apt_repo::install_key docker https://download.docker.com/linux/ubuntu/gpg \
    9DC858229FC7DD38854AE2D88D81803C0EBFCD88
  apt_repo::write_sources docker \
    "URIs: https://download.docker.com/linux/ubuntu" \
    "Suites: ${codename}" \
    "Components: stable" \
    "Architectures: $(dpkg --print-architecture)"
  apt_repo::remove_legacy docker download.docker.com/linux/ubuntu "*" \
    /etc/apt/keyrings/docker.asc \
    /usr/share/keyrings/docker.gpg \
    /usr/share/keyrings/docker-archive-keyring.gpg
  apt_repo::install_packages docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
}

main "$@"
