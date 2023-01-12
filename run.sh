#!/bin/mksh
# shellcheck shell=ksh

export LC_ALL=C TZ=UTC
unset LANGUAGE

if (( USER_ID == 0 )); then
	print -ru2 "W: running as superuser is discouraged, may trouble"
	print -ru2 "N: press ^C within 30s to abort, wait to continue"
	sleep 30
fi

if [[ -t 2 ]]; then
	PG_COLOR=always
else
	PG_COLOR=never
fi
export PG_COLOR PGCLIENTENCODING=SQL_ASCII

function xsendsig {
	local pid=$1
	shift

	kill -0 "$pid" >/dev/null 2>&1 || return 0
	kill "$@" "$pid"
}

function usage {
	print -ru2 "E: Usage: ${0##*/} [-kv] [port]"
	print -ru2 "N: -k: keep running if jensdmp finishes"
	print -ru2 "N: -v: run under pg_virtualenv(1)"
	print -ru2 "N: port: for HTTP, default 8080"
	exit ${1:-1}
}
dokeep=
dovenv=0
portarg=
while getopts 'hkv' c; do
	case $c in
	(h) usage 0 ;;
	(k) dokeep=-k ;;
	(v) dovenv=1 ;;
	(*) usage ;;
	esac
done
shift $((OPTIND - 1))
if (( $# == 0 )); then
	:
elif (( $# == 1 )) && [[ $1 = [1-9]*([0-9]) ]]; then
	portarg=$1
else
	usage
fi

if (( dovenv )); then
	set -A venv -- pg_virtualenv -t #-s
	set -A cmd -- "$0" $dokeep $portarg
	print -ru2 -- I: run.sh: starting pg_virtualenv
	exec "${venv[@]}" -- "${cmd[@]}"
	exit 255
fi
if [[ -z $PGHOST$PGPORT$PGDATABASE$PGUSER$PGPASSWORD ]]; then
	print -ru2 "E: PostgreSQL connection parameters not set"
	print -ru2 "N: maybe run with -v to set up an ephemeral instance?"
	exit 2
fi

# rename stdin to fd#4 for acquire
exec 4<&0
exec 0</dev/null

# change to script directory
cd "$(realpath "$0/..")" || {
	print -ru2 "E: run.sh: cannot change directory"
	exit 255
}

# prepare subprocess control
mypid=$$
pypid=
shpid=
function cleanup {
	print -ru2 -- I: run.sh: cleaning up
	trap - EXIT
	[[ -z $pypid ]] || xsendsig $pypid -INT
	[[ -z $shpid ]] || xsendsig $shpid -INT
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
		export LC_ALL=C.UTF-8
		exec python3 produce/main.py "$@"
	} &
	pspid=$!
	trap "kill -INT $pspid" INT
	trap "kill -TERM $pspid" TERM
	wait $pspid
	rv=$?
	trap - INT TERM
	print -ru2 -- I: run.sh: produce terminated with errorlevel $rv
	if (( rv == 0 )); then
		xsendsig $mypid -INT
	else
		xsendsig $mypid
	fi
} &
pypid=$!

# as well as shell subprocess acquire
print -ru2 -- I: run.sh: starting acquire
{
	sleep 1
	exec mksh acquire/main.sh $dokeep 0<&4
} &
shpid=$!
wait $shpid
rv=$?
print -ru2 -- I: run.sh: acquire terminated with errorlevel $rv
cleanup $rv
