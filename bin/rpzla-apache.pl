#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(:config default no_ignore_case);
use Pod::Usage;
use File::Basename;
use English;
use Config::General;
use Daemon::Daemonize;
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
use constant COMMIT_EVERY	=> 3;
use constant OUR_IDENT		=> 'rpzla-apache';  # identity for syslog

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

# We need access to this for the signal handler cleanup (be nice)
my $dbh = undef;
my $sth = undef;

sub err($) { my $s = shift; syslog(LOG_ERR, "%s", $s); };
sub msg($) { my $s = shift; syslog(LOG_INFO, "%s", $s); };
sub debug($) 
{ 
	my $s = shift; 
	if ( defined($options{OPT_DEBUG()}) )
	{
		syslog(LOG_DEBUG, "%s", $s); 
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

sub parse_log_entry($)
{
	my $s = shift;
	my $retval = undef;
	if ( $s =~ m/([\w-]+) ([\w:]+) ([\d.:]+) ([\w.:-]+) ([\w.-]+) ([\d]+) "GET ([\w\/.?&]+) HTTP\/[^"]*"/ )
	{
		my ($date, $time, $ip, $lookup, $site, $http_response, $path ) =
			($1, $2, $3, $4, $5, $6, $7);
		my $valid_request = 0;
		for my $valid ( @valid_files )
		{
			if ( $path eq "/$valid" )
			{
				$valid_request = 1;
				last;
			}
		}
		if ( not $valid_request )
		{
			# log it
			$retval = join(' ', $date, $time, $ip, $lookup, $site);
		}
	}
	return $retval;
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
		"INSERT INTO web " .
		"(datetime, client_ip, client_hostname, query_domain) " .
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
	}
}

# Handle cleanup on signalling (i.e /etc/init.d/rc.d/rpzla-apache stop)
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

sub main()
{
	my $retval = 1;
	# Load config
	my $conf = new Config::General($options{OPT_CONFIG()});
	my %config = $conf->getall();
	# Establish syslog
	openlog(OUR_IDENT(), '', LOG_DAEMON);
	# Access Apache log
	my $apache_log = $config{'walled-garden'}->{log};
	my $tail = File::Tail->new($apache_log);
	if ( not defined($tail) )
	{
		err("Could not access the log: $apache_log");
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
	# If testing, done.
	if ( defined($options{OPT_TEST()}) )
	{
		info("Test successful, exiting.");
		sig_handler('USR1');
	}
	# Log --> DB
	my $line = undef;
	my $uncommitted = 0;
	$sth = prepare_insert($dbh);
	Daemon::Daemonize->daemonize();
	while ( defined($line = $tail->read()) )
	{
		chomp($line);
		my $data = parse_log_entry($line);
		db_insert($sth, $_);
		$uncommitted++;
		if ( COMMIT_EVERY() <= $uncommitted )
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

rpzla-apache.pl - transfer Apache log entries to the RPZLA database

=head1 SYNOPSIS

        rpzla-apache.pl <-h|-m|-V>
or
        rpzla-apache.pl [-d] [-c /path/to/config]

=head1 DESCRIPTION

rpzla-apache.pl watches the apache log as defined in the config
and extracts logs that indicate someone visiting the site because
of RPZ domain name redirection.  These logs are then transferred
to the RPZLA database, also as defined in the config.

The format of the apache log file is important.  See the general
RPZLA documentation for more details.

The tool *requires* that you use the following log format in your
site definition:

	LogFormat "%{%d-%b-%Y %T}t %a %h %V %>s \"%r\"" rpz_log

	CustomLog logs/some-path rpz_log

It is useful (though costs a penalty) if you have:

	HostnameLookups On

All error and informational messages are sent to the system log.

rpzla-apache.pl is expected to be run as a daemon launched by init.

=head1 OPTIONS

=over

=item B<-c, --config>

The path to the config file.  Defaults to /etc/rpzla/rpzla.conf

=item B<-d, --debug>

Include debug log information.

=item B<-h, -?, --help>

Prints a help message.

=item B<-m, --man, --manual>

Prints the manual page.

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

