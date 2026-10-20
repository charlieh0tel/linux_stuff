#!/bin/bash
#
# Adds the Google Cloud CLI apt repository and installs gcloud.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=apt-repo-lib.sh
source "$(dirname "$(readlink -f "$0")")/apt-repo-lib.sh"

main() {
  apt_repo::init
  apt_repo::install_key google-cloud \
    https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3
  apt_repo::write_sources google-cloud \
    "URIs: https://packages.cloud.google.com/apt" \
    "Suites: cloud-sdk" \
    "Components: main"
  # The same host serves other repositories (Coral, gcsfuse, ...), so match
  # on the suite too.
  apt_repo::remove_legacy google-cloud packages.cloud.google.com/apt \
    "cloud-sdk*" \
    /usr/share/keyrings/cloud.google.gpg \
    /usr/share/keyrings/cloud.google.asc \
    /etc/apt/keyrings/cloud.google.gpg \
    /etc/apt/keyrings/cloud.google.asc
  apt_repo::install_packages google-cloud-cli
}

main "$@"
