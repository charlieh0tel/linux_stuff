#!/bin/bash

set -o errexit
set -o nounset

PATH=/sbin:/usr/sbin:/bin:/usr/bin

LAN="$1"
INTERNET="$2"

echo -n 1 >/proc/sys/net/ipv4/ip_forward

iptables -t nat -A POSTROUTING -o "${INTERNET}" -j MASQUERADE
iptables -A FORWARD -i "${LAN}" -j ACCEPT
