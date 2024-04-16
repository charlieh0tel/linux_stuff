#!/bin/bash

echo "module wireguard +p" | tee /sys/kernel/debug/dynamic_debug/control
