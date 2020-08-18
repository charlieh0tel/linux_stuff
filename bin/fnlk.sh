#!/bin/bash

for fn_lock in /sys/bus/hid/devices/*/fn_lock; do
  case $(cat "${fn_lock}") in
	0)
    echo -n 1 >"${fn_lock}"
	  ;;
	1)
	  echo -n 0 >"${fn_lock}"
	  ;;
  esac
done
