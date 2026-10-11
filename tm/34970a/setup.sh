#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

python3 -m venv .venv

# shellcheck source=/dev/null
. .venv/bin/activate

pip3 install -r requirements.txt
