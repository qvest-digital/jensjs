#!/bin/mksh
set -ex
exec "$(realpath "$0/..")/acquire/main.sh" "$@"
