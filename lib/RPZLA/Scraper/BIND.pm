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
	# first things first
	$self->_open_syslog();
	$self->_prep_insert_sql(PREP_INSTALL_SQL);
	$self->_load_config();
	$self->_log_path($self->_config->{'bind'}->{'log'});
	# it checks if log_path makes sense for us
	$self->SUPER::init();
}

sub _parse_log_entry($)
{
	my ($self, $line) = @_;
	my $retval = undef;
	my @field = ();
	my $err = undef;
	my $status = $self->_parse_bind_log($line, \@field, \$err);
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
	else
	{
		$retval = join(' ', @field);
	}
	return $retval;
}

#
# The trouble of parsing bind logs.
#
# NOTE: we accept the printing of category and/or severity in the log.
# These fields are ignored for the analysis below.
#
# BIND 9.8.2 does:
#
# Separating space delimited words, generally.
#
# 20-Oct-2012 
# 17:32:36.534 
# client 
# 2001:878:200:2000:d08c:a4a6:bd0a:a44#62386: 
# rpz QNAME CNAME rewrite 
# ipic.staticsdo.ccgslb.com.cn 
# via 
# ipic.staticsdo.ccgslb.com.cn.rpz.spamhaus.org
#
# 11 fields, with index:
#   2 == client 
#   4,5,6,7 == rpz,QNAME,CNAME,rewrite
#   9 == via
#
# Note that CNAME may relate to the rpz config of data
#
# BIND 9.9.0 does:
#
# 20-Oct-2012 
# 12:53:27.438 
# client 
# 2001:878:200:2000:c001::1#38909 
# (nastynasty.com): 
# rpz QNAME CNAME rewrite 
# nastynasty.com 
# via 
# nastynasty.com.local.rpz
#
# 12 fields, with index:
#   2 == client 
#   5,6,7,8 == rpz,QNAME,CNAME,rewrite
#   10 == via
#
# Note again that CNAME may relate to the rpz config of data
# We ignore the content of these words, but expect something to be there.
# (perhaps not the smartest solution).


# Return:
#   undef  	major error
#   ''		parsing successful (fields set in $field)
#  'some error' dont like the log entry.  Ignore it
sub _parse_bind_log($$)
{
	my ($self, $line, $field) = @_;
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
		return 0;
	}
	#
	# Simple sanity check: their should be 8 or 9 words left:
	#
	my $words_remaining = scalar(@chop);
	if ( 8 != $words_remaining and 9 != $words_remaining )
	{
		return "words remaining out of range."
	}
	# Okay, log is meant for us.
	# next field should be the IPv4/IPv6 address plus port number of the 
	# client.  Pull and store.
	$next = shift(@chop);
	if ( $next =~ m/([\dabcdefABCDEF\.\:]+)[\#]([\d]+)/ )
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
	# No we just match what remains:
	#
	if ( 9 == $words_remaining )
	{
		# burn the '(some.domain):' it is redundant
		shift(@chop);
	}
	my $rest = join(' ', @chop);
	if (  $rest =~ m/rpz [\w]+ [\w]+ rewrite ([\w\.\-]+) via ([\w\.\-]+)/ )
	{
		my $query = $1;
		$field->[4] = $query;
		my $zone = $2;
		if ( $zone =~ m/$query[.]([\w\.\-]+)/ )
		{
			$field->[5] = $1;
			return '';
		}
		else
		{
			return "Could not match query '$query' " .
				"in full zone '$zone'";
		}
	}
	else
	{
		return "Last part of line did not parse with " .
			"'rpz (word) (word) rewrite (domain) via (zone)'";
	}
	#
	# UNREACHED (should not be reached)
	#
	return undef;
}

1;
