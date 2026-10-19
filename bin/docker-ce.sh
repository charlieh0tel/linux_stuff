#!/bin/bash
set -o nounset -o errexit -o pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "$0: run as root." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

for pkg in docker.io docker-doc docker-compose docker-compose-v2 \
           podman-docker containerd runc; do
    apt-get remove -y "${pkg}" || true
done

apt-get update
apt-get install -y ca-certificates curl

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# shellcheck source=/dev/null
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"

case "${CODENAME}" in
    jammy|noble|plucky|questing|resolute) ;;
    *) echo "$0: unsupported codename '${CODENAME}'." >&2; exit 1 ;;
esac

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
