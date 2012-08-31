#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::Headers;

use constant	SITE_TITLE	=> "Web Safety Net";

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
	$self->stash
	(
		site_title	=> SITE_TITLE,
		page_data 	=> $data,
	);
	$self->render('warning');
};

#
# The 'home' page
#
get '/' => sub {
	my $self = shift;
	my $headers = $self->req->headers();
	my @comments = 
	( 
		'You have arrived at this page either deliberately, or ' .
		'because you attempted to reach a web page ' .
		'that is known to merely attempt to attack ' .
		'your computer.',
		'Arriving here has saved your computer from this attack.', 
		'If you would like to know more about what is happening ' .
		'see the <a href="/about">About</a> page.',
		'For further information please contact your IT service.'
		
	);
	my $page_data =
	{
		'title'	=> 'Visiting Dangerous Sites',
		'comment' => \@comments,
	};
	$self->render_page($page_data);
};

#
# The 'about' page
#
get '/about' => sub {
	my $self = shift;
	my $title = 'About the Safety Net';
	my $comments = 
	[ 
		'The criminals that are using the internet for profit ' . 
		'based on illegal activities need to register domains to ' .
		'host their web pages that are fully of nasty software ' .
		'(malware).  The malware attempts to infect you computer ' .
		'and then force it to do nasty things like send SPAM, or ' .
		'inform the criminals of whatever you are doing on the ' .
		'internet, including sending them the password ' .
		'that you use for your bank!.',
		'Going back to 1996, ' .
		'<a href="https://en.wikipedia.org/wiki/Paul_Vixie">' . 
		'Paul Vixie</a> from the ' .
		'<a href="http://isc.org">Internet Systems ' .
		'Consortium (ISC)</a> ' .
		'which manages the most used software (BIND) for converting ' .
		'domains into internet addresses (' .
		'<a href="https://en.wikipedia.org/wiki/Domain_Name_System">' .
		'DNS</a>), began a campaign to ' .
		'combat the rise of SPAM. It was based on reputation data.  ' .
		'i.e we know that these '.
		'people are sending spam, so we will stop accepting e-mail '.
		'from them.  This approach is a cornerstone of any ' .
		'modern, comprehensive, anti-spam mechanism.',
		'This site is the saftey net for a ' .
		'<strong>new mechanism</strong>, also ' .
		'developed by Paul Vixie and the ISC, for using reputational '.
		'data about domains that are being registered and then used '.
		'by criminals to deliver malware.',
	];
	my $page_data =
	{
		'title' => $title,
		'comment' => $comments,
	};
	$self->render_page($page_data);
};

# gobbledygook our cookie data
app->secret('rpzla42dogsoffthestick');
# lets play
app->start;

__DATA__

# The Template

@@ warning.html.ep
<!DOCTYPE HTML>
<html lang="en">
<head>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	<title>RPZ Log Analysis</title>
	<link rel="stylesheet" type="text/css" href="/style.css" />
</head>
<body>
<div id="wrap">
	<div id="header">
	<table width="100%">
	<tr>
		<td width="15%">
			<a href="/"><img src="/logo.png" align="left" /></a>
		</td>
		<td width="85%">
			<h2><%= $site_title %></h2>
		</td>
	</tr>
	</table>
	</div>

	<div id="nav">
	<hr />
		<table width="90%">
		<tr>
			<td align="left"><a href="/">Home</a></td>
			<td align="right"><a href="/about">About</a> </td>
		</tr>
		</table>
	<hr />
	</div>

	<div id="main">

	<h3> <%= $page_data->{title} %> </h3>

	% foreach my $c ( @{$page_data->{comment}} )
	% {
	<p> <%== $c %> </p>
	% }

	</div>
	<div id="footer">
		<hr />
		<p align="center">Standing on the Shoulders of Giants</p>
	</div>

</div>
</body>
</html>

