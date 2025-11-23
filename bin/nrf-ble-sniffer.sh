#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

rm -fr "${HOME}/.nrfutil" 2>/dev/null

curl 'https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/x86_64-unknown-linux-gnu/nrfutil' -o /tmp/nrfutil 
chmod +x /tmp/nrfutil
/tmp/nrfutil

PATH=$HOME/.nrfutil/bin:$PATH
nrfutil install device
nrfutil install ble-sniffer
nrfutil device list
#nrfutil device program --traits nordicUsb --firmware "${HOME}/.nrfutil/share/nrfutil-ble-sniffer/firmware/sniffer_nrf52840dongle_nrf52840_4.1.1.zip"
mkdir -p "${HOME}/.local/lib/wireshark/extcap"
nrfutil ble-sniffer bootstrap
nrfutil install completion
nrfutil completion install bash
