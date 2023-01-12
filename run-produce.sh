#!/bin/mksh
# shellcheck shell=ksh
export LC_ALL=C.UTF-8 TZ=UTC
unset LANGUAGE
set -ex
exec "$(realpath "$0/..")/produce/main.py" "$@"
