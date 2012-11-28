#!/usr/bin/perl 
package RPZLA::Scraper::MAC_Cache;

use warnings;
use strict;

use Class::Struct;

#####################################################################
#
# Purpose:
#
#	A Ethernet Link Layer Cache (non-portable; Linux only) 
#	based on using 'ip neighbour show' (man 8 ip).
#

my $packagename = __PACKAGE__;
struct
(
	$packagename => 
	{
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
        my $self = shift;
	my $retval = $self->cache_reset() and $self->cache_reload();
	return $retval;
}

# make an empty cache
sub cache_reset()
{
	my $self = shift;
	$self->_cache({});
	return 1;
}

# load what the OS has in its cache
sub cache_reload()
{
	my $self = shift;
	my $cmd = 'ip neighbour show';
	my $retval = 0;
	if ( open(ARP, "$cmd |") )
	{
		while ( <ARP> )
		{
			chomp;
			my @entry = split(' ', $_);
			my $ip = $entry[0];
			my $mac = $entry[4];
			my $status = $entry[5];  # ignored for now
			$self->_cache->{$ip} = $mac;
		}
		close(ARP);
		$retval = 1;
	}
	return $retval;
}

# Just look up a value
sub search($)
{
	my ($self, $ip) = @_;
	return $self->_cache->{$ip};
}

# Force a cache reload if the entry is not in cache.
sub get($)
{
	my ($self, $ip) = @_;
	my $retval = $self->search($ip);
	if ( not defined($retval) )
	{
		if ( $self->cache_reload() )
		{
			$retval = $self->search($ip);
		}
	}
	return $retval;
}

1;
