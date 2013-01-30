#!/usr/bin/env perl

use Mojolicious::Lite;
use Config::General;
use String::Util 'trim';

use constant NO_DATA_HELP	=> "<em>Note:</em> when no data is returned the cause is either:
<ol>
<li> there really is no data within the period, or</li>
<li> the query is confused</li>
</ol>
<p>The second case occurs when on uses Restrict and selects a column name and then changes the query type to one that <em>does not have the column</em>.  Suggestion: clear the restrction and reload.  If you still get no data, there is none.";
use constant DEFAULT_DATA_TEXT	=> 'Please make a data selection above and load.  <br />See <a href="/help">Help</a> for more information on making selections.';
use constant DEFAULT_GRAPH_TEXT	=> 'Having fun with graphs.';

#
# Definition of the database access information.  Currently it is read
# from the config file.  You can define it here and remove the use
# of the config file, which may save a little time.  See DONT_USE_CONFIG below
#
# my $db_creds = 
# {
#	type	=> 'Pg',  # Postgres
#	host	=> 'localhost',
#	name	=> 'rpzla',
#	port	=> '',  # if blank, use default for database type
#	user	=> 'rpzla',
#	pass	=> 'something-that-you-chose',
# };

# Hashref passed to the top level config.
#
# These are the 'variables' that are directly usable by the templates
#
# 'template' and 'format' are only used by the renderer.
#
# 'name' is critical to the top level template to know which sub-templates
# to use
#
# 'page_data' is for the data rendering (rather than static) pages.
#
my $stash_data =
{
	name		=>  undef,  # identifier for each page
	page_data	=>  undef,  # only used by data pages
};

# Hashref of information to be passed to the template for data rendering
#
my $db_data = 
{
	radio		=> undef, # buttons on the selection panel
	restrict	=> undef, # pulldowns (Restrict) on the selection panel
	data		=> undef, # data from the database
	cols		=> undef, # col names returned from db for easy access
	comments	=> undef, # any additional commentary
	table		=> undef, # 1 if the HTML table should be shown
	graph		=> undef, # 1 if the Graph should be shown
	graph_data	=> undef, # data ready for java script (flot) to graph
};

####################################################################3
#
#  General routines
#

#
# Pull all of the database config from the config file
#
sub get_db_from_config()
{
	my $conf = new Config::General('rpzla.conf');
	my %config = $conf->getall();
	return $config{db};
};

# Convert an array into tuples with leading index then data, as a string
# for use in JavaScript.
# e.g (16, 4, 1) becomes "[0, 16], [1, 4], [2, 1]"
sub graph_data_to_string($)
{
	my $data = shift;
	# TODO: optimize
	my @res = ();
	my $i = 0;
	my $len = scalar(@{$data});
	while ( $i < $len )
	{
		push(@res, "[$i, " . $data->[$i] ."]");
		$i++;
	}
	my $retval = join(', ', @res);
	return $retval;
}

####################################################################3
#
#  Helpers (routines available from 'self')
#

# Inquire as to the states of the radio buttons and return a hash
# with defaults set if no value chosen.
#
# See the template below: there are 3 radio groups
#
helper radio_states => sub
{
	my $self = shift;
	my %radio = ();
	my $data_type = $self->param('data_type');
	my $period = $self->param('period');
	my $grouping = $self->param('grouping');
	my $format = $self->param('format');
	my $graph_type = $self->param('graph_type');
	# set from the form
	$radio{'data_type'} = $data_type;
	$radio{'period'} = $period;
	$radio{'grouping'} = $grouping;
	$radio{'format'} = $format;
	$radio{'graph_type'} = $graph_type;
	# override with defaults (form may have unspecified values)
	if ( !defined($data_type) or '' eq $data_type )
	{
		$radio{'data_type'} = 'web';
	}
	if ( !defined($period) or '' eq $period )
	{
		$radio{'period'} = 'week';
	}
	if ( !defined($grouping) or '' eq $grouping )
	{
		$radio{'grouping'} = 'client_ip';
	}
	if ( !defined($format) or '' eq $format )
	{
		$radio{'format'} = 'html';
	}
	if ( !defined($graph_type) or '' eq $graph_type )
	{
		$radio{'graph_type'} = 'normal';
	}
	return \%radio;
};

