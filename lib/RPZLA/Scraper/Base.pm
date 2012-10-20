#!/usr/bin/perl
package RPZLA::Scraper::Base;

use strict;
use warnings;

use Config::General;
use Proc::Daemon;
use DBI;
use File::Tail;
use Sys::Syslog qw/:standard :macros/;
use Class::Struct;

#####################################################################
#
# Purpose:
#
#	Base class for RPZLA log scrapers
#
# Provides:
#
#   Config file loading
#
#   DB connection, statement handlers, and insertion
#
#   Log file tailing
#
#   Signal handlers for 'stop' and reload config
#
#   Main processing loop
#
#####################################################################
#
# SUPER CLASSES (Derived, call it what you will) must:
#
# 1. Open the syslog and config, load it and set it (call the method here)
#    e.g ->_open_syslog() and ->_load_config()
#
# 2. Set the name of the log file to watch (_log_path)
#
# 3. Set the SQL statement for preparing the insert (_prep_insert_sql)
#
# 4. Their 'overridden' init must call this base classes init.
#
# 5. Override the 'parse_log_entry' method with that which is appropriate
#    for their log file.  Note that the number of whitespace separated
#    fields in the string returned from this methos must match the
#    _prep_insert_sql.  See _db_insert()
#
# The 'main_loop' may then be called by the application.
#

