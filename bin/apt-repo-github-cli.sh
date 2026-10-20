#!/bin/bash
#
# Adds the GitHub CLI apt repository and installs gh.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

main() {
  apt_repo::init
  apt_repo::install_key github-cli \
    https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    7F38BBB59D064DBCB3D84D725612B36462313325
  apt_repo::write_sources github-cli \
    "URIs: https://cli.github.com/packages" \
    "Suites: stable" \
    "Components: main" \
    "Architectures: $(dpkg --print-architecture)"
  apt_repo::remove_legacy github-cli cli.github.com/packages "*" \
    /usr/share/keyrings/githubcli-archive-keyring.gpg \
    /etc/apt/keyrings/githubcli-archive-keyring.gpg
  apt_repo::install_packages gh
}

main "$@"
