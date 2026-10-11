#!/bin/sh

set -o xtrace
set -o errexit

find . -type f -name "*.rules" -exec cp -p {} /etc/udev/rules.d +
