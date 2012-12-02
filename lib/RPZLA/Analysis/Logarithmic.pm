#!/usr/bin/perl 
package RPZLA::Analysis::Logarithmic;

use warnings;
use strict;

use Class::Struct;

use constant	LOG_DROP_PERCENT	=> '45'; # in %. if we find this, done.

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
		'bucket'	=> '$',
	}
);
#####################################################################
#
# Methods

sub is_log_decay()
{
	my $self = shift;
	my $retval = 0;
	my $data = $self->bucket->get_sorted(0);
	my $total = $self->bucket->buckets_total();
	# pull off the first record
	my $sum = shift(@{$data});
	print "[Total / Current / Drop %]\n";
	for my $this_value ( @{$data} )
	{
		my $drop_percent = (($sum - $this_value) / $total) * 100;
		print "[$total / $sum / $drop_percent]\n";
		if ( $drop_percent > LOG_DROP_PERCENT() )
		{
			# Stop analysis: pattern found
			$retval = 1;
			print "Done: drop is enough\n";
			last;
		}
		$sum += $this_value;
		if ( LOG_DROP_PERCENT() > ($sum / $total) * 100 )
		{
			# stop looking, we'll never find it
			print "Done: no Drop can be found\n";
			last;
		}
	}
	return $retval;
}

1;
