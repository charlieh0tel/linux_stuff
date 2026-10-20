#!/bin/bash
#
# Adds the KiCad 10.0 releases PPA and installs kicad from it, replacing any
# earlier KiCad PPA and any KiCad packages from Ubuntu's archive.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

readonly KICAD_VERSION=10.0
readonly OLD_VERSIONS=(5.1 6.0 7.0 8.0 9.0 10.0)
readonly ORIGIN="LP-PPA-kicad-kicad-${KICAD_VERSION}-releases"
readonly PREFERENCES="${APT_REPO_ROOT:-}/etc/apt/preferences.d/kicad"

#######################################
# Prints the installed kicad* packages.
#######################################
installed_kicad() {
  dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'kicad*' 2> /dev/null \
    | awk '$1 == "ii" { print $2 }'
}

#######################################
# Succeeds if the installed version of PACKAGE comes from the PPA.
# Arguments:
#   Package.
#######################################
from_ppa() {
  apt-cache policy "$1" \
    | awk -v ppa="/kicad/kicad-${KICAD_VERSION}-releases/" '
        /^ \*\*\* / { mine = 1; next }
        mine && /^     [^ ]/ { mine = 0 }
        mine && index($0, ppa) { found = 1 }
        END { exit !found }'
}

main() {
  apt_repo::init

  local codename
  codename="$(apt_repo::codename)"

  # Every KiCad PPA is signed by the same Launchpad PPA key.
  apt_repo::install_key kicad \
    "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xFDA854F61C4D0D9572BB95E5245D5502FAD7A805" \
    FDA854F61C4D0D9572BB95E5245D5502FAD7A805
  apt_repo::write_sources kicad \
    "URIs: https://ppa.launchpadcontent.net/kicad/kicad-${KICAD_VERSION}-releases/ubuntu" \
    "Suites: ${codename}" \
    "Components: main"

  local version host
  for version in "${OLD_VERSIONS[@]}"; do
    for host in ppa.launchpadcontent.net ppa.launchpad.net; do
      apt_repo::remove_legacy kicad \
        "${host}/kicad/kicad-${version}-releases/ubuntu" "*" \
        "/etc/apt/trusted.gpg.d/kicad-ubuntu-kicad-${version/./_}-releases.gpg" \
        "/etc/apt/trusted.gpg.d/kicad-ubuntu-kicad-${version/./_}-releases.gpg~"
    done
  done

  # Take kicad* only from the PPA, never from Ubuntu.
  install -m 0755 -d "${PREFERENCES%/*}"
  cat > "${PREFERENCES}" << EOF
Package: kicad*
Pin: release o=${ORIGIN}
Pin-Priority: 1000

Package: kicad*
Pin: release o=Ubuntu
Pin-Priority: -1
EOF
  chmod 0644 "${PREFERENCES}"
  apt_repo::update

  # Switch installed kicad* packages to the PPA, and purge those only Ubuntu
  # has.
  local pkg candidate
  local switch=() purge=()
  while read -r pkg; do
    candidate="$(apt-cache policy "${pkg}" | awk '/Candidate:/ { print $2 }')"
    if [[ -z "${candidate}" || "${candidate}" == "(none)" ]]; then
      purge+=("${pkg}")
    elif [[ "${pkg}" != kicad ]]; then
      switch+=("${pkg}")
    fi
  done < <(installed_kicad)
  if (( ${#purge[@]} > 0 )); then
    apt-get purge -y "${purge[@]}"
  fi
  apt-get install -y kicad "${switch[@]}"

  local left=()
  while read -r pkg; do
    from_ppa "${pkg}" || left+=("${pkg}")
  done < <(installed_kicad)
  if (( ${#left[@]} > 0 )); then
    apt_repo::die "not from the PPA: ${left[*]}."
  fi
}

main "$@"
