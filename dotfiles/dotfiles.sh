#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

REPO=$(cd "$(dirname "$0")" && pwd)

usage() {
    echo "usage: $0 [-s host] {down|up|diff} [~/.file ...]" >&2
    exit 1
}

home_path() {
    echo "${HOME}/.${1#"${REPO}"/dot.}"
}

repo_path() {
    local rel=${1#"${HOME}"/}
    echo "${REPO}/dot.${rel#.}"
}

tracked() {
    find "${REPO}" -type f -name 'dot.*' | sort
}

# Ship the repo to a temp dir on host and run the command there; for "up",
# ship the updated dot files back.
# The script is expanded on the remote side.
# shellcheck disable=SC2016,SC2029
remote() {
    local host=$1 cmd=$2
    shift 2
    local args=() f r
    for f in "$@"; do
        r=$(repo_path "$(realpath -s "${f}")")
        printf -v f '"$HOME"/.%q' "${r#"${REPO}"/dot.}"
        args+=("${f}")
    done
    local script='set -e; t=$(mktemp -d); trap '\''rm -rf "$t"'\'' EXIT'
    script+='; tar -C "$t" -xf -'
    script+="; bash \"\$t/dotfiles.sh\" ${cmd} ${args[*]}"
    local back=cat
    if [ "${cmd}" = up ]; then
        script+=' >&2; cd "$t" && tar -cf - dot.*'
        back="tar -C ${REPO@Q} -xf -"
    fi
    (cd "${REPO}" && tar -cf - dotfiles.sh dot.*) \
        | ssh "${host}" "${script}" \
        | eval "${back}"
}

host=
while getopts s: opt; do
    case "${opt}" in
        s) host=${OPTARG} ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

[ $# -ge 1 ] || usage
cmd=$1
shift

case "${cmd}" in
    down|download) cmd=down ;;
    up|upload) cmd=up ;;
    diff) ;;
    *) usage ;;
esac

if [ -n "${host}" ]; then
    remote "${host}" "${cmd}" "$@"
    exit
fi

if [ $# -gt 0 ]; then
    files=()
    for f in "$@"; do
        files+=("$(repo_path "$(realpath -s "${f}")")")
    done
else
    mapfile -t files < <(tracked)
fi

case "${cmd}" in
    up)
        for r in "${files[@]}"; do
            mkdir -p "$(dirname "${r}")"
            cp -v "$(home_path "${r}")" "${r}"
        done
        ;;
    down)
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
            diff -uN --label "${r#"${REPO}"/}" --label "$(home_path "${r}")" "${r}" "$(home_path "${r}")" || rc=1
        done
        exit ${rc}
        ;;
    *)
        usage
        ;;
esac
