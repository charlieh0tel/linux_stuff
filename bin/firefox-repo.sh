#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /usr/share/keyrings/packages.mozilla.org.asc > /dev/null

echo "deb [signed-by=/usr/share/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null

echo 'Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | sudo tee /etc/apt/preferences.d/mozilla

echo 'Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
' | sudo tee /etc/apt/preferences.d/mozilla-block-ubuntu-firefox
