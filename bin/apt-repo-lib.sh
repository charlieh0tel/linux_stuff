# shellcheck shell=bash
#
# Helpers for the apt-repo-*.sh scripts.  Each third-party repository gets a
# pinned key in /etc/apt/keyrings/NAME.gpg and a deb822 source in
# /etc/apt/sources.list.d/NAME.sources that is signed by only that key.

#
# APT_REPO_ROOT, normally unset, moves every file the helpers touch under a
# test tree.  Paths written into sources stay real.

readonly APT_REPO_KEYRINGS=/etc/apt/keyrings
readonly APT_REPO_SOURCES="${APT_REPO_ROOT:-}/etc/apt/sources.list.d"
readonly APT_REPO_LIST="${APT_REPO_ROOT:-}/etc/apt/sources.list"
readonly APT_REPO_MAX_KEY_BYTES=1048576

#######################################
# Prints an error and exits.
# Arguments:
#   Message.
#######################################
apt_repo::die() {
  echo "${0##*/}: $*" >&2
  exit 1
}

#######################################
# Succeeds if PACKAGE is installed.
# Arguments:
#   Package.
#######################################
apt_repo::installed() {
  [[ "$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2> /dev/null)" == ii* ]]
}

#######################################
# Checks for root, creates a scratch directory and installs the tools the
# other helpers need.
# Globals:
#   APT_REPO_TMP (set)
#######################################
apt_repo::init() {
  (( EUID == 0 )) || apt_repo::die "run as root."
  umask 022
  export DEBIAN_FRONTEND=noninteractive
  export LC_ALL=C

  APT_REPO_TMP="$(mktemp -d)"
  readonly APT_REPO_TMP
  trap 'rm -rf "${APT_REPO_TMP}"' EXIT

  local pkg
  local missing=()
  for pkg in ca-certificates curl gpg; do
    apt_repo::installed "${pkg}" || missing+=("${pkg}")
  done
  if (( ${#missing[@]} > 0 )); then
    apt-get update
    apt-get install -y "${missing[@]}"
  fi
}

#######################################
# Prints a field from /etc/os-release, read in a clean environment so the
# caller's variables cannot interfere.
# Arguments:
#   Field name, e.g. ID.
#######################################
apt_repo::os_release() {
  local value
  # shellcheck disable=SC2016  # The inner bash expands it.
  value="$(env -i bash -c '. /etc/os-release && printf "%s" "${!1:-}"' \
    _ "$1")" || apt_repo::die "cannot read /etc/os-release."
  printf '%s\n' "${value}"
}

#######################################
# Prints the Ubuntu (or Debian) codename of this host.
#######################################
apt_repo::codename() {
  local codename
  codename="$(apt_repo::os_release UBUNTU_CODENAME)"
  [[ -n "${codename}" ]] || codename="$(apt_repo::os_release VERSION_CODENAME)"
  [[ -n "${codename}" ]] || apt_repo::die "no codename in /etc/os-release."
  printf '%s\n' "${codename}"
}

#######################################
# Checks that KEYRING holds exactly the primary keys FINGERPRINTS, none of
# them expired or revoked.
# Arguments:
#   Keyring file.
#   Fingerprints, one or more.
#######################################
apt_repo::check_keyring() {
  local keyring="$1"
  shift
  local want got bad
  want="$(printf '%s\n' "$@" | sort)"
  got="$(gpg --show-keys --with-colons "${keyring}" \
    | awk -F: '$1 == "pub" { want = 1; next }
               $1 == "fpr" && want { print $10; want = 0 }' | sort)"
  if [[ "${got}" != "${want}" ]]; then
    apt_repo::die "${keyring}: primary keys are ${got//$'\n'/ }," \
      "want $*."
  fi
  bad="$(gpg --show-keys --with-colons "${keyring}" \
    | awk -F: '$1 == "pub" && $2 ~ /[er]/ { print $5 }')"
  [[ -z "${bad}" ]] \
    || apt_repo::die "${keyring}: expired or revoked: ${bad//$'\n'/ }."
}

#######################################
# Downloads the key at URL and installs only the pinned primary keys as
# /etc/apt/keyrings/NAME.gpg, so extra keys in the download are never
# trusted.
# Arguments:
#   Repository name.
#   Key URL, https only.
#   Fingerprints, one or more.
#######################################
apt_repo::install_key() {
  local name="$1"
  local url="$2"
  shift 2
  local fpr
  for fpr in "$@"; do
    [[ "${fpr}" =~ ^[0-9A-F]{40}$ ]] || apt_repo::die "bad fingerprint ${fpr}."
  done

  local gnupghome="${APT_REPO_TMP}/gnupg-${name}"
  local raw="${APT_REPO_TMP}/${name}.raw"
  local key="${APT_REPO_TMP}/${name}.gpg"
  install -m 0700 -d "${gnupghome}"
  curl -fsSL --proto '=https' --tlsv1.2 \
    --max-filesize "${APT_REPO_MAX_KEY_BYTES}" "${url}" -o "${raw}" \
    || apt_repo::die "cannot fetch ${url}."
  GNUPGHOME="${gnupghome}" gpg --batch --quiet --import "${raw}" \
    || apt_repo::die "no keys in ${url}."
  # Export whole keys, since repositories often sign with a subkey.  A pinned
  # fingerprint that is itself a subkey drags in a primary that
  # check_keyring then rejects.
  GNUPGHOME="${gnupghome}" gpg --batch --export \
    --export-options export-minimal "$@" > "${key}"
  apt_repo::check_keyring "${key}" "$@" || exit 1

  local dir="${APT_REPO_ROOT:-}${APT_REPO_KEYRINGS}"
  install -m 0755 -d "${dir}"
  install -m 0644 "${key}" "${dir}/${name}.gpg.new"
  mv -f "${dir}/${name}.gpg.new" "${dir}/${name}.gpg"
}

#######################################
# Writes /etc/apt/sources.list.d/NAME.sources.  Signed-By defaults to
# /etc/apt/keyrings/NAME.gpg.
# Arguments:
#   Repository name.
#   deb822 fields, one per argument, e.g. "Suites: stable".
#######################################
apt_repo::write_sources() {
  local name="$1"
  shift
  local file="${APT_REPO_SOURCES}/${name}.sources"
  local field signed_by="${APT_REPO_KEYRINGS}/${name}.gpg"
  for field in "$@"; do
    [[ "${field}" == Signed-By:* ]] && signed_by=""
  done
  {
    echo "Types: deb"
    printf '%s\n' "$@"
    [[ -z "${signed_by}" ]] || echo "Signed-By: ${signed_by}"
  } > "${file}.new"
  chmod 0644 "${file}.new"
  mv -f "${file}.new" "${file}"
}

#######################################
# Prints the keyring paths a source file names in signed-by or Signed-By.
# Arguments:
#   Source file.
#######################################
apt_repo::signed_by_paths() {
  grep -ohE 'signed-by=[^] ]+|^Signed-By:[[:space:]]*/[^[:space:]]+' "$1" \
    | sed -E 's/^(signed-by=|Signed-By:[[:space:]]*)//' | tr ',' '\n' \
    | grep '^/' || true
}

#######################################
# Removes PATH unless a package owns it.
# Arguments:
#   Path.
#######################################
apt_repo::remove_unowned() {
  local path="$1"
  [[ -e "${path}" || -L "${path}" ]] || return 0
  if dpkg -S "${path#"${APT_REPO_ROOT:-}"}" > /dev/null 2>&1; then
    echo "${0##*/}: keeping ${path}, owned by a package." >&2
    return 0
  fi
  echo "${0##*/}: removing ${path}." >&2
  rm -f "${path}"
}

#######################################
# Prints "URI SUITE" for every entry in a source file, one-line or deb822,
# enabled or not.  URIs lose their scheme and trailing slash.
# Arguments:
#   Source file.
#######################################
apt_repo::entries() {
  awk '
    function flush(  i, j, nu, ns, u, s) {
      nu = split(uris, u, " ")
      ns = split(suites, s, " ")
      for (i = 1; i <= nu; i++)
        for (j = 1; j <= ns; j++)
          print u[i], s[j]
      uris = suites = ""
    }
    /^[#[:space:]]*deb(-src)?[[:space:]]/ {
      line = $0
      sub(/^[#[:space:]]*/, "", line)
      gsub(/\[[^]]*\]/, "", line)
      split(line, f, " ")
      print f[2], f[3]
      next
    }
    /^[[:space:]]*$/ { flush(); next }
    /^[#[:space:]]*URIs:/ { sub(/^[#[:space:]]*URIs:/, ""); uris = $0; next }
    /^[#[:space:]]*Suites:/ { sub(/^[#[:space:]]*Suites:/, ""); suites = $0 }
    END { flush() }
  ' "$1" | sed -E 's|^[a-z+]+://||; s|/+ | |'
}

#######################################
# Prints a summary of how a source file's entries compare to a repository:
# "none", "all" or "some".
# Arguments:
#   Source file.
#   URI without scheme or trailing slash.
#   Suite glob.
#######################################
apt_repo::match_file() {
  local file="$1"
  local want_uri="$2"
  local want_suite="$3"
  local uri suite hit=0 miss=0
  while read -r uri suite; do
    # shellcheck disable=SC2053  # want_suite is a glob.
    if [[ "${uri}" == "${want_uri}" && "${suite}" == ${want_suite} ]]; then
      hit=$((hit + 1))
    else
      miss=$((miss + 1))
    fi
  done < <(apt_repo::entries "${file}")
  if (( hit == 0 )); then
    echo none
  elif (( miss == 0 )); then
    echo all
  else
    echo some
  fi
}

#######################################
# Cleans up whatever earlier setups of this repository left behind:
#   - files in sources.list.d whose entries are all for this repository,
#     including disabled entries and ~, .save and .distUpgrade copies;
#   - the keyrings those files named, plus KEYS, once no source uses them;
#   - entries in sources.list, which are commented out.
# Files owned by a package are left alone, as are files that mix in other
# repositories.
# Arguments:
#   Repository name.
#   URI without scheme or trailing slash.
#   Suite glob, e.g. "*" or "cloud-sdk*".
#   Other old keyring paths, zero or more.
#######################################
apt_repo::remove_legacy() {
  local name="$1"
  local want_uri="$2"
  local want_suite="$3"
  shift 3
  local keep_source="${APT_REPO_SOURCES}/${name}.sources"
  local keep_key="${APT_REPO_KEYRINGS}/${name}.gpg"
  local keys=("$@")
  local file

  for file in "${APT_REPO_SOURCES}"/*; do
    [[ -f "${file}" && "${file}" != "${keep_source}" ]] || continue
    case "$(apt_repo::match_file "${file}" "${want_uri}" "${want_suite}")" in
      none) continue ;;
      some)
        echo "${0##*/}: ${file} mixes in other repositories; fix by hand." >&2
        continue
        ;;
    esac
    mapfile -t -O "${#keys[@]}" keys < <(apt_repo::signed_by_paths "${file}")
    apt_repo::remove_unowned "${file}"
  done

  local list="${APT_REPO_LIST}"
  if [[ -f "${list}" ]]; then
    local line uri suite changed=0
    : > "${list}.new"
    while IFS= read -r line || [[ -n "${line}" ]]; do
      if [[ "${line}" =~ ^[[:space:]]*deb ]]; then
        read -r uri suite < <(apt_repo::entries <(printf '%s\n' "${line}"))
        # shellcheck disable=SC2053  # want_suite is a glob.
        if [[ "${uri}" == "${want_uri}" && "${suite}" == ${want_suite} ]]; then
          mapfile -t -O "${#keys[@]}" keys \
            < <(apt_repo::signed_by_paths <(printf '%s\n' "${line}"))
          line="# ${line}"
          changed=1
        fi
      fi
      printf '%s\n' "${line}" >> "${list}.new"
    done < "${list}"
    if (( changed )); then
      echo "${0##*/}: commenting out ${want_uri} in ${list}." >&2
      cp -p "${list}" "${list}.bak"
      chmod 0644 "${list}.new"
      mv -f "${list}.new" "${list}"
    else
      rm -f "${list}.new"
    fi
  fi

  local key
  for key in "${keys[@]}"; do
    [[ "${key}" != "${keep_key}" ]] || continue
    # Not grep -q: under pipefail, its early exit would fail the pipeline
    # and make a key in use look unused.
    if grep -E '^[[:space:]]*deb|^Signed-By:' -r -s -h \
        "${list}" "${APT_REPO_SOURCES}" | grep -F -- "${key}" > /dev/null; then
      echo "${0##*/}: keeping ${key}, still used by a source." >&2
      continue
    fi
    apt_repo::remove_unowned "${APT_REPO_ROOT:-}${key}"
  done
}

#######################################
# Updates the package lists.
#######################################
apt_repo::update() {
  apt-get update
}

#######################################
# Updates the package lists and installs PACKAGES.
# Arguments:
#   Packages, one or more.
#######################################
apt_repo::install_packages() {
  apt_repo::update
  apt-get install -y "$@"
}
