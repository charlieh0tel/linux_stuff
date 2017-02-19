#!/bin/bash

set -o errexit
set -o verbose

WHERE=$(pwd)

BUILD="${WHERE}/_build_"
INSTALL="${WHERE}/_install_"

mkdir -p "${BUILD}"
mkdir -p "${INSTALL}"

(cd _build_ && cmake -DCMAKE_INSTALL_PREFIX="${INSTALL}" ..)
(cd _build_ && make -j && make install)
