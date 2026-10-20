#!/bin/bash
#
# Adds Mozilla's apt repository and installs Firefox from it in place of
# Ubuntu's snap transition package.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

readonly PREFERENCES="${APT_REPO_ROOT:-}/etc/apt/preferences.d"

main() {
  apt_repo::init
  apt_repo::install_key mozilla \
    https://packages.mozilla.org/apt/repo-signing-key.gpg \
    35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3
  apt_repo::write_sources mozilla \
    "URIs: https://packages.mozilla.org/apt" \
    "Suites: mozilla" \
    "Components: main"
  apt_repo::remove_legacy mozilla packages.mozilla.org/apt "*" \
    /usr/share/keyrings/packages.mozilla.org.asc \
    /etc/apt/keyrings/packages.mozilla.org.asc

  install -m 0755 -d "${PREFERENCES}"
  cat > "${PREFERENCES}/mozilla" << 'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
  cat > "${PREFERENCES}/mozilla-block-ubuntu-firefox" << 'EOF'
Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
EOF
  chmod 0644 "${PREFERENCES}/mozilla" \
    "${PREFERENCES}/mozilla-block-ubuntu-firefox"

  apt_repo::install_packages firefox
}

main "$@"
