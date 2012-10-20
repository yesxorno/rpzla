#!/usr/bin/perl 
package RPZLA::Scraper::Apache;
use base qw/RPZLA::Scraper::Base/;

use warnings;
use strict;

use constant	PREP_INSTALL_SQL	=> 	"INSERT INTO web " .
	"(datetime, client_ip, client_hostname, query_domain) " .
	"values " .
	"(?,?,?,?)";

#####################################################################
#
# Purpose:
#
#	The apache log scraper for RPZLA
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
	$self->_log_path($self->_config->{'walled-garden'}->{'log'});
	$self->SUPER::init();
}

sub _parse_log_entry($)
{
	my ($self, $s) = @_;
	my $retval = undef;
	my $valid_sites = $self->_config->{'walled-garden'}->{'valid_sites'}->{'domain'};
	if ( $s =~ m/([\w-]+) ([\d:]+) ([\w.:]+) ([\w.:-]+) ([\w.-]+) ([\d]+) "GET ([\w\/.?\=\&\%\-]+) HTTP\/[^"]*"/ )
	{
		my ($date, $time, $ip, $lookup, $site, $http_response, $path ) =
			($1, $2, $3, $4, $5, $6, $7);
		my $log_it = 0;
		# Config::General will return an array if there are multiple
		# 'domain's, or a string if only one.  Take care of that.
		if ( '' eq ref($valid_sites) )
		{
			$log_it = ($site ne $valid_sites);
		}
		else
		{
			$log_it = 1;
			for my $valid (@{$valid_sites})
			{
				if ( $site eq $valid )
				{
					$log_it = 0;
					last;
				}
			}
		}
		if ( $log_it )
		{
			$retval = join(' ', $date, $time, $ip, $lookup, $site);
		}
	}
	return $retval;
}
