#!/bin/mksh
# shellcheck shell=ksh

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

# test database Perl module
perl -MDBI -MDBD::Pg -e '1;' || {
	print -ru2 "E: acquire: apt-get install libdbd-pg-perl"
	exit 255
}

# validate header line from input
IFS= read -r hdrline
[[ $hdrline = '"p|q|w","TS.","OWD.|MEMBYTES|wdogscheduled?","QDELAY.|NPKTS|NTOOEARLY","CHANCE|handover?|N50US","ecnin|BWLIM|N1MS","ecnout|TSOFS.|N4MS","bit5?|-|NLATER","mark?|-|(THISDELAY)","drop?|-|(&F8)","flow|-|-","PKTLEN|-|-"' ]] || {
	print -ru2 "E: acquire: wrong input format"
	print -ru2 "N: $hdrline"
	exit 1
}

# shovel into DB
exec perl todb.pl "$@"
