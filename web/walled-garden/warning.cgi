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
	my $headers = Mojo::Headers->new();
	my $referrer = $headers->referrer();
	my $comments = 
	[ 
		'blah blah',
		'Referrer: ' . $referrer,
	];
	my $page_data =
	{
		'title'	=> 'Visiting Dangerous Sites',
		'comment' => $comments,
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
		$title,
		'Nasty world'
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
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
	<title>RPZ Log Analysis</title>
	<link rel="stylesheet" type="text/css" href="/style.css" />
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
			<h2><%= $site_title %></h2>
		</td>
	</tr>
	</table>
	</div>

	<div id="nav">
	<hr />
		<table width="100%">
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

