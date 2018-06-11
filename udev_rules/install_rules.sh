#!/bin/sh

set -o xtrace
set -o errexit

cp -p $(find -type f -name \*.rules -print) /etc/udev/rules.d
