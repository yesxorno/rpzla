#!/usr/bin/perl 
package RPZLA::Scraper::BIND;
use base qw/RPZLA::Scraper::Base/;

use warnings;
use strict;

use constant	PREP_INSTALL_SQL	=> 	"INSERT INTO dns " .
	"(datetime, client_ip, client_mac, query_domain, response_zone) " .
	"values " .
	"(?,?,?,?,?)";

#####################################################################
#
# Purpose:
#
#	The BIND log scraper for RPZLA
#
#  Essentially just parses log lines from the RPZ log
#

#####################################################################
#
# Overridden methods

sub init()
{
        my $self = shift;
	if ( not defined($self->ident) )
	{
		die("Need self->ident defined.");
	}
	# first things first
	$self->_open_syslog();
	$self->_prep_insert_sql(PREP_INSTALL_SQL);
	$self->_load_config();
	$self->_log_path($self->_config->{'bind'}->{'log'});
	# it checks if log_path makes sense for us
	$self->SUPER::init();
	$self->_zone_filter_check();
}

sub _parse_log_entry($)
{
	my ($self, $line) = @_;
	my $retval = undef;
	my @field = ();
	my $err = undef;
	my $status = $self->_parse_bind_log($line, \@field, \$err);
	my $zone = $field[5];
	if ( not defined($status) )
	{
		# major baulk
		$self->err("Major error parsing bind log.");
		$self->exit_now(1);
	}
	elsif ( 0 < length($status) )
	{
		# dont ship to DB, report error in debug mode
		$self->debug("Log entry unparsable/unexpected.");
		# include any message delivered by the parser
		$self->debug($status);
		$self->debug("Log entry: $line");
		$retval = undef;
	}
	elsif ( $self->_zone_include($zone) )
	{
		$retval = join(' ', @field);
	}
	else
	{
		# zone filtered
		$self->debug("RR filtered for zone '$zone'");
		$retval = undef;
	}
	return $retval;
}

#####################################################################
#
# Our methods

sub _zone_filter_check()
{
	my $self = shift;
	my $conf = $self->_config->{'bind'};
	if 
	( 
		not defined($conf->{'zone_filter'}) 
	or 
		0 == scalar(keys(%{$conf->{'zone_filter'}}))
	)
	{
		$conf->{'zone_filter'}->{'include_all'} = 1;
	}
	else
	{
		$conf->{'zone_filter'}->{'include_all'} = 0;
		# Default policy is 'include'
		if ( not defined($conf->{'zone_filter'}->{'zone_to_db'}) )
		{
			$conf->{'zone_filter'}->{'zone_to_db'} = 1;
		}
		if ( not defined($conf->{'zone_filter'}->{'list'}) )
		{
			$self->exit_now("No zone_filter list elements.");
		}
	}
	$self->debug
	(
		">>>> Zone Filter: " .
		"include_all: " .  $conf->{'zone_filter'}->{'include_all'} .
		" zone_to_db: " .  
		$conf->{'zone_filter'}->{'zone_to_db'} .
		" list: [" . 
		join(", ", @{$conf->{'zone_filter'}->{'list'}->{'zone'}}) .
		"]"
	);
}

# Implement zone filtering
#
# return value indicates if records from the provided zone should be
# shipped to the DB.
sub _zone_include($)
{
	my ($self, $zone) = @_;
	my $zf_conf = $self->_config->{'bind'}->{'zone_filter'};
	my $retval = 0;
	my $match = 0;
	if ( $zf_conf->{'include_all'} )
	{
		$retval = 1;
		$match = 0;
	}
	else # do matching
	{
		# $self->debug(join(", ", $zf_conf->{'list'}));
		for my $z ( @{$zf_conf->{'list'}->{'zone'}} )
		{
			$self->debug("Testing zone: '$z' against '$zone'");
			if ( $zone eq $z )
			{
				$self->debug("Matched zone: '$z'");
				$match = 1;
				last;
			}
		}
		my $zone_to_db = $zf_conf->{'zone_to_db'};
		$self->debug("zone_to_db == $zone_to_db, match == $match");
		$retval =
		(
			( $match and $zone_to_db )
		or
			( !$match and !$zone_to_db )
		);
	}
	$self->debug("Zone '$zone' include == $retval");
	return $retval;
}

# Extract the name of the zone which matched the query from the 
# resource record which matched.  Deal with all 4 cases (QNAME, IP,
# NSIP, NSDNAME)
sub _zone_from_rr($$$)
{
	my ($self, $query, $match_type, $rr) = @_;
	my $retval = undef;
	if ( $rr =~ m/$query[.]([\w\.\-]+)/i )
	{
		# Then this is a QNAME. (easy case)
		$retval = $1;
	}
	else
	{
		my $delim = 'rpz-' . lc($match_type) . '[.]';
		my @parts = split($delim, $rr);
		if ( 2 == scalar(@parts) )
		{
			$retval = $parts[1];
		}
	}
	return $retval;
}

