#!/usr/bin/perl

use DateTime;
use Config::General;

my $conf = new Config::General('/etc/rpzla/rpzla.conf');
my %config = $conf->getall();
my $schema = $config{db}{schema};

my $today = DateTime->now();

sub insert($$$$$)
{
	my ($d,$t,$i,$h,$z) = @_;
	print "insert into $schema.dns values (DEFAULT, '$d $t', '$i', '$h', '$z');\n";
}

if ( open(DATA, '< dns.data.txt') )
{
	while ( <DATA> )
	{
		chomp($_);
		my ($delta,$time,$ip,$host,$zone) = split(';');
		# Subtrac days from today
		my $past = $today->clone();
		$past->subtract(days=>$delta);
		my $day = $past->ymd();
		insert($day,$time,$ip,$host,$zone);
	}
	close(DATA);
}
