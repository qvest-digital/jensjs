#!/bin/mksh

trap 'print -ru2 -- I: acquire: got SIGINT, exiting; exit 0' INT

# change to script directory
cd "$(realpath "$0/..")" || {
	print -ru2 "E: acquire: cannot change directory"
	exit 255
}

# set up database schema
psql -f schema.sql || {
	print -ru2 "E: acquire: cannot install DB schema"
	exit 2
}

set -eo pipefail
while IFS= read -r line; do
	print -r -- "got $line"
done
print -ru2 -- I: acquire: terminating