my $packagename = __PACKAGE__;
struct
(
	$packagename => 
	{
                'ident'         => '$',  # name to identify with syslog
		'config_path'	=> '$',  # any non-default config location
		'debug_mode'	=> '$',  # debug mode (undef for NO DEBUG)
		'test_mode'	=> '$',  # test mode (undef for NO TEST)
		#
		# Internals (dont touch)
		#
		'_config'	=> '$',  # loaded config
		# the File::Tail object for watching the log
		'_log'		=> '$',  
		'_log_opts'	=> '$',
		'_dbh'		=> '$',  # DB connection handle
		'_sth'		=> '$',  # prepared statement handle
		#
		# Things that must be set by derived classes:
		#
		'_ident'		=> '$',  # name for syslog
		# Prepare insert SQL
		#
		'_prep_insert_sql' => '$',
		#
		# Path the log file
		#
		'_log_path'	=> '$',
	}
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


#####################################################################
#
# Public Methods
#

# init MUST BE CALLED before any other public method.

sub init()
{
	my $self = shift;
	my $sane = 1;
	if ( not defined($self->ident()) )
	{
		$self->err("Must supply ident for use in syslog");
		$sane = 0;
	}
	if ( not defined($self->_config()) )
	{
		$self->err("Config not loaded.");
		$sane = 0;
	}
	if ( not $sane )
	{
		$self->exit_now(1);
	}
	if ( not defined($self->debug_mode()) )
	{
		$self->debug_mode(0);
	}
	else
	{
		$self->debug_mode(1);
	}
	my $log_opts = { };
	$log_opts->{name} 	= $self->_log_path;
	#
	# Decide who frequently to check and recheck the log file
	#
	if ( $self->debug_mode() )
	{
		$log_opts->{interval}		= 1.0,
		$log_opts->{maxinterval}	= 3.0,
	}
	else
	{
		$log_opts->{interval}		= 10.0,
		$log_opts->{maxinterval}	= 60.0,
	}
	$self->_log_opts($log_opts);
	if ( not defined($self->config_path()) )
	{
		$self->err("config_path must be defined.");
                $self->exit_now(1);
	}
	$self->_connect_all();
	# If test mode, done.
	if ( $self->test_mode )
	{
		$self->info("Test successful, exiting.");
		$self->exit_now(0);
	}
	return 1;
}

# shorthand for syslog calls
sub err($) { my ($self, $s) = @_; syslog(LOG_ERR, "%s", $s); };
sub info($) { my ($self, $s) = @_; syslog(LOG_INFO, "%s", $s); };
sub debug($) 
{ 
	my ($self, $s) = @_;
	if ( $self->debug_mode )
	{
		print STDERR $self->ident . ": debug: $s\n";
	}
}

##############################################################
#
# Signal handling methods.  Call from the 'program'.
#
# Use as follows:
#
# Say you have a super-class of this base called 'scraper' which
# is a global (or is in scope) and have defined:
#
# sub sig_stop($) { my $sig = shift; $scraper->sig_stop($sig); }
# sub sig_reload($) { my $sig = shift; $scraper->sig_reload($sig); }
#
# Then to capture signals, just:
#
# $SIG{INT} = $SIG{TERM} = \&sig_stop;
# $SIG{HUP} = \&sig_reload;

# Handle cleanup on signalling (i.e /etc/init.d/rc.d/rpzla-apache stop)
sub sig_stop($)
{
	my ($self, $sig) = @_;
	$self->info("Exiting upon receipt of signal '$sig'");
	$self->exit_now(0);
}

# Handle config reload
sub sig_reload($)
{
	my ($self, $sig) = @_;
	$self->info("Reload config request from signal '$sig'");
	$self->_disconnect_all();
	$self->info("disconnected all; reloading config and reconnecting");
	$self->_load_config();
	$self->_connect_all();
	$self->info("Reconnected to log and database.  Resuming");
	return 1;
}

# Not a signal handler ...
# This just shuts down all (disconnect, close, etc ...)
sub exit_now($)
{
	my ($self, $status) = @_;
	$self->_disconnect_all();
	closelog();
	$self->info("Exiting: status == $status");
	exit($status);
}

sub main_loop()
{
	my $self = shift;
	# Off to daemon land
	my $daemon_opts = {};
	if ( $self->debug_mode )
	{
		$daemon_opts->{'child_STDERR'} = '/tmp/' .$self->ident. '.err';
	}
	Proc::Daemon::Init($daemon_opts);
	#
	# Start shipping data
	#
	my $start_msg = "starting";
	if ( $self->debug_mode )
	{
		$start_msg .= ": with debug on";
	}
	$self->info($start_msg);
	my $line = undef;
	my $uncommitted = 0;
	my $commit_interval = $self->_config->{db}->{commit_interval};
	if ( $self->debug_mode )
	{
		$commit_interval = 1;
	}
	$self->debug_mode("First call to log->read: tailing the log file ...");
	while ( defined($line = $self->_log->read()) )
	{
		chomp($line);
		$self->debug_mode("Found in log: $line");
		# the log parser may wish to ignore the log entry it
		# is given.  Its returns undef and we honour that.
		my $data = $self->_parse_log_entry($line);
		if ( defined($data) )
		{
			$self->debug_mode("Insert to DB: $data");
			$self->_db_insert($self->_sth, $data);
			$uncommitted++;
		}
		else
		{
			$self->debug_mode("Ignored.");
		}
		if ( $commit_interval <= $uncommitted )
		{
			$self->_commit_now();
			$uncommitted = 0;
			$self->_sth = $self->_prepare_insert();
		}
	}
	# UNREACHED (expect to run forever, until signal received)
	$self->info("Unexpected exit of main loop (log file moved?). Exiting.");
	$self->exit_now(0);
	# Definitely UNREACHED
	return 1;
}

#####################################################################
#
# Internal (Private) Methods
#

# Establish syslog
sub _open_syslog()
{
	my $self = shift;
	openlog($self->ident, '', LOG_DAEMON);
}

# Load the config: expected to be used by super-classes BEFORE this our init()
sub _load_config()
{
	my $self = shift;
	my $conf = new Config::General($self->config_path);
	my %config = $conf->getall();
	if ( 0 == scalar(keys(%config)) )
	{
		$self->err("Failure loading config");
		$self->exit_now(1);
	}
	else
	{
		$self->_config(\%config);
	}
}

#
# General 'dis/connect to db and log' routine
#
sub _connect_all()
{
	my $self = shift;
	$self->_db_connect();
	$self->_log_connect();
}

sub _disconnect_all()
{
	my $self = shift;
	$self->_db_disconnect();
	$self->_log_disconnect();
}

#
# Database handling routines
#
sub _prepare_insert()
{
	my $self = shift;
	$self->_sth($self->_dbh->prepare($self->_prep_insert_sql));
	if ( not defined($self->_sth) )
	{
		$self->err
		(
			"Failure preparing insert statement handle."
		);
		$self->exit_now(1);
	}
}

sub _db_insert($)
{
	my ($self, $s) = @_;
	my @values = split(' ', $s);
	my $date = shift(@values);
	my $time = shift(@values);
	# PostrgreSQL is beautiful: no date/time conversion required
	return $self->_sth->execute($date . ' ' . $time, @values);
}

sub _commit_now()
{
	my $self = shift;
	if ( defined($self->_sth) )
	{
		$self->_sth->finish();
	}
	if ( defined($self->_dbh) )
	{
		$self->_dbh->commit();
		$self->debug_mode("Committed to DB");
	}
}

sub _db_connect()
{
	my $self = shift;
	my $creds = $self->_config->{db};
	my $type = $creds->{'type'};
	my $host = $creds->{'host'};
	my $name = $creds->{'name'};
	my $user = $creds->{'user'};
	my $pass = $creds->{'pass'};
	my $target = 'dbi:' . $type . ':dbname=' . $name . ';host=' . $host;
	$self->_dbh(DBI->connect($target, $user, $pass, {AutoCommit => 0}));
	if ( not defined($self->_dbh) )
	{
		$self->err
		(
			"Failure connecting to database: check config: " . 
			$self->config_path
		);
		$self->exit_now(1);
	}
	$self->_prepare_insert();
	return 1;
}

sub _db_disconnect()
{
	my $self = shift;
	$self->_commit_now();
	$self->_dbh->disconnect() if ( defined($self->_dbh) );
	$self->_dbh(undef);
}

#
# Log handling routines
#
sub _log_connect()
{
	my $self = shift;
	$self->_log(File::Tail->new(%{$self->_log_opts}));
	if ( not defined($self->_log) )
	{
		$self->err
		(
			"Could not access the log: " . 
			$self->_log_opts->{name}
		);
		$self->exit_now(1);
	}
}

sub _log_disconnect()
{
	my $self = shift;
	# hope that this closes the existing log handle, free's memory etc.
	my $log = $self->_log();
	$self->_log(undef);
	undef($log);
}

1;
