#!/bin/mksh

set -e

if (( $# == 0 )); then
	# as default command
	set -- psql
	# as hint
	print -ru2 '# SELECT jensjs.use_session(1);'
fi

devattach_sh_mydir=$(realpath "$0/..")
if [[ ! -s $devattach_sh_mydir/.pid ]]; then
	print -ru2 E: cannot find pidfile
	exit 1
fi
devattach_sh_pid=$(<"$devattach_sh_mydir/.pid")

devattach_sh_cmd='exec env "$@"'
for devattach_sh_x in "$@"; do
	devattach_sh_cmd+=\ ${devattach_sh_x@Q}
done
exec </proc/"$devattach_sh_pid"/environ xargs -0o mksh -c "$devattach_sh_cmd" --
