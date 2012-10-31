#!/usr/bin/perl 
package RPZLA::Scraper::Cache-MAC;
use base qw/RPZLA::Scraper::Cache-MAC/;
use Net::ARP;

use warnings;
use strict;

use constant DEFAULT_RETAIN	=>	180;

#####################################################################
#
# Purpose:
#
#	The BIND log scraper for RPZLA
#

my $packagename = __PACKAGE__;
struct
(
	$packagename => 
	{
		'cache_retain'	=> '$', # in seconds, how long to retain
		'dev'		=> '$', # e.g "eth0" the device to use
		#
		# Internal
		#
		'_cache'	=> '$',
	}
);

#####################################################################
#
# Overridden methods

# Make the SOAP / XML request for a service
sub init
{
        my ($self, $retain) = @_;
	if ( undef($retain) )
	{
		$self->cache_retain(DEFAULT_RETAIN());
	}
	else
	{
		$self->cache_retain($retain);
	}
	$self->_cache({});
}

# Remove cache entries older than 'cache_retain'
sub prune($)
{
        my ($self, $time) = @_;
	my $now = $self->now();
	my $cache_retain = $self->cache_retain;
	for my $ip ( keys($self->_cache()) )
	{
		my $cache_value = $self->_cache{$ip}{'time'};
		if ( $cache_retain < ($now - $cache_value) )
		{
			delete($self->_cache{$ip});
		}
	}
}

# Just look up a value
sub search($)
{
	my ($self, $ip) = @_;
	return $self->_cache->{$ip};
}

# Return the value (or look it up and store) for an IP
sub get($)
{
	my ($self, $ip) = @_;
	my $retval = $self->search($ip);
	if ( not defined $retval )
	{
		if ( defined($retval = $self->lookup($ip)) )
		{
			$self->store($ip, $retval);
		}
	}
	return $retval;
}

# Do the ARP lookup
sub lookup($)
{
	my ($self, $ip) = @_;
	my $mac = Net::ARP::arp_lookup($dev, $ip);
	return $mac;
}

# Add a value to the cache 
sub store($$)
{
	my ($self, $ip, $mac) = @_;
	if ( defined($mac) )
	{
		my $time = $self->now();
		$self->_cache{$ip} = 
		{
			'time'	=>	$time,
			'mac'	=>	$mac,
		};
	}
}

# get current time
sub now()
{
	return time();
}

1;
