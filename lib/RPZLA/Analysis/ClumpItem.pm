#!/usr/bin/perl 
package RPZLA::Analysis::ClumpItem;
use base RPZLA::Analysis::DateTimeSupport;

use warnings;
use strict;

#####################################################################
#
# Purpose:
#
#

my $packagename = __PACKAGE__;
struct
(
	$packagename => 
	{
		# Static
		'interval'	=> '$', # interval in seconds
		# Data
		'num'		=> '$', # number of these clumps (total)
		# Internal records
		'_first'	=> '$'	# the DateTime of the first element
					# for the clump
	}
);

#####################################################################
#
# Methods

sub init($)
{
	my ($self, $dt) = @_;
	die ( "Define interval." ) if ( not defined($self->interval) );
	$self->_first($dt);
	$self->num(1);
}

sub add($)
{
        my ($self, $dt) = @_;
	my $retval = 0;
	if ( $self->date_diff_to_sec($self->_first(), $dt) < $self->interval )
	{
		$self->num($self->num + 1);
		$retval = 1;
	}
	return $retval;
}
