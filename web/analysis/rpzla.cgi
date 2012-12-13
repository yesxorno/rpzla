#!/usr/bin/env perl
use Mojolicious::Lite;
use Config::General;
use String::Util 'trim';

use constant	PAGE_HOME 	=> "Welcome to RPZ Log Analysis";
use constant	PAGE_HELP 	=> "Here is the help";

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

sub radio_checked($$$)
{
	my ($hash, $key, $value) = @_;
	my $retval = '';
	if ( $hash->{$key} eq $value )
	{
		$retval = 'checked';
	}
	return $retval;
}

##################################
#
# Actual page handling
#

#
# The general page splatter (assigns data and calls the template)
#
helper render_page => sub
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
	my @col_names = @{$data->{data}[0]};
	# remove the datetime (no point matching that)
	shift(@col_names);
	$self->stash
	(
		page_data => $data,
		radio => $radio,
		where => $where,
		cols => \@col_names,
	);
	$self->render('rpzla', format=>$radio->{'format'});
};

#
# The 'home' page
#
get '/' => sub {
	my $self = shift;
	my $comments = [ 
		'Welcome to RPZ Log Analysis.',
		'An introduction to the site and its purpose is available ' .
		'from <a href="/about">About</a>.',
		'Details of the data selection choices available with ' .
		'the radio button groups on the right is available under ' .
		'<a href="/help">Help</a>',
	];
	my $page_data =
	{
		'title' => 'Home',
		'comment' => $comments,
	};
	$self->render_page($page_data);
};

#
# The 'about' page
#
get '/about' => sub {
	my $self = shift;
	my $comments = [ 
		'The RPZ Log Analysis site provides a high level overview of data gathered from recursive DNS resolvers implementing Response Policy Zones and a Walled Garden (as it is known in the RPZ literature) web site.',
		'By tracking the logs from the DNS\'s implementing RPZ we can determine which systems are visiting potentially hazardous domains.  These attempted visits are either human generated (e.g click link in nasty email) or not (e.g malware on the system wants to call home).',
		'By implementing a walled garden site, and tracking its logs we can attempt to differentiate between the two types of request.  In general, a person using a web browser will end up at the walled garden, thus generating two pieces of log data, the DNS request and the Walled Garden visit.  Conversely, a piece of malware is only likely to generate the DNS log record.  (There will, of course, be false positives if the "malware" is speaking HTTP and following CNAME DNS reponses such that it totally mimics a browser).',
		'This site allows you to view the data gathered from the DNS resolver(s) and the walled garden during some recent period either as raw data, or in a summarized aggregate form (number of visits per client).',
		'Additionally, one can use the `Correlated` data of "DNS + Web" or "DNS - Web".  The first shows systems where a RPZ response to a DNS lookup resulted in a view of the walled garden (i.e a human using a brower to visit suspicious sites).  The second show the other case, where an RPZ response does <em>not</em> result in a visit to the walled garden (probably malware).'
	];
	my $page_data =
	{
		'title' => 'About',
		'comment' => $comments,
	};
	$self->render_page($page_data);
};

#
# The 'help' page
#
get '/help' => sub {
	my $self = shift;
	my $comments = [ 
		'For a general introduction, see <a href="/about">About</a>.',
		'The 4 Data types are: <ol>' .
		'<li><strong>DNS</strong> shows DNS lookups of potentially ' .
		'dangerous sites (as defined by your Response Policy Zones)' .
		'</li>' .
		'<li><strong>Web</strong> shows the page hits to your walled ' .
		'garden web-site.  This data indicates people using a web ' .
		'browser to visit potentially dangerous sites, or people just '.
		'visiting the walled garden for the fun of it.</li>'.
		'<li><strong>DNS + Web</strong> shows the number of correlations between the DNS and Web data.  These entries indicate an RPZ response to a DNS lookup that then results in a visit to the walled garden (e.g people clicking dangerous links in email).</li>' .
		'<li><strong>DNS - Web</strong> shows the RPZ responses to a DNS lookup that did <em>not</em> result in a walled garden page view.  This indicates probable malware activity.</li></ol>',
		'There are 3 periods of data viewing, the last day, week or month (30 days).',
		'For the Raw Data views (DNS and Web), one may see all of the data, or just a count (Frequency) that occurred duing the period for each client.  When Frequency view is used, the data is grouped into "buckets" of time equal to the period.  i.e Web data with a weekly period in frequency view shows all visits to the walled garden from all hosts in the last week.',
		'For the Web data the value listed in the <em>client_hostname</em> column is the result of a reverse lookup on the IP at the time of page view.  The data is grouped by hostname and IP address.  If these change dramatically overtime, the data may be somewhat difficult to interpret.  Hopefully the client_hostname is a constant.',
		'The choice of Summarize (All / Frequency) is <em>ignored</em> for the Correlated data ("DNS + Web" and "DNS - Web").  Frequency style data is always shown.',
		'Data can be viewed (Format) as a web page, of as just text.  The text version is potentially useful in auto-generating reports.',
	];
	my $page_data =
	{
		'title' => 'Help',
		'comment' => $comments,
	};
	$self->render_page($page_data);
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

#
# Actual splating of real data based on the radio button choices
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
	# grab the radio states
	#
	my $radio = $self->radio_states();
	my $where = $self->where_states();
	# fetch data
	my $data = $self->get_data($db_creds, $radio, $where);
	# render
	$self->render_page($data);
};

