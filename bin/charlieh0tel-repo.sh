#!/bin/bash
set -o nounset -o errexit -o pipefail

# Adds https://github.com/charlieh0tel/apt-repo to the apt sources.

URL=https://charlieh0tel.github.io/apt-repo
FINGERPRINT=A913FC709FC04F202A4EECF477CD38547561F4EC
KEYRING=/etc/apt/keyrings/charlieh0tel.gpg

if [[ "$EUID" -ne 0 ]]; then
    echo "$0: run as root." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates curl gpg

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# Install only the pinned key, so extra keys in public.key are never trusted.
export GNUPGHOME="${TMP}/gnupg"
install -m 0700 -d "${GNUPGHOME}"
curl -fsSL "${URL}/public.key" | gpg --batch --quiet --import
if ! gpg --batch --list-keys "${FINGERPRINT}" > /dev/null 2>&1; then
    echo "$0: key ${FINGERPRINT} not found in ${URL}/public.key." >&2
    exit 1
fi
gpg --batch --export "${FINGERPRINT}" > "${TMP}/key.gpg"

install -m 0755 -d /etc/apt/keyrings
install -m 0644 "${TMP}/key.gpg" "${KEYRING}"

# The repo publishes a single suite for all hosts.
echo "deb [signed-by=${KEYRING}] ${URL} bookworm main" \
    > /etc/apt/sources.list.d/charlieh0tel.list

apt-get update
