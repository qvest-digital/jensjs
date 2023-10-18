use strict;
use warnings;

use DBI;
use DBD::Pg;

my $dbhp = DBI->connect("dbi:Pg:", '', '',
    {AutoCommit => 1, RaiseError => 1});
my $dbhq = DBI->connect("dbi:Pg:", '', '',
    {AutoCommit => 1, RaiseError => 1});

my $sessname = shift;
my $sid = $dbhp->selectall_arrayref('SELECT jensjs.new_session($1)',
    {}, $sessname)->[0]->[0];
$dbhq->do('SELECT jensjs.use_session($1)', undef, $sid);

my $np;
my $nq;
my $ni = 0;

sub pbeg {
	$dbhp->do(q{COPY p
		(ts, owd, qdelay, vqnb, ecnin, ecnout, bitfive, ismark, isdrop, flow, len)
		FROM STDIN WITH (FORMAT csv, DELIMITER E'\t')
	});
	$np = 127;
}
&pbeg;

sub qbeg {
	$dbhq->do(q{COPY q
		(ts, membytes, npkts, handover, bwlim, tsofs)
		FROM STDIN WITH (FORMAT csv, DELIMITER E'\t')
	});
	$nq = 127;
}
&qbeg;

while (<STDIN>) {
	if (/^\"p\"\t/) {
		s///;
		$dbhp->pg_putcopydata($_);
		if (++$np >= 128) {
			$dbhp->pg_putcopyend();
			&pbeg;
		}
	} elsif (/^\"q\"\t/) {
		s///;
		$dbhq->pg_putcopydata($_);
		if (++$nq >= 128) {
			$dbhq->pg_putcopyend();
			&qbeg;
		}
	} else {
		print STDERR "W: acquire: first ignored line: $_" if $ni == 0;
		++$ni;
	}
}

$dbhp->pg_putcopyend() if $np > 0;
$dbhq->pg_putcopyend() if $nq > 0;
print STDERR "I: acquire: terminating, $ni lines ignored\n";
$dbhp->disconnect or warn $dbhp->errstr;;
$dbhq->disconnect or warn $dbhq->errstr;;

if ((shift || '') eq '-k') {
	print STDERR "N: acquire: waiting for termination request...\n";

	while (1) {
		sleep 30;
	}
}
