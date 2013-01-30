#!/usr/bin/perl 
package RPZLA::Analysis::DateTimeSupport;

use warnings;
use strict;

use Carp;
use DateTime;
use DateTime::Duration;
use Class::Struct;

#####################################################################
#
# Purpose:
#
# Solve the DateTime challenge.  Simplify for Analysis tools.
#

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

# convert a duration to seconds, including fractional seconds.
sub duration_to_sec($)
{
        my $dur = shift;
	# give a float
	my $fl = $dur->seconds . '.' . $dur->nanoseconds;
	return 1.0 * $fl; 
}

# subtract two dates and give the difference in seconds.
sub date_diff_to_sec($$)
{
	my ($self, $d1, $d2) = @_;
	return $self->durationt_to_sec($d1->subtract_datetime_absolute($d2));
}

# Create a DateTime with optional fractional seconds from an ISO date string.
sub iso_to_datetime($$)
{
	my ($self, $s) = @_;
	$_ = $s;
	my $dt = undef;;
        if ( m/(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)([.]\d+)/ )
        {
                my ($Y, $M, $D, $h, $m, $s, $n) = ($1, $2, $3, $4, $5, $6, $7);
                $n = $n * 1000000000;
                $dt = DateTime->new
                (
                        year => $Y, month => $M, day => $D,
                        hour => $h, minute => $m, second => $s,
                        nanosecond => $n,
                        time_zone => $self->{tz},
                );
        }
        elsif ( m/(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ )
        {
                my ($Y, $M, $D, $h, $m, $s) = ($1, $2, $3, $4, $5, $6);
                $dt = DateTime->new
                (
                        year => $Y, month => $M, day => $D,
                        hour => $h, minute => $m, second => $s,
                        time_zone => $self->{tz},
		die("Not an ISO date.");
	}
	return $dt;
}
