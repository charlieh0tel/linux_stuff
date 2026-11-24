# shellcheck shell=bash
#
# Helper for scripts that install a .deb attached to a GitHub release.  Runs
# as the user, so gh uses the user's credentials (needed for private
# repositories), and uses sudo only for apt-get.

#######################################
# Prints an error and exits.
# Arguments:
#   Message.
#######################################
gh_release_deb::die() {
  echo "${0##*/}: $*" >&2
  exit 1
}

#######################################
# Downloads PACKAGE's .deb for this host's architecture from a release of
# REPO and installs it, unless that version is already installed.
# Arguments:
#   Repository, OWNER/NAME.
#   Package name.
#   Release tag, optional; defaults to the latest release.
#######################################
gh_release_deb::install() {
  local repo="$1"
  local package="$2"
  local tag="${3:-}"

  command -v gh > /dev/null || gh_release_deb::die "gh is not installed."
  (( EUID != 0 )) || gh_release_deb::die "run as yourself, not root."

  local arch tmp
  arch="$(dpkg --print-architecture)"
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064  # Expand tmp now.
  trap "rm -rf '${tmp}'" EXIT
  # Let apt's sandbox user read the download.
  chmod 0755 "${tmp}"

  local args=(--repo "${repo}" --dir "${tmp}"
    --pattern "${package}_*_${arch}.deb")
  if [[ -n "${tag}" ]]; then
    gh release download "${tag}" "${args[@]}"
  else
    gh release download "${args[@]}"
  fi

  local debs=("${tmp}"/*.deb)
  [[ -f "${debs[0]}" ]] \
    || gh_release_deb::die "no ${package} .deb for ${arch} in ${repo}."
  (( ${#debs[@]} == 1 )) \
    || gh_release_deb::die "more than one ${package} .deb in ${repo}."
  local deb="${debs[0]}"
  chmod 0644 "${deb}"

  local name version installed
  name="$(dpkg-deb -f "${deb}" Package)"
  version="$(dpkg-deb -f "${deb}" Version)"
  [[ "${name}" == "${package}" ]] \
    || gh_release_deb::die "${deb##*/} is package ${name}, want ${package}."
  installed="$(dpkg-query -W -f='${db:Status-Abbrev} ${Version}' \
    "${package}" 2> /dev/null || true)"
  if [[ "${installed}" == "ii  ${version}" ]]; then
    echo "${package} ${version} is already installed."
    return 0
  fi

  sudo apt-get install -y "${deb}"
}
