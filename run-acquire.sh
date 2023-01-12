#!/bin/mksh
# shellcheck shell=ksh
export LC_ALL=C TZ=UTC
unset LANGUAGE
set -ex
exec "$(realpath "$0/..")/acquire/main.sh" "$@"
