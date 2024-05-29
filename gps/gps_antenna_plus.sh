#!/bin/sh

modprobe cp210x
echo -n 10c4 8116 >/sys/bus/usb-serial/drivers/cp210x/new_id
