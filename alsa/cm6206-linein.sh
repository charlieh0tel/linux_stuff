#!/bin/bash

set -o errexit
set -o nounset
set -o xtrace

#
# For /etc/udev/rules.d/55-cm6206.rules
#
# SUBSYSTEM=="sound", ATTRS{idVendor}=="0d8c", ATTRS{idProduct}=="0102",  ENV{PULSE_IGNORE}="1", ATTR{id}="cm6206"
#

DEVICE="hw:cm6206"

function amixer_set()
{
    amixer -q -D "${DEVICE}" -- set "$@"
}

function amixer_cset()
{
    amixer -q -D "${DEVICE}" -- cset "$@"
}

# Change the capture source to Mixer.  Line does not work (6.11).
amixer_set 'PCM Capture Source' Mixer
amixer_cset 'name=PCM Capture Switch' on
amixer_set Line 'Line Capture Switch' on
amixer_set Line 'Playback Switch' on

# Given we are using Mixer as the source, turn off the other sources.
amixer_cset 'iface=Mixer,name=Mic Capture Switch' off
amixer_cset 'iface=Mixer,name=IEC958 In Capture Switch' off

# Ajust gains gains (L, R).
amixer_set PCM Capture 0,0
amixer_set Line Capture -3dB,-3dB
