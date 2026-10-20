#!/bin/bash
#
# Adds Tailscale's apt repository and installs tailscale.
#
# Unlike the other apt-repo scripts, the repository ends up signed by the key
# that the tailscale-archive-keyring package installs, so apt follows
# Tailscale's key rotations.  A pinned copy is used only to bootstrap.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

readonly FINGERPRINT=2596A99EAAB33821893C0A79458CA832957F5868
readonly PACKAGE_KEYRING=/usr/share/keyrings/tailscale-archive-keyring.gpg

main() {
  apt_repo::init

  local codename
  codename="$(apt_repo::codename)"
  local fields=(
    "URIs: https://pkgs.tailscale.com/stable/ubuntu"
    "Suites: ${codename}"
    "Components: main"
  )

  # Old sources may name another key, which apt would reject as a conflict.
  apt_repo::remove_legacy tailscale pkgs.tailscale.com/stable/ubuntu "*"

  if ! apt_repo::installed tailscale-archive-keyring; then
    apt_repo::install_key tailscale \
      "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
      "${FINGERPRINT}"
    apt_repo::write_sources tailscale "${fields[@]}"
    apt_repo::install_packages tailscale-archive-keyring
  fi

  apt_repo::check_keyring "${APT_REPO_ROOT:-}${PACKAGE_KEYRING}" \
    "${FINGERPRINT}" || exit 1
  apt_repo::write_sources tailscale "${fields[@]}" \
    "Signed-By: ${PACKAGE_KEYRING}"
  apt_repo::remove_unowned \
    "${APT_REPO_ROOT:-}${APT_REPO_KEYRINGS}/tailscale.gpg"
  apt_repo::install_packages tailscale
}

main "$@"
