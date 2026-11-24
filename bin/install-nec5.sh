#!/bin/bash
#
# Installs the NEC-5 Linux port from a release of charlieh0tel/NEC5.
#
# Usage: install-nec5.sh [TAG]
#
# TAG defaults to the latest release.

set -o errexit -o nounset -o pipefail

# shellcheck source-path=SCRIPTDIR source=gh-release-deb-lib.sh
source "$(dirname "$(readlink -f "$0")")/gh-release-deb-lib.sh"

main() {
  (( $# <= 1 )) || gh_release_deb::die "usage: ${0##*/} [TAG]"
  gh_release_deb::install charlieh0tel/NEC5 nec5 "$@"
}

main "$@"
