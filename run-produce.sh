#!/bin/mksh
set -ex
exec "$(realpath "$0/..")/produce/main.py" "$@"
