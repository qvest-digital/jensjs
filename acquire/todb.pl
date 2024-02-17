use strict;
use warnings;

use DBI;
use DBD::Pg;

my $dbh = DBI->connect("dbi:Pg:", '', '',
    {AutoCommit => 1, RaiseError => 1});

my $sessname = shift;
my $sid = $dbh->selectall_arrayref('SELECT jensjs.new_session($1)',
    {}, $sessname)->[0]->[0];

my $n;

sub bbeg {
	$dbh->do(q{COPY r
		(vts, hts, flow, flags, kind, mark, ue, psize, uepkts, uebytes, iptos, vbw, rbw, vqdelay, rqdelay, owdelay)
		FROM STDIN WITH (FORMAT csv, DELIMITER E'\t')
	});
	$n = 0;
}
&bbeg;
$n = 127;

while (<STDIN>) {
	$dbh->pg_putcopydata($_);
	if (++$n >= 128) {
		$dbh->pg_putcopyend();
		&bbeg;
	}
}

$dbh->pg_putcopyend() if $n > 0;
print STDERR "I: acquire: terminating\n";
$dbh->disconnect or warn $dbh->errstr;;

if ((shift || '') eq '-k') {
	print STDERR "N: acquire: waiting for termination request...\n";

	while (1) {
		sleep 30;
	}
}
