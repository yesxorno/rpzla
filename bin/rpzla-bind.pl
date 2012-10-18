#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(:config default no_ignore_case);
use Pod::Usage;
use File::Basename;
use English;
use Config::General;
use Proc::Daemon;
use DBI;
use File::Tail;
use Sys::Syslog qw/:standard :macros/;
use Carp;

# command-line options
use constant OPT_CONFIG		=> 'config';
use constant OPT_DEBUG		=> 'debug';
use constant OPT_HELP           => 'help';
use constant OPT_MANUAL		=> 'manual';
use constant OPT_TEST		=> 'test';
use constant OPT_VERSION        => 'Version';

use constant CONFIG_DEFAULT	=> '/etc/rpzla/rpzla.conf';
use constant OUR_IDENT		=> 'rpzla-bind';  # identity for syslog
use constant COMMIT_EVERY	=> 3;

my $version = '0.1';
my $ME = basename($PROGRAM_NAME);
my %options;
my $parse = GetOptions
(
        \%options,
        OPT_CONFIG() . '=s',
        OPT_DEBUG(),
        OPT_HELP() . '|?',  # allow -? or --? for help
        OPT_MANUAL(),
        OPT_TEST(),
        OPT_VERSION(),
);

# path requests to the warning site which we consider valid and
# do NOT log (should really be in the config)
my @valid_files = 
(
	'index.html',
	'censorship.html',
	'favicon.ico',
	'stylesheet.css',
	'background.html',
);
# The config
my %config = ();

# We need access to this for the signal handler cleanup (be nice)
my $dbh = undef;
my $sth = undef;

# shorthand for syslog calls
sub err($) { my $s = shift; syslog(LOG_ERR, "%s", $s); };
sub info($) { my $s = shift; syslog(LOG_INFO, "%s", $s); };
sub debug($) 
{ 
	my $s = shift; 
	if ( defined($options{OPT_DEBUG()}) )
	{
		print STDERR OUR_IDENT() . ": debug: $s\n";
	}
	else
	{
		syslog(LOG_INFO, "debug: %s", $s);
	}
}

sub parse_command_line()
{
        my $retval = 1;
        if ( !$parse )
        {
                pod2usage(2);
        }
        elsif ( $options{OPT_HELP()} )
        {
                pod2usage(0);
        }
        elsif ( $options{OPT_MANUAL()} )
        {
                pod2usage(-exitstatus => 0, -verbose => 2);
        }
        elsif ( $options{OPT_VERSION()} )
        {
                print "$ME v$version\n";
                exit(0);
        }
        if ( !defined($options{OPT_CONFIG()}) )
        {
                $options{OPT_CONFIG()} = CONFIG_DEFAULT();
        }
	if ( ! -f $options{OPT_CONFIG()} or ! -r $options{OPT_CONFIG()} )
	{
		croak("Config file argument '" . $options{OPT_CONFIG()} . 
			"' does not exist or cant be read.");
	}
        return $retval;
}

# given a line from the named log, reformat to:
# date, time, client ip address, query domain, rpz zone
#
# Exmaple input:
# 
# 15-Oct-2012 19:24:59.740 client ::1#52394 (nastynasty.com): rpz QNAME CNAME rewrite nastynasty.com via nastynasty.com.local.rpz
#
# Example output:
#
# 15-Oct-2012 19:24:59.740 ::1 nastynasty.com local.rpz
#
# ie.
#
# date time 'ipv6 loopback address' 'query domain' 'rpz zone name'
sub parse_log_entry($)
{
	my $line = shift;
	my $parsed = 0;
	# Format is:
	#
	# (date) (time) client (ip) \((query)\): rpz 'word' 'word' rewrite
	# (query) via (rpz-zone)
	#
	# where things in parens are matched for extration.
	#
	my $format = '([\w\-\:\.]+) ([\w\:\.]+) client ([\w\:\.\#]+) [(]([\w\.]+)[)]: rpz [\w]+ [\w]+ rewrite ([\w\.]+) via ([\w\.]+)';
	if ( $line !~ m/$format/ )
	{
		err("Unexpected format from BIND log " . $options{OPT_FILE()});
		err("Line was: $line");
		# abort
		return undef;
	}
	my ($date, $time, $ip_full, $query1, $query2, $zone_full) = 
		($1, $2, $3, $4, $5, $6);
	my $rpz_zone = undef;
	# Split out core details from entries combined with more data
	# Ignore fractional seconds
	my ($hms, $fractional_seconds) = split('[.]', $time);
	# Ignore client port number
	my ($ip, $port) = split('[#]', $ip_full);
	# Check queries match
	if ( $query1 ne $query2 )
	{
		err("Unexpected: name of query domain differs.  Bad parsing.");
		err("Query 1: '$query1' != Query 2: '$query2'");
	}
	# strip the query from the font of the rpz zone name
	elsif ( $zone_full !~ m/$query1[.]([\w\.]+)/ )
	{
		err("Unexpected: query domain not a part of the rpz zone name");
		err("Query domain: '$query1', Zone name (full): '$zone_full'");
	}
	else
	{
		$parsed = 1;
		$rpz_zone = $1;
	}
	# join and return
	return 
	( 
		$parsed 
	? 
		join(OUTPUT_SEP(), $date, $hms, $ip, $query1, $rpz_zone)
	:
		undef
	);
}

sub db_connect($)
{
	my $creds = shift;
	my $type = $creds->{'type'};
	my $host = $creds->{'host'};
	my $name = $creds->{'name'};
	my $user = $creds->{'user'};
	my $pass = $creds->{'pass'};
	my $target = 'dbi:' . $type . ':dbname=' . $name . ';host=' . $host;
	return DBI->connect($target, $user, $pass, {AutoCommit => 0})
}

