#!/bin/bash
#
# Adds https://github.com/charlieh0tel/apt-repo to the apt sources.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

readonly URL=https://charlieh0tel.github.io/apt-repo

main() {
  apt_repo::init
  apt_repo::install_key charlieh0tel "${URL}/public.key" \
    A913FC709FC04F202A4EECF477CD38547561F4EC
  # The repo publishes a single suite for all hosts.
  apt_repo::write_sources charlieh0tel \
    "URIs: ${URL}" \
    "Suites: bookworm" \
    "Components: main" \
    "Architectures: $(dpkg --print-architecture)"
  apt_repo::remove_legacy charlieh0tel charlieh0tel.github.io/apt-repo "*" \
    /usr/share/keyrings/charlieh0tel.gpg
  apt_repo::update
}

main "$@"
