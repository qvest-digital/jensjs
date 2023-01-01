#!/bin/mksh

trap 'print -ru2 -- I: acquire: got SIGINT, exiting; exit 0' INT

set -eo pipefail
while IFS= read -r line; do
	print -r -- "got $line"
done
print -ru2 -- I: acquire: terminating
