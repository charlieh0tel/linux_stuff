#!/bin/bash

ONCORE_SET_TO_DEFAULTS=$'\x40\x40\x43\x69\x01\x28\x0d\x0a'

echo -n "${ONCORE_SET_TO_DEFAULTS}" > $1
    
