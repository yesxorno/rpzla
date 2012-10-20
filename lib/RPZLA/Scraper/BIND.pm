#!/usr/bin/perl 
package RPZLA::Scraper::BIND;
use base qw/RPZLA::Scraper::Base/;

use warnings;
use strict;

use constant	PREP_INSTALL_SQL	=> 	"INSERT INTO dns " .
	"(datetime, client_ip, query_domain, response_zone) " .
	"values " .
	"(?,?,?,?)";

#####################################################################
#
# Purpose:
#
#	The BIND log scraper for RPZLA
#

#####################################################################
#
# Overridden methods

# Make the SOAP / XML request for a service
sub init()
{
        my $self = shift;
	if ( not defined($self->ident) )
	{
		die("Need self->ident defined.");
	}
	$self->_prep_install_sql(PREP_INSTALL_SQL);
	$self->_open_syslog();
	$self->_load_config();
	$self->_log_path($self->_config->{'bind'}->{'log'});
	$self->SUPER::init();
}

sub parse_log_entry($)
{
	my ($self, $line) = @_;
	my $parsed = 0;
	# Format is:
	#
	# (date) (time) client (ip) \((query)\): rpz 'word' 'word' rewrite
	# (query) via (rpz-zone)
	#
	# where things in parens are matched for extration.
	#
	# 18-Oct-2012 
	# 15:25:09.176 
	# client 
	# 2001:878:200:2000:c000::2#56895: 
	# rpz QNAME CNAME rewrite 
	# www.camprofilexo.com 
	# via 
	# www.camprofilexo.com.rpz.spamhaus.org
	if ( $line !~ m/([\w\-:.]+) ([\w:.]+) client ([\w\-:.#]+) rpz [\w]+ [\w]+ rewrite ([\w\-.]+) via ([\w\-.]+)/ )
	{
		$self->err
		(
			"Unexpected format from BIND log " .
			$self->_config{bind}->{log}
		);
		$self->err("Line was: $line");
		# abort
		return undef;
	}
	my ($date, $time, $ip_full, $query, $zone_full) = 
		($1, $2, $3, $4, $5, $6);
	my $rpz_zone = undef;
	# Split out core details from entries combined with more data
	# Ignore fractional seconds
	my ($hms, $fractional_seconds) = split('[.]', $time);
	# Ignore client port number
	my ($ip, $port) = split('[#]', $ip_full);
	# strip the query from the font of the rpz zone name
	if ( $zone_full !~ m/$query[.]([\w\.]+)/ )
	{
		$self->err("Unexpected: query not a part of the rpz zone name");
		$self->err("Query domain: '$query', Zone name: '$zone_full'");
	}
	else
	{
		$parsed = 1;
		$rpz_zone = $1;
	}
	# join and return
	return 
	( 
		$parsed 
	? 
		join(' ', $date, $hms, $ip, $query, $rpz_zone)
	:
		undef
	);
}
