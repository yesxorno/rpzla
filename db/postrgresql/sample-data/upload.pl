#!/usr/bin/perl
use strict;
use warnings;

# This and uploads the sample-data

use Config::General;

my $cmd = '( ./web.pl && ./dns.pl ) | psql ';

# pull the database name and user name from the config
# should generalise this (-c /path/to/config)
my $conf = new Config::General('/etc/rpzla/rpzla.conf');
my %config = $conf->getall();
my $db = $config{db}{name};

# run it
print "Now we upload sample data.\n\nPostgres user password needed ...\n";
system($cmd . "$db postgres");
exit($?)