sub prepare_insert($)
{
	my $dbh = shift;
	my $sth = $dbh->prepare
	(
		"INSERT INTO dns " .
		"(datetime, client_ip, query_domain, response_zone) " .
		"values " .
		"(?,?,?,?)"
	);
	return $sth;
}

sub db_insert($$)
{
	my ($sth, $s) = @_;
	my @values = split(' ', $s);
	my $date = shift(@values);
	my $time = shift(@values);
	# PostrgreSQL is beautiful: no date/time conversion required
	return $sth->execute($date . ' ' . $time, @values);
}

sub commit_now()
{
	if ( defined($sth) )
	{
		$sth->finish();
	}
	if ( defined($dbh) )
	{
		$dbh->commit();
		debug("Committed to DB");
	}
}

# Handle cleanup on signalling (i.e /etc/init.d/rc.d/rpzla-bind stop)
sub sig_handler($)
{
	my $sig = shift;
	commit_now();
	$dbh->disconnect() if ( defined($dbh) );
	info("Exiting upon receipt of signal '$sig'");
	closelog();
	exit(0);
}

$SIG{INT} = $SIG{TERM} = \&sig_handler;

# Load config, daemonise, do much work for debug mode, connect
# to log file and database (stop if in test mode), and start 
# shipping matched data.
sub main()
{
	my $retval = 1;
	# Load config
	my $conf = new Config::General($options{OPT_CONFIG()});
	%config = $conf->getall();
	# shorthand
	my $in_debug = defined($options{OPT_DEBUG()});
	# Off to daemon land
	my $daemon_opts = {};
	if ( $in_debug )
	{
		$daemon_opts->{'child_STDERR'} = '/tmp/rpzla-bind.err';
	}
	Proc::Daemon::Init($daemon_opts);
	# Establish syslog
	openlog(OUR_IDENT(), '', LOG_DAEMON);
	# Access Apache log
	my $bind_log = $config{'bind'}->{log};
	#
	# Cut down wait time on log checking for debug mode
	#
	my $interval = 10.0;  #default
	my $max_inter = 60.0; #default
	if ( $in_debug )
	{
		$interval = 1.0;
		$max_inter = 4.0;
	}
	my $tail = File::Tail->new
	(
		name		=> $bind_log,
		interval	=> $interval,
		maxinterval	=> $max_inter,
		debug		=> 1,
	);
	if ( not defined($tail) )
	{
		err("Could not access the log: $bind_log");
		exit(1);
	}
	# Connect to DB
	$dbh = db_connect($config{db});
	if ( !defined($dbh) )
	{
		err
		(
			"Failure connecting to database: check config: " . 
			$options{OPT_CONFIG()}
		);
		exit(1);
	}
	# If test mode, done.
	if ( defined($options{OPT_TEST()}) )
	{
		info("Test successful, exiting.");
		sig_handler('USR1');
	}
	#
	# Start shipping data
	#
	my $start_msg = "starting";
	if ( $options{OPT_DEBUG()} )
	{
		$start_msg .= ": with debug on";
	}
	info($start_msg);
	my $line = undef;
	my $uncommitted = 0;
	$sth = prepare_insert($dbh);
	#
	# Commit every time in debug mode
	#
	my $commit_interval = COMMIT_EVERY();
	if ( $in_debug )
	{
		$commit_interval = 1;
	}
	debug("First call to tail->read: tailing the log file ...");
	while ( defined($line = $tail->read()) )
	{
		chomp($line);
		debug("Found in log: $line");
		my $data = parse_log_entry($line);
		if ( defined($data) )
		{
			debug("Insert to DB: $data");
			db_insert($sth, $data);
			$uncommitted++;
		}
		else
		{
			debug("Ignored.");
		}
		if ( $commit_interval <= $uncommitted )
		{
			commit_now();
			$uncommitted = 0;
			$sth = prepare_insert($dbh);
		}
	}
	# UNREACHED (expect to run forever, until signal received)
	if ( $uncommitted )
	{
		commit_now();
	}
	$dbh->disconnect();
	return 1;
}

parse_command_line();

exit( main() ? 0 : 1 );

# UNREACHED

__END__

=head1 NAME

rpzla-bind.pl - transfer Apache log entries to the RPZLA database

=head1 SYNOPSIS

        rpzla-bind.pl <-h|-m|-V>
or
        rpzla-bind.pl [-d] [-t] [-c /path/to/config]

=head1 DESCRIPTION

rpzla-bind.pl watches the bind log as defined in the config
and extracts logs that indicate an RPZ response to a domain
lookup.

The format of the bind log file is important.  See the general
RPZLA documentation for more details.

rpzla-bind.pl is expected to be run as a daemon launched by init.

=head1 OPTIONS

=over

=item B<-c, --config>

The path to the config file.  Defaults to /etc/rpzla/rpzla.conf

=item B<-d, --debug>

Debug mode.  When deamonising send stderr to /tmp/rpzla-bind.err.
All info and regular error messages are still sent to syslog.

=item B<-h, -?, --help>

Prints a help message.

=item B<-m, --man, --manual>

Prints the B<manual page>.

=item B<-t, --test>

Test mode.  Will only check that the log file, and database, as
specified in the config can be read and connected to, respectively,
and then exit.

Can be combined with --debug.

=item B<-V, --Version>

Print the software version.

=back

=head1 SEE ALSO

rpzla.conf

https://github.com/yesxorno/rpzla.git

=head1 AUTHOR

Hugo M. Connery

=head1 LICENSE

GNU Public License version 2. (GPLv2)

=cut

