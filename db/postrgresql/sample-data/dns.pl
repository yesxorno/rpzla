#!/usr/bin/perl

use DateTime;

my $today = DateTime->now();

sub insert($$$$$)
{
	my ($d,$t,$i,$h,$z) = @_;
	print "insert into dns values (DEFAULT, '$d $t', '$i', '$h', '$z');\n";
}

if ( open(DATA, '< dns.data.txt') )
{
	while ( <DATA> )
	{
		my ($delta,$time,$ip,$host,$zone) = split(';');
		# Subtrac days from today
		my $past = $today->clone();
		$past->subtract(days=>$delta);
		my $day = $past->ymd();
		insert($day,$time,$ip,$host,$zone);
	}
	close(DATA);
}
