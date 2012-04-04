#!/usr/bin/perl

use DateTime;

my $today = DateTime->now();

sub insert($$$$$)
{
	my ($d,$t,$i,$c,$h) = @_;
	print "insert into web values (DEFAULT, '$d $t', '$i', '$c', '$h');\n";
}

if ( open(DATA, '< web.data.txt') )
{
	while ( <DATA> )
	{
		my ($delta,$time,$ip,$client,$host) = split(';');
		# Subtrac days from today
		my $past = $today->clone();
		$past->subtract(days=>$delta);
		my $day = $past->ymd();
		insert($day,$time,$ip,$client,$host);
	}
	close(DATA);
}
