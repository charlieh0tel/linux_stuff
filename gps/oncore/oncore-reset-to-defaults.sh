#!/bin/bash

ONCORE_SET_TO_DEFAULTS=$'\x40\x40\x43\x66\x25\x0d\x0a'

for x in 1200 2400 4800 9600 19200 38400 57600 115200; do
    echo "Sending reset at ${x} baud..."
    stty ${x} < $1
    echo -n "${ONCORE_SET_TO_DEFAULTS}" > $1
done
    
