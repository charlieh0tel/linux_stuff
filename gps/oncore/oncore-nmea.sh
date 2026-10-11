#!/bin/bash

ONCORE_SWITCH_TO_NMEA=$'\x40\x40\x43\x69\x01\x28\x0d\x0a'

echo -n "${ONCORE_SWITCH_TO_NMEA}" > "$1"
    
