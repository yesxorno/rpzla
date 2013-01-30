#!/usr/bin/perl 
package RPZLA::Analysis::ClumpItem;
use base qw/RPZLA::Analysis::Base/;

use warnings;
use strict;

use Carp;
use Class::Struct;

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

		# Data
		'num'		=> '$', # number of these clumps (total)
		'offset'	=> '$', # array of DateTime::Duration
					# differences between first clump 
					# elements betweeen all clumps
		# Internal records
		'_last'		=> '$'	# the DateTime of the first element
					# from the last clump (for use in
					# difference to the next added).
	}
);

#####################################################################
#
# Methods

sub new
{
        confess("bad arg count: 2 args expected") if ( 2 != @_ );
        my ($invocant, $tz ) = @_;
        my $class = ref($invocant) || $invocant;
        my $self = { 'tz' => $tz };
        bless($self, $class);
        return $self;
}

sub add($)
{
	my ($self, $start_of_new_clump) = @_;
	if ( not defined($self->_last()) )
	{
		# first clump
		$self->_last($start_of_new_clump);
		$self->num(1);
	}
	else
	{
		# diff = $self->_last - $start_of_new_clump
		# my $offset = $self->offset()
		# push($offset, $diff);
		# $self->num($self->num + 1);
		# $self->_last($start_of_new_clump)
	}
}
1;
