#!/bin/mksh
# shellcheck shell=ksh
export LC_ALL=C TZ=UTC
unset LANGUAGE
set -ex
if (( $# == 0 )); then
	set -- 'unnamed session from run-acquire.sh'
fi
exec "$(realpath "$0/..")/acquire/main.sh" "$@"
