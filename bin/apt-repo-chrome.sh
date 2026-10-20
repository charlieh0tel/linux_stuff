#!/bin/bash
#
# Adds Google's Chrome apt repository and installs Chrome.
#
# Like Tailscale, Chrome manages its own repository: its maintainer scripts
# and /etc/cron.daily/google-chrome rewrite google-chrome.sources and the key
# in /usr/share/keyrings, so apt follows Google's key rotations.  This script
# bootstraps with a pinned key, makes sure that machinery is turned on, and
# checks the result.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

readonly FINGERPRINT=EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796
readonly PACKAGE_KEYRING=/usr/share/keyrings/google-chrome.gpg
readonly DEFAULTS="${APT_REPO_ROOT:-}/etc/default/google-chrome"
readonly CRON="${APT_REPO_ROOT:-}/etc/cron.daily/google-chrome"
readonly SOURCES="${APT_REPO_SOURCES}/google-chrome.sources"

#######################################
# Tells Chrome's scripts to (re)create google-chrome.sources.
#######################################
enable_repo_config() {
  install -m 0755 -d "${DEFAULTS%/*}"
  touch "${DEFAULTS}"
  sed -i '/^[[:space:]]*repo_add_once=/d; /^[[:space:]]*repo_reenable_on_distupgrade=/d' \
    "${DEFAULTS}"
  printf '%s\n' 'repo_add_once="true"' 'repo_reenable_on_distupgrade="true"' \
    >> "${DEFAULTS}"
}

main() {
  apt_repo::init

  # Old sources may name another key, which apt would reject as a conflict.
  apt_repo::remove_legacy google-chrome dl.google.com/linux/chrome/deb "*" \
    /etc/apt/trusted.gpg.d/google-chrome.gpg
  enable_repo_config

  if ! apt_repo::installed google-chrome-stable; then
    apt_repo::install_key google-chrome \
      https://dl.google.com/linux/linux_signing_key.pub "${FINGERPRINT}"
    apt_repo::write_sources google-chrome \
      "URIs: https://dl.google.com/linux/chrome-stable/deb/" \
      "Suites: stable" \
      "Components: main" \
      "Architectures: amd64"
    # The package's postinst replaces the source and key with its own.
    apt_repo::install_packages google-chrome-stable
  fi

  [[ -x "${CRON}" ]] || apt_repo::die "${CRON} is missing."
  "${CRON}"

  grep -qxF "Signed-By: ${PACKAGE_KEYRING}" "${SOURCES}" 2> /dev/null \
    || apt_repo::die "${SOURCES} is not signed by ${PACKAGE_KEYRING}."
  apt_repo::check_keyring "${APT_REPO_ROOT:-}${PACKAGE_KEYRING}" \
    "${FINGERPRINT}" || exit 1
  apt_repo::remove_unowned \
    "${APT_REPO_ROOT:-}${APT_REPO_KEYRINGS}/google-chrome.gpg"
  apt_repo::install_packages google-chrome-stable
}

main "$@"
