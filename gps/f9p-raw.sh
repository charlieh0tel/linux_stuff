#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

export UBXOPTS="-P 22"

gpsctl -s 460800

ubxtool -d NMEA
ubxtool -e BINARY

ubxtool -d GLONASS
ubxtool -d BEIDOU
ubxtool -d GALILEO
ubxtool -d SBAS
ubxtool -e GPS


ubxtool -p CFG-GNSS

ubxtool -e RAWX

FILE="gps-raw-$(date +%Y%m%d).obs"

gpsrinex -i 30 -n 2880 -f "${FILE}"