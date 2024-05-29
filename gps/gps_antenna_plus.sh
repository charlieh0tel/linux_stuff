#!/bin/sh

sudo modprobe cp210x
echo -n 10c4 8116 | sudo tee /sys/bus/usb-serial/drivers/cp210x/new_id
