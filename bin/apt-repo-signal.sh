#!/bin/bash
#
# Adds Signal's apt repository and installs Signal Desktop.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

main() {
  apt_repo::init
  apt_repo::install_key signal https://updates.signal.org/desktop/apt/keys.asc \
    DBA36B5181D0C816F630E889D980A17457F6FB06
  # Signal publishes only amd64, under the "xenial" suite for every release.
  apt_repo::write_sources signal \
    "URIs: https://updates.signal.org/desktop/apt" \
    "Suites: xenial" \
    "Components: main" \
    "Architectures: amd64"
  apt_repo::remove_legacy signal updates.signal.org/desktop/apt "*" \
    /usr/share/keyrings/signal-desktop-keyring.gpg
  apt_repo::install_packages signal-desktop
}

main "$@"
