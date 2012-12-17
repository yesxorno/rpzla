package Mojolicious::Plugin::RpzlaAnalysis;
use Mojo::Base 'Mojolicious::Plugin';
use DateTime;
use DateTime::Duration;
use POSIX;

# Take the data produced by RpzlaData and turn it into graphable info

# Some defaults for difference graphs
use constant OFFSET_MAX		=> 5400;  	# 1.5 hours in seconds
use constant OFFSET_WIDTH_SEC	=> 2;  		# events within 2 seconds
use constant OFFSET_WIDTH_TEXT	=> '2 seconds';	# events within 2 seconds

######################################################################
#
# Plugin routines.
#

sub add_tz($)
{
	my $retval = shift; # !!
	# get current time (just for the is daylight savings time [isdst])
	my @current_time = localtime(time());
	# get names of both time zones
	my ($winter, $summer) = POSIX::tzname();
	if ( $current_time[8] )
	{
		$retval->{tz} = $summer;
	}
	else
	{
		$retval->{tz} = $winter; # standard time
	}
	return $retval;
}

# Convert a lovely ISO date from Postgres to a perl DateTime
sub datetime_to_DateTime($$)
{
	my ($s, $tz) = @_;
	my $dt = undef;
	if ( $s =~ m/(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ )
	{
		my ($Y, $M, $D, $h, $m, $s, $n) = ($1, $2, $3, $4, $5, $6, $7);
		$dt = DateTime->new
		(
			year => $Y, month => $M, day => $D,
			hour => $h, minute => $m, second => $s,
			time_zone => $tz,
		);
	}
	else
	{
		# TODO
		# Need a much better mechanism that this
		die("bad date format from database");
	}
	return $dt;
}

# diff (offset) data
sub offset_data()
{
	my $retval = 
	{
		offset_max_sec		=> OFFSET_MAX(),
		offset_interval_sec	=> OFFSET_WIDTH_SEC(),
		offset_interval_text	=> OFFSET_WIDTH_TEXT(),
		offset_interval_dt	=> undef,
	};
	$retval = add_tz($retval);
	# convert to DateTime::Duration
	$retval->{offset_width_dt} = DateTime::Duration->new(
		seconds => $retval->{offset_interval_sec}
	);
	return $retval;
}

# create and initialise an array for offset data based on the definition.
sub offset_init($)
{
	my $offset_def = shift;
	my $len = $offset_def->{offset_max_sec} / 
		$offset_def->{offset_interval_sec};
	my @data = ( );
	my $i = 0;
	while ( $i < $len )
	{
		$data[$i] = 0; $i++;
	}
	$offset_def->{data} = \@data;
	return 1;
}

# graph area is 1300, thus div 4 allows 325 buckets showable.
# 1 day is    1440 minutes:   5 minute buckets is 288 
# 1 week is  10080 minutes:  32 minute buckets is 315
# 1 month is 43200 minutes: 150 minute buckets is 288

sub period_data($)
{
	my $period = shift;
	my $retval = 
	{
		bucket_num		=> undef,
		bucket_width_sec	=> undef,
		bucket_width_text	=> undef,
		bucket_width_dt		=> undef,
	};
	$retval = add_tz($retval);
	if ( 'day' eq $period )
	{
		$retval->{bucket_num} = 288;
		$retval->{bucket_width_sec} = 300; # seconds
		$retval->{bucket_width_text} = '5 minutes'; # seconds
	}
	elsif ( 'week' eq $period )
	{
		$retval->{bucket_num} = 315;
		$retval->{bucket_width_sec} = 1920; # seconds
		$retval->{bucket_width_text} = '32 minutes'; # seconds
	}
	if ( 'month' eq $period )
	{
		$retval->{bucket_num} = 288;
		$retval->{bucket_width_sec} = 9000; # seconds
		$retval->{bucket_width_text} = '2.5 hours'; # seconds
	}
	# convert to DateTime::Duration
	$retval->{bucket_width_dt} = DateTime::Duration->new(
		seconds => $retval->{bucket_width_sec}
	);
	return $retval;
}

# Convert a sequence of datatime from the DB into buckets of numbers
# based on a period.
#
# Looked to use the DB, but seems very complex and silly (probably faster)
#
# Gimme the data (first column is the datetimes) and a period
# Return an array reference with time divided as best as possible
# for the period.
sub get_graph_linear($$)
{
	my ($data, $period) = @_;
	my $retval = period_data($period);
	my $now = DateTime->now(time_zone => $retval->{tz});
	$retval->{period_start} = $now->datetime();
	# counters
	my $curr_bucket =  0;
	my $num_records = scalar(@{$data});
	# Time/Duration values
	my $curr_bucket_end = $now->subtract_duration
	(
		$retval->{bucket_width_dt}
	);
	# initialise buckets at 0 (there really should be a smarter way ...)
	my @bucket = ( );
	my $i = 0; 
	my $num_buckets = $retval->{bucket_num};
	while ( $i < $num_buckets )
	{
		push(@bucket, 0);
		$i++;
	}
	# skip first data row (col names)
	$i = 1;
	my $bucket_non_zero = 0;
	my $bucket_total_records = 0;
	while ( $i < $num_records and $curr_bucket < $num_buckets )
	{
		my $rec = datetime_to_DateTime
		(
			$data->[$i]->[0], $retval->{tz}
		);
		if 
		( 
			1 == DateTime::compare
			(
				$rec, $curr_bucket_end
			) 
		)
		{
			# within the bucket
			$bucket_non_zero++ if ( 0 == $bucket[$curr_bucket] );
			$bucket[$curr_bucket]++;
			$bucket_total_records++;
			$i++;
		}
		else
		{
			# move to next bucket
			$curr_bucket++;
			$curr_bucket_end->subtract_duration
			(
				$retval->{bucket_width_dt}
			);
		}
	}
	$retval->{data} = \@bucket;
	$retval->{bucket_non_zero} = $bucket_non_zero;
	$retval->{bucket_total_records} = $bucket_total_records;
	return $retval;
};

# remove trailing zeros from the timing data.  Makes graphs nicer
sub offset_prune_trailing_zeros($)
{
	my $data = shift;
	my $len = scalar(@{$data});
	my $i = $len - 1;
	while ( 0 == $data->[$i] )
	{
		pop(@{$data});
		$i--;
	}
}

# Differential timing analysis
sub  get_graph_offset($)
{
	my $input = shift;
	my $retval = offset_data();
	offset_init($retval);
	# offset is buckets of difference in time between events from $input
	my $end = scalar(@{$input});
	my $col_index = 0; # the datetime column
	my $offset_non_zero = 0;
	my $prev = datetime_to_DateTime
	(
		$input->[1]->[$col_index], $retval->{tz}
	);
	my $curr = undef;
	my $i = 2; # skip first row (col names), and start with the second data
	while ( $i < $end )
	{
		$curr = datetime_to_DateTime
		(
			$input->[$i]->[$col_index], $retval->{tz}
		);
		# make comparison ... and assign
		my $delta_dur = $prev->subtract_datetime_absolute($curr);
		my $diff = $delta_dur->seconds();
		if ( $diff < $retval->{offset_max_sec} )
		{
			# Find the bucket
			my $offset= int($diff / $retval->{offset_interval_sec});
			if ( 0 == $retval->{data}->[$offset] )
			{
				$offset_non_zero++;
			}
			$retval->{data}->[$offset]++;
		}
		$prev = $curr;
		$i++;
	}
	my $total = 0;
	for my $val ( @{$retval->{data}} )
	{
		$total += $val;
	}
	$retval->{offset_non_zero} = $offset_non_zero;
	$retval->{input_records} = $end - 1;
	$retval->{total_differences} = $total;
	offset_prune_trailing_zeros($retval->{data});
	return $retval;
}

sub  get_graph_freq($)
{
	my $input = shift;
	my @data = ();
	my $total = 0;
	my $end = scalar(@{$input});
	my $i = 1; # skip first row (col names)
	while ( $i < $end )
	{
		# Must have 'count' as the second column
		my $value = $input->[$i]->[1];
		$total += $value;
		push(@data, $value);
		$i++;
	}
	my @sorted = sort {$b <=> $a} @data;
	return
	{
		data	=> \@sorted,
		records	=> $end - 1,
		total	=> $total,
	};
}

######################################################################
#
# Registration
#

# use 'register' to make the 'plugin' into a 'helper' for the app
# i.e it gets added as a member function for the app.
sub register {
	my ($self, $app) = @_;
	$app->helper
	(
		get_graph_linear => sub 
		{ 
			my ($self, $data, $period) = @_;
			return get_graph_linear($data, $period);
		}
	);
	$app->helper
	(
		get_graph_freq => sub 
		{ 
			my ($self, $data) = @_;
			return get_graph_freq($data);
		}
	);
	$app->helper
	(
		get_graph_offset => sub 
		{ 
			my ($self, $data) = @_;
			return get_graph_offset($data);
		}
	);
};

1;
