#!/bin/bash
#
# Installs Chrome and makes sure Chrome's own repository setup is on.
#
# Chrome manages its repository itself: its maintainer scripts and
# /etc/cron.daily/google-chrome own google-chrome.sources and the key in
# /usr/share/keyrings, and follow Google's key rotations.  This script never
# touches those.  It only sets repo_add_once in /etc/default/google-chrome,
# the switch Chrome documents for re-adding the repository, and runs Chrome's
# cron job.  A fresh install bootstraps from a pinned key under a separate
# name, removed once Chrome's package has set up its own.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

readonly BOOTSTRAP=google-chrome-bootstrap
readonly FINGERPRINT=EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796
readonly DEFAULTS="${APT_REPO_ROOT:-}/etc/default/google-chrome"
readonly CRON="${APT_REPO_ROOT:-}/etc/cron.daily/google-chrome"
readonly SOURCES="${APT_REPO_SOURCES}/google-chrome.sources"

#######################################
# Sets repo_add_once="true" so Chrome's scripts (re)create its source.
#######################################
request_repo() {
  if [[ -f "${DEFAULTS}" ]] && grep -q '^[[:space:]]*repo_add_once=' "${DEFAULTS}"; then
    sed -i 's/^[[:space:]]*repo_add_once=.*/repo_add_once="true"/' "${DEFAULTS}"
  else
    install -m 0755 -d "${DEFAULTS%/*}"
    echo 'repo_add_once="true"' >> "${DEFAULTS}"
  fi
}

main() {
  apt_repo::init
  request_repo

  if ! apt_repo::installed google-chrome-stable; then
    apt_repo::install_key "${BOOTSTRAP}" \
      https://dl.google.com/linux/linux_signing_key.pub "${FINGERPRINT}"
    apt_repo::write_sources "${BOOTSTRAP}" \
      "URIs: https://dl.google.com/linux/chrome-stable/deb/" \
      "Suites: stable" \
      "Components: main" \
      "Architectures: amd64"
    apt_repo::install_packages google-chrome-stable
    rm -f "${APT_REPO_SOURCES}/${BOOTSTRAP}.sources" \
      "${APT_REPO_ROOT:-}${APT_REPO_KEYRINGS}/${BOOTSTRAP}.gpg"
  fi

  [[ -x "${CRON}" ]] || apt_repo::die "${CRON} is missing."
  "${CRON}"
  [[ -f "${SOURCES}" ]] \
    || apt_repo::die "Chrome's scripts did not create ${SOURCES}."

  apt_repo::install_packages google-chrome-stable
}

main "$@"
