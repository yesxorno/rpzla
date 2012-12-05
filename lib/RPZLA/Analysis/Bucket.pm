#!/usr/bin/perl 
package RPZLA::Analysis::Bucket;

use warnings;
use strict;
use RPZLA::Analysis::BucketSpec;

use Class::Struct;

#####################################################################
#
# Purpose:
#
#	Stastical Analysis: just a bucket collector.
#

my $packagename = __PACKAGE__;
struct
(
	$packagename => 
	{
		# All must be Integers (else the mod work goes to hell)
		'spec'		=> '$',  # bucket details
		#
		# Internal
		#
		'_bucket'	=> '$',
	}
);
#####################################################################
#
# Methods

sub init
{
        my $self = shift;
	my $retval = 
	(
		'RPZLA::Analysis::BucketSpec' eq ref($self->spec)
	and
		$self->spec->check
	);
	if ( $retval )
	{
		$retval = $self->reset();
	}
	return $retval;
}

# make an empty bucket
sub reset()
{
	my $self = shift;
	my $len = 
	(
		($self->spec->max - $self->spec->min) / 
		$self->spec->interval
	);
	my @bucket = ( );
	my $i = 0;
	while ( $i < $len )
	{
		$bucket[$i] = 0;
		$i++;
	}
	$self->_bucket(\@bucket);
	return 1;
}

# You get a reference; dont modify without calling reset ...
sub get()
{
	my $self = shift;
	return $self->_bucket;
}

# reform the array, indexed by its value.
# arg is decending (0 or absent), ascending (1)
sub get_sorted()
{
	my $self = shift;
	my $decend = 1;
	my $values = $self->_bucket;
	my @retval = ();
	if ( scalar(@_) )
	{
		$decend = ( $_[0] == 0 ? 1 : 0 );
	}
	if ( $decend )
	{
		@retval = sort {$b <=> $a} @{$values};
	}
	else
	{
		@retval = sort {$a <=> $b} @{$values};
	}
	return \@retval;
}

# may add floats within min/max
sub add($)
{
	my ($self, $n) = @_;
	my ($min, $max, $intv) = 
	(
		$self->spec->min, $self->spec->max, $self->spec->interval
	);
	my $retval = 0;
	if ( $min <= $n and $n <= $max )
	{
		my $val = int($n); # floor to int
		my $diff = $val % $intv;  # difference to interval
		my $offset = int((($val - $diff) - $min) / $intv);
		$self->_bucket->[$offset]++;
		$retval = $self->_bucket->[$offset];
	}
	return ( 0 < $retval );
}

sub buckets_total()
{
	my $self = shift;
	my $retval = 0;
	for my $val ( @{$self->_bucket} )
	{
		$retval += $val;
	}
	return $retval;
}

# dump data to a file: two ways, unsorted, or sorted (second arg sorted==true)
sub dump_to_file($$)
{
	my ($self, $path, $sorted) = @_;
	my $data = $self->_bucket;
	if ( $sorted )
	{
		$data = $self->get_sorted(0);
	}
	return $self->_dump_to_file($path, $data);
}

# dump the buckets to a text file
sub _dump_to_file($$)
{
	my ($self, $path, $data) = @_;
	my ($min, $max, $intv) = 
	(
		$self->spec->min, $self->spec->max, $self->spec->interval
	);
	if ( open(FILE, "> $path") )
	{
		# First find the last non-zero value.  We'll not
		# print out all of the last zeros.
		my $len = scalar(@{$data});
		my $i = $len;
		my $index_of_last_non_zero = undef;
		while ( -1 < $i )
		{
			$i--;
			if ( 0 < $data->[$i] )
			{
				$index_of_last_non_zero = $i;
				last;
			}
		}
		if ( defined($index_of_last_non_zero) )
		{
			$i = 0;
			my $stop = $index_of_last_non_zero + 1;
			while ( $i < $stop )
			{
				my $x = $intv * $i + $min;
				my $y = $data->[$i];
				print FILE  "$x $y\n" ;
				$i++;
			}
		}
		else
		{
			print FILE "All buckets heights are zero.  i.e you " .
				"didn't load at least one difference."
		}
		close(FILE);
	}
	return ( -f $path );
}

1;
