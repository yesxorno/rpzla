#!/usr/bin/perl

use DateTime;
use Config::General;

my $conf = new Config::General('/etc/rpzla/rpzla.conf');
my %config = $conf->getall();
my $schema = $config{db}{schema};

my $today = DateTime->now();

sub insert($$$$$)
{
	my ($d,$t,$i,$c,$h) = @_;
	print "insert into $schema.web values (DEFAULT, '$d $t', '$i', '$c', '$h');\n";
}

if ( open(DATA, '< web.data.txt') )
{
	while ( <DATA> )
	{
		chomp($_);
		my ($delta,$time,$ip,$client,$host) = split(';');
		# Subtrac days from today
		my $past = $today->clone();
		$past->subtract(days=>$delta);
		my $day = $past->ymd();
		insert($day,$time,$ip,$client,$host);
	}
	close(DATA);
}
