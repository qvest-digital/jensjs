#!/bin/mksh
# shellcheck shell=ksh

export LC_ALL=C TZ=UTC
unset LANGUAGE

if (( USER_ID == 0 )); then
	print -ru2 "W: running as superuser is discouraged, may trouble"
	print -ru2 "N: press ^C within 30s to abort, wait to continue"
	sleep 30
fi

print -ru2 "I: mrun.sh: testing sudo…"
if ! sudo true; then
	print -ru2 "E: mrun.sh: could not sudo, terminating"
	exit 1
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
	print -ru2 "E: Usage: ${0##*/} [-kv] [-H handle] [port]"
	print -ru2 "N: -H: normally autodetected; e.g. 0001"
	print -ru2 "N: -k: keep running if jensdmp finishes"
	print -ru2 "N: -v: run under pg_virtualenv(1)"
	print -ru2 "N: port: for HTTP, default 8080"
	exit "${1:-1}"
}
dokeep=
dovenv=0
handle=
portarg=
while getopts 'H:hkv' c; do
	case $c in
	(H)
		if [[ $OPTARG != [0-9A-F][0-9A-F][0-9A-F][0-9A-F] ]]; then
			print -ru2 "E: mrun.sh: invalid handle: $OPTARG"
			usage
		fi
		handle=$OPTARG
		;;
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
	# shellcheck disable=SC2086 # intentional
	set -A cmd -- "$0" $dokeep ${handle:+-H $handle} $portarg
	print -ru2 -- I: mrun.sh: starting pg_virtualenv
	# shellcheck disable=SC2154 # false positive
	exec "${venv[@]}" -- "${cmd[@]}"
	exit 255
fi
if [[ -z $PGHOST$PGPORT$PGDATABASE$PGUSER$PGPASSWORD ]]; then
	print -ru2 "E: mrun.sh: PostgreSQL connection parameters not set"
	print -ru2 "N: maybe run with -v to set up an ephemeral instance?"
	exit 2
fi

exec 0</dev/null
now=$(date -Is) || exit 255

# change to script directory
cd "$(realpath "$0/..")" || {
	print -ru2 "E: mrun.sh: cannot change directory"
	exit 255
}

if [[ -z $handle ]]; then
	# shellcheck disable=SC2046 # splitting desired
	handles=$(print -r -- $(sudo find /sys/kernel/debug/sch_multijens/ \
	    -name '[0-9A-F][0-9A-F][0-9A-F][0-9A-F]:v1')) || handles=
	if [[ -z $handles || $handles = *\ * ]]; then
		print -ru2 "E: mrun.sh: cannot guess handle"
		exit 1
	fi
	handle=${handles##*/}
	handle=${handle%:v*}
fi
if [[ $handle != [0-9A-F][0-9A-F][0-9A-F][0-9A-F] ]]; then
	print -ru2 "E: mrun.sh: invalid handle: $handle"
	usage
fi
handles=$(sudo stat -c %s "/sys/kernel/debug/sch_multijens/$handle:v1") || handles=
if [[ $handles != [1-9]?([0-9]?([0-9]?([0-9]))) ]]; then
	print -ru2 "E: mrun.sh: cannot stat handle $handle control file"
	exit 1
fi
if (( handles > 8 * 256 || (handles / 8) * 8 != handles )); then
	print -ru2 "E: mrun.sh: handle $handle control file has implausible size"
	exit 1
fi
(( handles /= 8 ))
typeset -Uui16 -Z5 hnum
(( hnum = handles - 1 ))
if [[ $(sudo stat -c %s "/sys/kernel/debug/sch_multijens/$handle-${hnum#16#}:0") != 0 ]]; then
	print -ru2 "E: mrun.sh: cannot stat UE $handle-${hnum#16#} relay file"
	exit 1
fi

# prepare subprocess control
mypid=$$
pypid=
set -A shpid
set -A jdpids
function cleanup {
	print -ru2 -- I: mrun.sh: cleaning up
	trap - EXIT
	rm -f .pid
	[[ -z $pypid ]] || xsendsig "$pypid" -INT
	[[ -z $shpid ]] || for p in "${shpid[@]}"; do
		xsendsig "$p" -INT
	done
	for p in "${jdpids[@]}"; do
		xsendsig "$p" -INT
	done
	exit "$1"
}
trap 'cleanup 0' INT
trap 'cleanup 1' EXIT TERM

echo $$ >.pid

# run python subprocess produce
{
	trap - EXIT
	{
		trap 'exit 129' INT TERM
		sleep 2
		print -ru2 -- I: mrun.sh: starting produce
		export LC_ALL=C.UTF-8
		exec python3 produce/main.py "$@"
	} &
	pspid=$!
	# shellcheck disable=SC2064 # intentional
	trap "kill -INT $pspid" INT
	# shellcheck disable=SC2064 # intentional
	trap "kill -TERM $pspid" TERM
	wait $pspid
	rv=$?
	trap - INT TERM
	print -ru2 -- I: mrun.sh: produce terminated with errorlevel $rv
	if (( rv == 0 )); then
		xsendsig $mypid -INT
	else
		xsendsig $mypid
	fi
} &
pypid=$!

# as well as shell subprocess acquire
print -ru2 -- "I: mrun.sh: starting acquire for UE#0"
# shellcheck disable=SC2118 # go home, shellcheck, you’re drunk, learn ksh syntax
sudo /usr/libexec/jensdmp -t \
    "/sys/kernel/debug/sch_multijens/$handle-00:0" |&
jdpids=$!
exec 0>&p
exec 5<&p
{
	sleep 1
	exec mksh acquire/main.sh "$now UE#0" $dokeep 0<&5
} &
shpid=$!
exec 5<&-
sleep 3
if ! kill -0 "$shpid"; then
	print -ru2 "E: mrun.sh: acquire for UE#0 not running any longer"
	cleanup 1
fi
hnum=0
while (( ++hnum < handles )); do
	print -ru2 -- "I: mrun.sh: starting acquire for UE#${hnum#16#}"
	# shellcheck disable=SC2118 # go home, shellcheck, you’re drunk, learn ksh syntax
	sudo /usr/libexec/jensdmp -t \
	    "/sys/kernel/debug/sch_multijens/$handle-${hnum#16#}:0" |&
	subpid=$!
	exec 0>&p
	exec 5<&p
	jdpids+=("$subpid")
	{
		sleep 1
		exec mksh acquire/msub.sh "$now UE#${hnum#16#}" $dokeep 0<&5
	} &
	subpid=$!
	exec 5<&-
	shpid+=("$subpid")
done
sleep 3
(( hnum = handles - 1 ))
if ! kill -0 "${shpid[hnum]}"; then
	print -ru2 "E: mrun.sh: acquire for UE#${hnum#16#} not running any longer"
	cleanup 1
fi
print -ru2 -- "I: mrun.sh: all acquire processes started"
wait "${shpid[0]}"
rv=$?
print -ru2 -- "I: mrun.sh: acquire#0 terminated with errorlevel $rv"
cleanup $rv
