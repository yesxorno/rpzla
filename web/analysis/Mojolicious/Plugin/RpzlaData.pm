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

sub select_all($$)
{
	my ($dbh, $table) = @_;
	my $sql = "select * from $table";
	return get_all($dbh, $sql);
};

#
# The master 'get it all' routine.  Give me the handle, schema and table, 
# and you get the page title and data.
#
sub get_db_data($$$)
{
	my ($dbh, $schema, $table) = @_;
	return 
	{
		'title' => $title{$table},
		# 'data' => select_all($dbh, "$schema.$table")
		'data' => select_all($dbh, $table)
	};
};


######################################################################
#
# 'get_data' routines (for each data type)
#

sub get_dns_data($$$)
{
	my ($dbh, $schema, $radio) = @_;
	my $data = { };
	if ( 'frequency' eq $radio->{summarize} )
	{
		if ( 'day' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'dns_day_frequency');
		}
		elsif ( 'week' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'dns_week_frequency');
		}
		elsif ( 'month' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'dns_month_frequency');
		}
	}
	elsif ( 'all' eq $radio->{summarize} )
	{
		if ( 'day' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'dns_day_all');
		}
		elsif ( 'week' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'dns_week_all');
		}
		elsif ( 'month' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'dns_month_all');
		}
	}
	return $data;
};

sub get_web_data($$$)
{
	my ($dbh, $schema, $radio) = @_;
	my $data = { };
	if ( 'frequency' eq $radio->{summarize} )
	{
		if ( 'day' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'web_day_frequency');
		}
		elsif ( 'week' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'web_week_frequency');
		}
		elsif ( 'month' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'web_month_frequency');
		}
	}
	elsif ( 'all' eq $radio->{summarize} )
	{
		if ( 'day' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'web_day_all');
		}
		elsif ( 'week' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'web_week_all');
		}
		elsif ( 'month' eq $radio->{period} )
		{
			$data = get_db_data($dbh, $schema, 'web_month_all');
		}
	}
	return $data;
};

sub get_cor_web_data($$$)
{
	my ($dbh, $schema, $radio) = @_;
	my $data = { };
	if ( 'day' eq $radio->{period} )
	{
		$data = get_db_data($dbh, $schema, 'cor_day_web');
	}
	elsif ( 'week' eq $radio->{period} )
	{
		$data = get_db_data($dbh, $schema, 'cor_week_web');
	}
	elsif ( 'month' eq $radio->{period} )
	{
		$data = get_db_data($dbh, $schema, 'cor_month_web');
	}
	return $data;
};

sub get_cor_dns_data($$$)
{
	my ($dbh, $schema, $radio) = @_;
	my $data = { };
	if ( 'day' eq $radio->{period} )
	{
		$data = get_db_data($dbh, $schema, 'cor_day_dns');
	}
	elsif ( 'week' eq $radio->{period} )
	{
		$data = get_db_data($dbh, $schema, 'cor_week_dns');
	}
	elsif ( 'month' eq $radio->{period} )
	{
		$data = get_db_data($dbh, $schema, 'cor_month_dns');
	}
	return $data;
};

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
	my ($db_creds, $radio) = @_;
	my $dbh = get_dbh($db_creds);
	my $schema = $db_creds->{schema};
	my $data = undef;
	# first level split of the radio values
	if ( 'dns' eq $radio->{'data_type'} )
	{
		$data = get_dns_data($dbh, $schema, $radio);
	}
	elsif ( 'web' eq $radio->{'data_type'} )
	{
		$data = get_web_data($dbh, $schema, $radio);
	}
	elsif ( 'cor_web' eq $radio->{'data_type'} )
	{
		$data = get_cor_web_data($dbh, $schema, $radio);
	}
	elsif ( 'cor_dns' eq $radio->{'data_type'} )
	{
		$data = get_cor_dns_data($dbh, $schema, $radio);
	}
	$dbh->disconnect();
	if ( defined($data) )
	{
		my $num_rows = scalar(@{$data->{data}}) - 1;
		my $comment = '';
		if ( 0 == $num_rows )
		{
			$comment .= "No data in period.";
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
		$data->{comment} = [ $comment ];
	}
	return $data;
};

#
# TODO:
#
# Development idea.  Provide the use with a list of the view, and
# they can just click on a view to see its data.
#
# Not working yet.

# return a list of the view names in the database
sub get_views($)
{
	my $db_creds = shift;
	my $dbh = get_dbh($db_creds);
	my @views = $dbh->tables
	(
		'', '', $db_creds->{name}, 'VIEW', {noprefix=>1}
	);
	my $num_views = scalar(@views);
	my $data = 
	{
		'title' 	=> 'List of Views',
		'comment' 	=> [ "Plugin framework: $num_views views" ],
		'data'		=> [ @views ],
	};
	$dbh->disconnect();
	return $data;
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
		get_data => sub 
		{ 
			my ($self, $db_creds, $radio) = @_;
			return get_data($db_creds, $radio); 
		}
	);
	$app->helper
	(
		get_views => sub 
		{ 
			my ($self, $db_creds) = @_;
			return get_views($db_creds);
		}
	);
};

1;
