#!/bin/sh

set -o xtrace
set -o errexit

find . -type f -name "*.rules" -exec cp -p -t /etc/udev/rules.d {} +
