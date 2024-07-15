#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

declare -rA CHANNEL_FREQUENCY_MAP=(
    ["WX1"]="162.550M"
    ["WX2"]="162.400M"
    ["WX3"]="162.475M"
    ["WX4"]="162.425M"
    ["WX5"]="162.450M"
    ["WX6"]="162.500M"
    ["WX7"]="162.525M"
    ["WX8"]="161.650M"
    ["WX9"]="161.775M"
    ["WX10"]="163.275M"
)

declare -r RATE=11025

CHANNEL="$1"
shift

FREQUENCY="${CHANNEL_FREQUENCY_MAP["${CHANNEL}"]}"

rtl_fm "$@" -f "${FREQUENCY}" -s ${RATE} | \
    play -t raw -r "${RATE}" -es -b 16 -c 1 -V1 -

# Local Variables:
# compile-command: "shellcheck play_noaa.sh"
# End:
