#!/bin/sh

set -o xtrace
set -o errexit

TZ="America/Los_Angeles"

put() {
    local namespace="$1"
    local key="$2"
    local value="$3"

    adb shell settings put "${namespace}" "${key}" "${value}"
    adb shell settings put --user current "${namespace}" "${key}" "${value}"

    adb shell settings get "${namespace}" "${key}"
    adb shell settings get --user current "${namespace}" "${key}"
}

adb root
adb shell date @$(date +%s)

# doesn't seem to work
put global auto_time_zone 0
put global time_zone "${TZ}"

# it seems like this is the only thing that works ...
adb shell setprop persist.sys.timezone "${TZ}"

exit 0
