#!/usr/bin/perl 
package RPZLA::Analysis::BucketSpec;

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

		'interval'	=> '$',  # width of buckets
		'min'		=> '$',  # min value accepable 
		'max'		=> '$',  # must be a multiple of min * interval
	}
);

#####################################################################
#
# Methods

sub check
{
        my $self = shift;
	my $retval = 
	(
		$self->is_int($self->interval)
	and
		$self->is_int($self->min)
	and
		$self->is_int($self->max)
	and
		(0 == ($self->max % $self->interval))
	);
	return $retval;
}

sub is_int($) { my ($self, $n) = @_; return ( $n =~ m/\d+/) };

1;
