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
my $user = $config{db}{user};
my $db = $config{db}{name};

# run it
system($cmd . "$user $db");
exit($?)
