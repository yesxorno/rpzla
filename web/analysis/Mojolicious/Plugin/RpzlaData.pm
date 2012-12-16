package Mojolicious::Plugin::RpzlaData;
use Mojo::Base 'Mojolicious::Plugin';

use DBI;


#
#  Change of TACK:
#
#  Schema / minimal privileges are too hard for now.
#
#  There is the use of 'schema' in many selection routines.
#
#  It is ignored for now, but left in place.

######################################################################
#
# Data gathering for RPZ Log Analysis.  Database connection and
# data retrieval.  All we do is query data.  Thus all the 'heavy
# lifting' is done in the database with view creation.  We just 
# select * from view.
#

#
# NOTE:
#
# The entire database design is based on having all the queries 
# stored as views.  This means that for any query we are just
# doing a 'select * from <view>'.  Thus, we can do all the 
# work with just a few routines.

# Search titles keyed on table (view) name
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

# Connect to DB based on supplied credentials
sub get_dbh($)
{
	my $cred = shift;
	my $type = $cred->{type};
	my $host = $cred->{host};
	my $port = $cred->{port};
	my $db   = $cred->{name};
	my $user = $cred->{user};
	my $pass = $cred->{pass};
	# my $user = $cred->{analysis}->{user};
	# my $pass = $cred->{analysis}->{pass};
	my $dsn = "DBI:$type:database=$db;host=$host";
	if ( 0 < length($port) )
	{
		$dsn .= ";port=$port";
	}
	my $dbh = DBI->connect($dsn, $user, $pass)
		or die $DBI::errstr;
	return $dbh
};

######################################################################
#
# Database queries
#

# retrive all rows, and add column headers
sub get_all($$)
{
	my ($dbh, $sql) = @_;
	my $sth = $dbh->prepare($sql);
	my $result = [ ];
	my @col_names = ( );
	if ( !defined($sth) )
	{
		die $DBI::errstr;
	}
	else
	{
		$sth->execute();
		@col_names = $sth->{NAME};

	}
	$result = $sth->fetchall_arrayref();
	unshift(@{$result}, @col_names);
	return $result;
};

sub select_all($$$)
{
	my ($dbh, $table, $where) = @_;
	my $sql = "select * from $table $where";
	return get_all($dbh, $sql);
};

#
# The master 'get it all' routine.  Give me the handle, schema and table, 
# and you get the page title and data.
#
sub get_db_data($$$$)
{
	my ($dbh, $schema, $table, $where) = @_;
	return select_all($dbh, $table, $where);
};

# Radio is essentially a bunch of enums.  Check.
sub radio_valid($)
{
	my $r = shift;
	my $data_type = $r->{'data_type'};
	my $summarize = $r->{'summarize'};
	my $period = $r->{'period'};
	return
	(
		(
			$data_type eq 'dns'
		or
			$data_type eq 'web'
		or
			$data_type eq 'cor_dns'
		or
			$data_type eq 'cor_web'
		)
	and
		(
			$summarize eq 'frequency'
		or
			$summarize eq 'all'
		)
	and
		(
			$period eq 'day'
		or
			$period eq 'week'
		or
			$period eq 'month'
		)
	)
}

# Can translate the radio into the relevant view from which to select
sub radio_to_view($)
{
	my $radio = shift;
	my $view = undef;
	if ( 'dns' eq $radio->{'data_type'} )
	{
		$view = 'dns_' . $radio->{period} . '_' . $radio->{summarize};
	}
	elsif ( 'web' eq $radio->{'data_type'} )
	{
		$view = 'web_' . $radio->{period} . '_' . $radio->{summarize};
	}
	elsif ( 'cor_web' eq $radio->{'data_type'} )
	{
		$view = 'cor_' . $radio->{period} . '_web';
	}
	elsif ( 'cor_dns' eq $radio->{'data_type'} )
	{
		$view = 'cor_' . $radio->{period} . '_dns';
	}
	else
	{
		# ABORT: invalid data type
		die("Invalid data type requested.");
	}
	return $view;
}

# We trust the front end to only supply valid data: make the where clause
sub make_where_clause($)
{
	my $where = shift;
	my $retval = '';
	if 
	( 
		defined($where->{'col_name'})
	and
		defined($where->{'col_op'})
	and
		defined($where->{'col_value'})
	)
	{
		$retval = join
		(
			' ',
			'where',
			$where->{'col_name'},
			$where->{'col_op'},
			"'" . $where->{'col_value'} . "'"
		);
	}
	return $retval;
}

######################################################################
#
# Plugin routines.
#

#
# The master 'get data' uses the values of the radio buttons to 
# determine the requested data type.  Essentially, the radio buttons
# determine a view from which we select all and add commentary (title,
# column names and number of rows fetched).
#
sub get_data
{
	my ($db_creds, $page_data) = @_;
	my $dbh = get_dbh($db_creds);
	# pull out radio and where for processing
	my $radio = $page_data->{radio};
	my $where = $page_data->{where};
	# Currently unused: aborted the tricky schema based roles
	my $schema = $db_creds->{schema};
	# Convert the radio choices to view name in DB
	my $view = radio_to_view($radio);
	# Convert where selection to where clause
	my $where_clause = make_where_clause($where);
	# Grab the data
	$page_data->{data} = get_db_data($dbh, $schema, $view, $where_clause);
	# Set heading for data page
	$page_data->{title} = $title{$view};
	$dbh->disconnect();
	# Add num rows comment
	if ( defined($page_data) )
	{
		my $num_rows = scalar(@{$page_data->{data}}) - 1;
		my $comment = '';
		if ( 0 == $num_rows )
		{
			$comment .= "No matching data.";
		}
		elsif ( 1 == $num_rows )
		{
			$comment = "$num_rows row";
		}
		elsif ( 1 < $num_rows )
		{
			$comment = "$num_rows rows";
		}
		else
		{
			$comment = "The world has gone crazy. Negative number of row returned from query.";
		}
		$page_data->{comment} = [ $comment ];
	}
	return 1;
	# return $page_data;
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
		get_data => sub 
		{ 
			my ($self, $db_creds, $page_data) = @_;
			return get_data($db_creds, $page_data);
		}
	);
};

1;
