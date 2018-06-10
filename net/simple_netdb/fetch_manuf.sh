#!/bin/sh

set -o errexit

wget 'https://code.wireshark.org/review/gitweb?p=wireshark.git;a=blob_plain;f=manuf' -O manuf.tab
