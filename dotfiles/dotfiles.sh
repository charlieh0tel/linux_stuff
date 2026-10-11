#!/bin/bash

set -o errexit
set -o nounset

REPO=$(cd "$(dirname "$0")" && pwd)

usage() {
    echo "usage: $0 {in|out|diff} [~/.file ...]" >&2
    exit 1
}

home_path() {
    echo "${HOME}/.${1#${REPO}/dot.}"
}

repo_path() {
    local rel=${1#${HOME}/}
    echo "${REPO}/dot.${rel#.}"
}

tracked() {
    find "${REPO}" -type f -name 'dot.*' | sort
}

[ $# -ge 1 ] || usage
cmd=$1
shift

if [ $# -gt 0 ]; then
    files=()
    for f in "$@"; do
        files+=("$(repo_path "$(realpath -s "${f}")")")
    done
else
    mapfile -t files < <(tracked)
fi

case "${cmd}" in
    in)
        for r in "${files[@]}"; do
            mkdir -p "$(dirname "${r}")"
            cp -v "$(home_path "${r}")" "${r}"
        done
        ;;
    out)
        for r in "${files[@]}"; do
            h=$(home_path "${r}")
            mkdir -p "$(dirname "${h}")"
            if [ -e "${h}" ] && ! cmp -s "${r}" "${h}"; then
                cp -v "${h}" "${h}~"
            fi
            cp -v "${r}" "${h}"
        done
        ;;
    diff)
        rc=0
        for r in "${files[@]}"; do
            diff -u --label "${r#${REPO}/}" --label "$(home_path "${r}")" "${r}" "$(home_path "${r}")" || rc=1
        done
        exit ${rc}
        ;;
    *)
        usage
        ;;
esac