# Inquire as to the states of the where clause
#
helper where_states => sub
{
	my $self = shift;
	my @restrict = ();
	for my $num ( 1, 2 )
	{
		my %where = ();
		my $col_name = $self->param('col_name' . $num);
		my $col_op = $self->param('col_op' . $num);
		my $col_value = trim($self->param('col_value' . $num));
		# Check for nasties
		my $sane = 0;
		if 
		( 
			# Should actually check that is matches the column names!!!
			$col_name =~ m/\w+/
		and
			($col_op eq '=' or $col_op eq '!=')
		and
			length($col_value) > 0
		and
			# There may be better checks than this ...
			$col_value !~ m/[ '";]/
		)
		{
			$sane = 1;
		}
		if ( not $sane )
		{
			$col_name = $col_op = $col_value = undef;
		}
		$where{'col_name'} = $col_name;
		$where{'col_op'} = $col_op;
		$where{'col_value'} = $col_value;
		push(@restrict, \%where);
	}
	return \@restrict;
};

# Give the already loaded DB data to the Analysis tool for making graphs
helper make_graph_data => sub
{
	my $self = shift;
	my $graph_data = undef;
	my $grouping = $db_data->{radio}->{grouping};
	my $graph_type = $db_data->{radio}->{graph_type};
	if ( 'none' eq $grouping )
	{
		if ( 'normal' eq $graph_type )
		{
			$graph_data = $self->get_graph_linear
			(
				$db_data->{data}, 
				$db_data->{radio}->{period}
			);
			$graph_data->{graph_type} = 'bucket';
			$graph_data->{buckets_actual} = 
				scalar(@{$graph_data->{data}});
		}
		elsif ( 'difference' eq $graph_type )
		{
			$graph_data = $self->get_graph_offset
			(
				$db_data->{data}
			);
			$graph_data->{graph_type} = 'offset';
			$graph_data->{offsets_actual} = 
				scalar(@{$graph_data->{data}});
		}
	}
	else
	{
		$graph_data = $self->get_graph_freq
		(
			$db_data->{data}
		);
		$graph_data->{graph_type} = 'freq';
	}
	$graph_data->{data} = graph_data_to_string($graph_data->{data});
	return $graph_data;
};

##################################
#
# Actual page handling helpers
#

#
# The general page splatter (assigns data and calls the template)
#
helper render_data_page => sub
{
	my ($self, $data_warning) = @_;
	# Get the column names from the queried data
	# strip the 'datetime' column and give it to the 
	# renderer for use in the Restrict column name pulldown (where clause)
	#
	# Note that converting the first row from array ref to array is
	# important, else when we 'shift' it, we *lose* the column name.
	#
	if ( $data_warning )
	{
		my $col_names = [ ];
		if 
		( 
			defined($db_data->{data}[0])
		and
			0 < length(@{$db_data->{data}[0]}) )
		{
			@{$col_names} = @{$db_data->{data}[0]};
			# remove the datetime (no point matching that)
			shift(@{$col_names});
			$db_data->{cols} = $col_names;
		}
		else
		{
			push(@{$db_data->{comment}}, NO_DATA_HELP());
		}
	}
	###################################################################3
	#
	# This is getting complex: may need a re-think
	#
	###################################################################3
	my $format = $db_data->{radio}->{format};
	if ( 'text' eq $format )
	{
		$db_data->{table} = 1;
		$db_data->{graph} = 0;
	}
	elsif ( 'html' eq $format )
	{
		$db_data->{table} = 1;
		$db_data->{graph} = 0;
	}
	elsif ( 'graph' eq $format )
	{
		$db_data->{table} = 0;
		$db_data->{graph} = 1;
		$db_data->{graph_data} = $self->make_graph_data();
	}
	elsif ( 'graph+html' eq $format )
	{
		$db_data->{table} = 1;
		$db_data->{graph} = 1;
		$db_data->{graph_data} = $self->make_graph_data();
	}
	else
	{
		$self->render_page('home');  # ;-)
		return ;
	}
	$stash_data->{page_data} = $db_data;
	$self->render_page('data');
};

#
# The simple page splatter
#
helper render_page => sub
{
	my ($self, $name) = @_;
	$stash_data->{name} = $name;
	# Default to html format
	my $format = 'html';
	if 
	( 
		defined($db_data->{radio}->{format}) 
	and 
		'text' eq $db_data->{radio}->{format}
	)
	{
		$format = 'text'
	}
	$self->stash($stash_data);
	$self->render
	(
		template => 'rpzla',
		format => $format,
	);
};

####################################################################3
#
#  Route definitions (of a sort) (::Lite)
#

#
# The static pages (content in templates)
#
get '/' => sub {
	my $self = shift;
	$self->render_page('home');
};

get '/about' => sub {
	my $self = shift;
	$self->render_page('about');
};

get '/help' => sub {
	my $self = shift;
	$self->render_page('help');
};

get '/graph' => sub {
	my $self = shift;
	$self->render_page('graph');
};

get '/data' => sub {
	my $self = shift;
	$db_data->{radio} = $self->radio_states();
	$db_data->{restrict} = $self->where_states();
	# Just a get, no data to gather
	$db_data->{comment} = [ DEFAULT_DATA_TEXT() ];
	$self->render_data_page(0);
};

#
# Actual splating of real data based on the selection choice
#
post '/data' => sub
{
	my $self = shift;
	# get the db credentials from config
	#
	# Tag: DONT_USE_CONFIG
	#
	# If you dont want to incur the penalty of loading the database
	# connection details from the config file, define them at the top of 
	# file and comment out the line below
	my $db_creds = get_db_from_config();
	#
	# grab the selection
	#
	$db_data->{radio} = $self->radio_states();
	$db_data->{restrict} = $self->where_states();
	my $data_type = $db_data->{radio}->{data_type};
	if ( 'cor_web' eq $data_type or 'cor_dns' eq $data_type )
	{
		$db_data->{radio}->{grouping} = 'client_ip';
	}
	# fetch data
	$self->get_data($db_creds, $db_data);
	# render
	$self->render_data_page(1);
};

####################################################################3
#
#  Application initalisation
#

#
# Load plugins (our class objects)
#
app->plugin('RpzlaData');
app->plugin('RpzlaAnalysis');

# gobbledygook our cookie data
app->secret('rpzla42dogsonastick');
# lets play
app->start;
