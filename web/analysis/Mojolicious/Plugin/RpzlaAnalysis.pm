package Mojolicious::Plugin::RpzlaAnalysis;
use Mojo::Base 'Mojolicious::Plugin';
use DateTime;
use DateTime::Duration;

# Take the data produced by RpzlaData and turn it into graphable info

# TODO: change meaning for a graph ...
my %title =
(
	'dns_day_all'		=> 'DNS data (day)',
	'dns_week_all'		=> 'DNS data (week)',
	'dns_month_all'		=> 'DNS data (month)',
	'dns_day_frequency'	=> 'DNS aggregate (day)',
	'dns_week_frequency'	=> 'DNS aggregate (week)',
	'dns_month_frequency'	=> 'DNS aggregate (month)',
	'web_day_all'		=> 'Web data (day)',
	'web_week_all'		=> 'Web data (week)',
	'web_month_all'		=> 'Web data (month)',
	'web_day_frequency'	=> 'Web aggregate (day)',
	'web_week_frequency'	=> 'Web aggregate (week)',
	'web_month_frequency'	=> 'Web aggregate (month)',
	'cor_day_web'		=> 'Correlated data DNS + Web (day)',
	'cor_week_web'		=> 'Correlated data DNS + Web (week)',
	'cor_month_web'		=> 'Correlated data DNS + Web (month)',
	'cor_day_dns'		=> 'Correlated data DNS - Web (day)',
	'cor_week_dns'		=> 'Correlated data DNS - Web (week)',
	'cor_month_dns'		=> 'Correlated data DNS - Web (month)',
);

######################################################################
#
# Plugin routines.
#

# Convert a lovely ISO date from Postgres to a perl DateTime
sub datetime_to_DateTime($)
{
	my $s = shift;
	my $dt = undef;
	if ( $s =~ m/(\d\d\d\d)-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)/ )
	{
		my ($Y, $M, $D, $h, $m, $s) = ($1, $2, $3, $4, $5, $6);
		$dt = DateTime->new
		(
			year => $Y, month => $M, day => $D,
			hour => $h, minute => $m, second => $s,
			time_zone => 'floating'
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

# graph area is 1300, thus div 4 allows 325 buckets showable.
# 1 day is    1440 minutes:   5 minute buckets is 288 
# 1 week is  10080 minutes:  32 minute buckets is 315
# 1 month is 43200 minutes: 150 minute buckets is 288

sub period_data($)
{
	my $period = shift;
	my $retval = 
	{
		num => undef,
		width => undef,
	};
	if ( 'day' eq $period )
	{
		$retval->{num} = 288;
		$retval->{width} = 300; # seconds
		$retval->{text} = '5 minutes'; # seconds
	}
	elsif ( 'week' eq $period )
	{
		$retval->{num} = 315;
		$retval->{width} = 1920; # seconds
		$retval->{text} = '32 minutes'; # seconds
	}
	if ( 'month' eq $period )
	{
		$retval->{num} = 288;
		$retval->{width} = 9000; # seconds
		$retval->{text} = '2.5 hours'; # seconds
	}
	# convert to DateTime::Duration
	$retval->{width} = DateTime::Duration->new(
		seconds => $retval->{width}
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
sub get_graph_data_linear($$)
{
	my ($data, $period) = @_;
	my $buck_def = period_data($period);
	my $now = DateTime->now();
	# counters
	my $i = 1; # skip first data row (col names)
	my $curr_bucket =  0;
	my $num_records = scalar(@{$data});
	# Time/Duration values
	my $curr_bucket_end = $now->subtract_duration($buck_def->{width});
	my @bucket = ( 0 );
	while ( $i < $num_records )
	{
		my $rec = datetime_to_DateTime
		(
			$data->[$i]->[0]
		);
		if 
		( 
			1 == DateTime::compare_ignore_floating
			(
				$rec, $curr_bucket_end
			) 
		)
		{
			# within the bucket
			$bucket[$curr_bucket]++;
			$i++;
		}
		else
		{
			$curr_bucket++;
			# initialise new bucket to 0 !!
			$bucket[$curr_bucket] = 0;
			$curr_bucket_end->subtract_duration($buck_def->{width});
		}
	}
	return 
	{
		data => \@bucket,
		width => $buck_def->{text},  # human readable stuff
	};
};

sub get_graph_data($)
{
	my $page_data = shift;
	my $data = [3, 0, 0, 53, 12, 0, 5, 9, 0, 1, 0, 0, 19, 0, 26, 3];
	my $retval =
	{
		bucket 		=> '3 hours',
		data		=> $data,
	};
	return $retval;
};

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
		get_graph_data_linear => sub 
		{ 
			my ($self, $data, $period) = @_;
			return get_graph_data_linear($data, $period);
		}
	);
};

1;