#
# Failed attempt to just splat all the view names from the database.
# DBI doco for Pg does not give us what we want.
#
# Aaaarg.
#
# Does NOT WORK.
#
get '/views' => sub
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
	# grab the radio states
	#
	my $radio = $self->radio_states();
	# fetch data
	my $data = $self->get_views($db_creds);
	# render
	$self->render_page($data);
};

# gobbledygook our cookie data
app->secret('rpzla42dogsonastick');
# lets play
app->start;

__DATA__

# The Template

@@ rpzla.html.ep
<!DOCTYPE HTML>
<!DOCTYPE HTML>
<html lang="en">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<title>RPZ Log Analysis</title>
	<link rel="stylesheet" type="text/css" href="/style.css" />
	<!-- nasty javascript, but sets the 'Load' button as focussed
	 so that you just press Return to 'load' the settings -->
	<script type="text/javascript">
	window.onload = function() {
		document.getElementById('submit').focus();
	}
	</script>
</head>
<body>
<div id="wrap">
	<div id="header">
	<table width="100%">
	<tr>
		<td width="25%">
			<a href="/"><img src="/logo.png" align="left"/></a>
		</td>
		<td width="75%">
			<h2>RPZ Log Analysis</h2>
		</td>
	</tr>
	</table>
	</div>

	<div id="nav">
	<hr />
		<table width="100%">
		<tr>
			<td align="left"><a href="/">Home</a></td>
			<td align="right"><a href="/help">Help</a>&nbsp;&nbsp;&nbsp;&nbsp;<a href="/about">About</a> </td>
		</tr>
		</table>
		<hr />
	</div>

	<div id="selection">

	<!-- The big 'radio groups sidebar' should really be an object -->
	<form name="choose" method="post" action="/data">
		<center>
		<table>

		<tr>

		<td id="choose">
		<strong>Raw Data</strong><br />
		<input type="radio" name="data_type" value="dns" 
		<%= $radio->{'data_type'} eq 'dns' ? 'checked' : '' %> />
			DNS
		<br />
		<input type="radio" name="data_type" value="web" 
		<%= $radio->{'data_type'} eq 'web' ? 'checked' : '' %> />
			Web
		</td>

		<td>
		<strong>Correlated Data</strong><br />
		<input type="radio" name="data_type" value="cor_web" 
		<%= $radio->{'data_type'} eq 'cor_web' ? 'checked' : '' %> />
			DNS + Web
		<br />
		<input type="radio" name="data_type" value="cor_dns" 
		<%= $radio->{'data_type'} eq 'cor_dns' ? 'checked' : '' %> />
			DNS - Web
		</td>

		<td>
		<strong>Period</strong><br />
		<input type="radio" name="period" value="day" 
		<%= $radio->{'period'} eq 'day' ? 'checked' : '' %>/>
			Day
		<br />
		<input type="radio" name="period" value="week" 
		<%= $radio->{'period'} eq 'week' ? 'checked' : '' %>/>
			Week
		<br />
		<input type="radio" name="period" value="month" 
		<%= $radio->{'period'} eq 'month' ? 'checked' : '' %>/>
			Month
		</td>
		<td>
		<strong>Summarize</strong><br />
		<input type="radio" name="summarize" value="frequency" 
		<%= $radio->{'summarize'} eq 'frequency' ? 'checked' : '' %>
		/>
			Frequency
		<br />
		<input type="radio" name="summarize" value="all" 
		<%= $radio->{'summarize'} eq 'all' ? 'checked' : '' %>
		/>
			All
		</td>
		<td>
		<strong>Format</strong><br />
		<input type="radio" name="format" value="html" 
		<%= $radio->{'format'} eq 'html' ? 'checked' : '' %>
		/>
			HTML
		<br />
		<input type="radio" name="format" value="text" 
		<%= $radio->{'format'} eq 'text' ? 'checked' : '' %>
		/>
			Text
		</td>

		<td>
		<strong>Restrict as</strong><br />
		<select name="col_name">
		%	foreach my $col ( @$cols )
		% {
			<option <%= $where->{'col_name'} eq $col ? 'selected' : '' %> > <%= $col %> </option>
		% }
		</select>
		&nbsp;
		<select name="col_op">
			<option>=</option>
			<option>!=</option>
		</select>
		<br />
		<input name="col_value" type="text" 
		value="<%= $where->{'col_value'} %>"
		/>
		</td>
		</tr>
		<tr>
		<td colspan="6"> 
			<center><input name="submit" type="submit" value="Load Selection" /></center>
		</td>
		</tr>
		</table>
		</center>
	</form>
	</div>

	<hr />

	<div id="main">

		<h3> <%= $page_data->{title} %> </h3>

		% foreach my $c ( @{$page_data->{comment}} )
		% {
		<p> <%== $c %> </p>
		% }

		<table width="100%" >
		% my $i = 0;
		% foreach my $row ( @{$page_data->{data}} )
		% {
			<tr>
		%	foreach my $cell ( @$row )
		%	{
				<%== (0 == $i) ? '<th align="left">' : '<td>' %>
				<%= $cell %>
				<%== (0 == $i) ? '</th>' : '</td>' %>
		%	}
		%	$i++;
			</tr>
		% }
		</table>
	</div>

	<div id="footer">
		<hr />
		<p align="center">Standing on the Shoulders of Giants</p>
	</div>


</div>
</body>
</html>


@@ rpzla.text.ep
<%= $page_data->{title} %>

% foreach my $c ( @{$page_data->{comment}} )
% {
* <%== $c %>
% }

% my $i = 0;
% foreach my $row ( @{$page_data->{data}} )
% {
<%= join(' ', @{$row}) %>
% if ( 0 == $i ) 
% { 
%	$i = 1; 
	<%= '' %> 
% }
% }
