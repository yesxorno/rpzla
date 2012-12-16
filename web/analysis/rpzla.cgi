#!/usr/bin/env perl

use Mojolicious::Lite;
use Config::General;
use String::Util 'trim';

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
	my ($self, $data) = @_;
	my $radio = $self->radio_states();
	my $where = $self->where_states();
	# Get the column names from the queried data
	# strip the 'datetime' column and give it to the 
	# renderer for use in the Restrict column name pulldown (where clause)
	#
	# Note that converting the first row from array ref to array is
	# important, else when we 'shift' it, we *lose* the column name.
	#
	my @col_names = ();
	if ( defined($data->{data}[0]) and 0 < length(@{$data->{data}[0]}) )
	{
		@col_names = @{$data->{data}[0]};
		# remove the datetime (no point matching that)
		shift(@col_names);
	}
	else
	{
		push
		(
			@{$data->{'comment'}}, 
			"<em>Note:</em> using Restrict can produce " .
			"no data if your value does not match anything, or " .
			"you have chosen a column and then changed the query " .
			"type (other queries may not have that column).  " .
			"Suggestion: clear the restrction and reload."
		);
	}
	$self->stash
	(
		template	=> 'rpzla',
		name 		=> 'data',
		format 		=> $radio->{'format'},
		page_data	=> $data,
		radio		=> $radio,
		where		=> $where,
		cols		=> \@col_names,
	);
	$self->render();
};

#
# The simple page splatter
#
helper render_simple_page => sub
{
	my ($self, $name) = @_;
	$self->stash(template => 'rpzla', name => $name);
	$self->render();
};

#
# The static pages (content in templates)
#
get '/' => sub {
	my $self = shift;
	$self->render_simple_page('home');
};

get '/about' => sub {
	my $self = shift;
	$self->render_simple_page('about');
};

get '/help' => sub {
	my $self = shift;
	$self->render_simple_page('help');
};

get '/data' => sub {
	my $self = shift;
	$self->render_data_page({'data' => []});
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
	my $radio = $self->radio_states();
	my $where = $self->where_states();
	# fetch data
	my $page_data = $self->get_data($db_creds, $radio, $where);
	# render
	$self->render_data_page($page_data);
};

# gobbledygook our cookie data
app->secret('rpzla42dogsonastick');
# lets play
app->start;
