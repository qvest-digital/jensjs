#!/bin/mksh

# rename stdin to fd#4 for acquire
exec 4<&0
exec 0</dev/null

# change to script directory
cd "$(realpath "$0/..")" || {
	print -ru2 "E: run.sh: cannot change directory"
	exit 255
}

# could do getopts here; forward arguments to produce only for now

# prepare subprocess control
mypid=$$
pypid=
shpid=
function cleanup {
	print -ru2 -- I: run.sh: cleaning up
	trap - EXIT
	[[ -z $pypid ]] || if kill -0 $pypid >/dev/null 2>&1; then
		kill -INT $pypid
	fi
	[[ -z $shpid ]] || if kill -0 $shpid >/dev/null 2>&1; then
		kill -INT $shpid
	fi
	exit $1
}
trap 'cleanup 0' INT
trap 'cleanup 1' EXIT TERM

# run python subprocess produce
{
	trap - EXIT
	{
		trap 'exit 129' INT TERM
		sleep 2
		print -ru2 -- I: run.sh: starting produce
		exec produce/main.py "$@"
	} &
	pspid=$!
	trap "kill -INT $pspid" INT
	trap "kill -TERM $pspid" TERM
	wait $pspid
	rv=$?
	print -ru2 -- I: run.sh: produce terminated with errorlevel $rv
	if (( rv == 0 )); then
		kill -INT $mypid
	else
		kill $mypid
	fi
} &
pypid=$!

# as well as shell subprocess acquire
print -ru2 -- I: run.sh: starting acquire
{
	sleep 1
	exec acquire/main.sh 0<&4
} &
shpid=$!
wait $shpid
rv=$?
print -ru2 -- I: run.sh: acquire terminated with errorlevel $rv
cleanup $rv
