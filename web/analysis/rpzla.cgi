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
my $tpl_config =
{
	name		=>  undef,  # identifier for each page
	page_data	=>  undef,  # only used by data pages
};

# Hashref of information to be passed to the template for data rendering
#
my $db_data = 
{
	radio		=> undef, # buttons on the selection panel
	where		=> undef, # pulldowns (Restrict) on the selection panel
	data		=> undef, # data from the database
	cols		=> undef, # col names returned from db for easy access
	comments	=> undef, # any additional commentary
};

# Note: This class adds methods to 'self'.  Thus, if you cant find the
# self->some_method(arg,...) look in Mojolicious/Plugin/RpzlaData.pm
plugin 'RpzlaData';

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
	my $summarize = $self->param('summarize');
	my $format = $self->param('format');
	# set from the form
	$radio{'data_type'} = $data_type;
	$radio{'period'} = $period;
	$radio{'summarize'} = $summarize;
	$radio{'format'} = $format;
	# override with defaults (form may have unspecified values)
	if ( !defined($data_type) or '' eq $data_type )
	{
		$radio{'data_type'} = 'web';
	}
	if ( !defined($period) or '' eq $period )
	{
		$radio{'period'} = 'week';
	}
	if ( !defined($summarize) or '' eq $summarize )
	{
		$radio{'summarize'} = 'frequency';
	}
	if ( !defined($format) or '' eq $format )
	{
		$radio{'format'} = 'html';
	}
	return \%radio;
};

# Inquire as to the states of the where clause
#
helper where_states => sub
{
	my $self = shift;
	my %where = ();
	my $col_name = $self->param('col_name');
	my $col_op = $self->param('col_op');
	my $col_value = trim($self->param('col_value'));
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
	return \%where;
};

#
# Pull all of the database config from the config file
#
sub get_db_from_config()
{
	my $conf = new Config::General('rpzla.conf');
	my %config = $conf->getall();
	return $config{db};
}

##################################
#
# Actual page handling
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
	if ( defined($db_data->{radio}) )
	{
		$tpl_config->{format} = $db_data->{radio}->{format};
	}
	$tpl_config->{page_data} = $db_data;
	$self->render_page('data');
};

#
# The simple page splatter
#
helper render_page => sub
{
	my ($self, $name) = @_;
	$tpl_config->{name} = $name;
	my $format = 'html';
	if ( defined($db_data->{radio}->{format}) )
	{
		$format = $db_data->{radio}->{format};
	}
	$self->stash($tpl_config);
	$self->render
	(
		template => 'rpzla',
		format => $format,
	);
};

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

get '/data' => sub {
	my $self = shift;
	$db_data->{radio} = $self->radio_states();
	$db_data->{where} = $self->where_states();
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
	$db_data->{where} = $self->where_states();
	# fetch data
	$self->get_data($db_creds, $db_data);
	# render
	$self->render_data_page(1);
};

# gobbledygook our cookie data
app->secret('rpzla42dogsonastick');
# lets play
app->start;