#
# The trouble of parsing bind logs. Separating space delimited words.
#
# BIND 9.8.2 does:
#
#  0 Date:		20-Oct-2012 
#  1 Time:		17:32:36.534 
#  2 Static:		client 
#  3 Address:		2001:878:200:2000:d08c:a4a6:bd0a:a44#62386: 
#  4 Static:		rpz 
#  5 Match Type:	QNAME 
#  6 Policy:		CNAME 
#  7 Static:		rewrite 
#  8 Query:		ipic.staticsdo.ccgslb.com.cn 
#  9 Static:		via 
# 10 RR match:		ipic.staticsdo.ccgslb.com.cn.rpz.spamhaus.org
#
# BIND 9.9.0 does:
#
#  0 Date: 		20-Oct-2012 
#  1 Time: 		12:53:27.438 
#  2 Static: 		client 
#  3 Address: 		2001:878:200:2000:c001::1#38909 
#  4 Query: 		(nastynasty.com): 
#  5 Static: 		rpz 
#  6 Match Type: 	QNAME 
#  7 Policy: 		CNAME 
#  8 Static: 		rewrite 
#  9 Query (again): 	nastynasty.com 
# 10 Static: 		via 
# 11 RR match: 		nastynasty.com.local.rpz
#
#
# Return:
#   undef  	major error
#   ''		parsing successful (fields set in $field)
#  'some error' dont like the log entry.  Ignore it
#
# in $field we return what we extract from the log (array of string)
#
# 0  date
# 1  time
# 2  ip address
# 3  mac (if possible)
# 4  query domain
# 5  zone name (within which the match was found)
#
sub _parse_bind_log($$)
{
	my ($self, $line, $field) = @_;
	my $match_type = undef;
	my @chop = split(' ', $line);
	# first we just assume that we get date and time
	$field->[0] = shift(@chop);
	# Not stripping the milliseconds ...
	# my ($hms, $fractional_seconds) = split('[.]', $time);
	$field->[1] = shift(@chop);
	# Now we allow the category and or severity fields and ignore them.
	my $next = $chop[0];
	if ( $next eq 'rpz:' or $next eq 'info:' )
	{
		shift(@chop);
	}
	$next = $chop[0];
	if ( $next eq 'rpz:' or $next eq 'info:' )
	{
		shift(@chop);
	}
	# Those out of the way, we expect 'client'
	# if not, this log is not for us.
	# This is a bit strange, as this log should be for us in entirety.
	$next = shift(@chop);
	if ( 'client' ne $next )
	{
		return 'does not look like an RPZ log entry: ignored';
	}
	#
	# Simple sanity check: their should be 8 or 9 words left:
	#
	my $words_remaining = scalar(@chop);
	if ( 8 != $words_remaining and 9 != $words_remaining )
	{
		return "# words remaining out of range " .
			"(unrecognized RPZ format).";
	}
	# Okay, log is meant for us.
	# next field should be the IPv4/IPv6 address plus port number of the 
	# client.  Pull and store address and get mac.
	$next = shift(@chop);
	if ( $next =~ m/([\dabcdefABCDEF\.\:\%]+)[\#]([\d]+)/ )
	{
		# looks good, we ignore the port number
		$field->[2] = $1;
		$field->[3] = $self->get_mac($1);
	}
	else
	{
		return "Expected an IP address#port field.  Couldn't match: " .
			"'$next'";
	}
	#
	# Half way there, roughly ;-)
	#
	my $retval = ''; # assuming success
	if ( 9 == $words_remaining )
	{
		# burn the '(some.domain):' it is redundant
		shift(@chop);
	}
	my $rest = join(' ', @chop);
	if ( $rest =~ m/rpz ([\w]+) [\w]+ rewrite ([\w\.\-]+) via ([\w\.\-]+)/ )
	{
		$match_type = $1; # we use this below ...
		my $query = $2;
		$field->[4] = $query;
		my $rr = $3;
		my $zone = $self->_zone_from_rr($query, $match_type, $rr);
		if ( defined($zone) )
		{
			$field->[5] = $zone;
			return '';
		}
		else
		{
			$retval = "Could not match query '$query' with match " .
				"type $match_type from resoure recrord ". 
				"'$zone'";
		}
	}
	else
	{
		$retval = "Last part of line did not parse with " .
			"'rpz (word) (word) rewrite (domain) via (zone)'";
	}
	return $retval;
}

1;
