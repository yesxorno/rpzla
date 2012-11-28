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
use RPZLA::Scraper::MAC_Cache;

use constant DEFAULT_COMMIT_INTERVAL	=>	3;
use constant MAC_UNKNOWN		=>	'NULL'; # registers a NULL in DB

#####################################################################
#
# Purpose:
#
#	Base class for RPZLA log scrapers
#
# Provides:
#
#  * Config file loading
#  * syslog initialisation
#  * DB connection, statement handlers, insertion, and commiting
#  * Log file tailing
#  * Signal handlers for 'stop' and reload config
#  * Main processing loop
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
# 4. Their 'overridden' init must call this base classes init (after the above)
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
		#
		# These to be set by the caller (of a derived class)
		#
                'ident'         => '$',  # name to identify with syslog
		'config_path'	=> '$',  # any non-default config location
		'debug_mode'	=> '$',  # debug mode (undef for NO DEBUG)
		#
		#####################################################
		#
		# Things that must be set by derived classes in their init()
		# before calling ours.
		#
		# Prepare insert SQL
		#
		'_prep_insert_sql' => '$',
		#
		# Path the log file
		#
		'_log_path'	=> '$',
		#
		# Tools for use by derived classes
		#
		# MAC cache (call $self->_mac->get($ip_addr)) to get a MAC
		# It may return undef, see the module.
		#
		'_mac'		=> '$',
		#
		#####################################################
		#
		# Internals (dont touch)
		#  
		# The loaded config hash
		'_config'	=> '$',
		# the File::Tail object for watching the log
		'_log'		=> '$',  
		# options which we provide to File::Tail (varies with debug)
		'_log_opts'	=> '$',
		# Database and statement handles
		'_dbh'		=> '$',
		'_sth'		=> '$',
	}
);

#####################################################################
#
# Public Methods
#

# init MUST BE CALLED before any other public method.

sub init()
{
	my $self = shift;
	#
	# Sanity checks
	#
	my $sane = 1;
	if ( not defined($self->ident) )
	{
		$self->err("Must supply ident for use in syslog");
		$sane = 0;
	}
	if ( not defined($self->_config) )
	{
		$self->err("Config not loaded.");
		$sane = 0;
	}
	if ( not defined($self->config_path()) )
	{
		$self->err("config_path must be defined.");
                $sane = 0;
	}
	if ( not defined($self->_log_path) )
	{
		$self->err("log path not defined.");
		$sane = 0;
	}
	elsif ( ! (-f $self->_log_path and -r $self->_log_path) )
	{
		$self->err("log path not readable regular file.");
		$sane = 0;
	}
	my $db = $self->_config->{'db'};
	if 
	(
		not defined($db->{'type'})
	or
		not defined($db->{'host'})
	or
		not defined($db->{'name'})
	or
		not defined($db->{'user'})
	or
		not defined($db->{'pass'})
	)
	{
		$self->err
		(
			"Must have all DB config (except port): " .
			"type, host, name, user and pass.  Something missing."
		);
		$sane = 0;
	}
	if ( not $sane )
	{
		$self->exit_now(1);
	}
	# undef means no debug, else debug
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
	# Decide how frequently to check and recheck the log file
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
	# Create the MAC Cache
	my $cache = new RPZLA::Scraper::MAC_Cache;
	$cache->init();
	$self->_mac($cache);
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
		# this may look strangs, but some syslog are by default
		# configured to *ignore* debug messages, so we use LOG_INFO
		syslog(LOG_INFO, ": debug: $s\n");
	}
}

##############################################################
#
# Signal handling methods.  Call from the 'program'.
#
# Use as follows:
#
# Say you have a derived class of this base called '$scraper' which
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
	#
	# I dont know why, be after reconnecting to the log, we get a double
	# load of the first line of the next submitted log entry ????
	#
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

# Call the MAC cache to get the link local address for the supplied IPv[46]
# address.  If it can't be found 'unknown' (string) is returned.
sub get_mac($)
{
	my ($self, $ip) = @_;
	my $retval = $self->_mac->get($ip);
	if ( not defined($retval) )
	{
		$retval = MAC_UNKNOWN();
		$self->err("Unable to get MAC for IP: $ip");
	}
	return $retval;
}

#
# This you call after init(), and we start doing our job.
#
sub main_loop()
{
	my $self = shift;
	my $start_msg = "starting";
	#
	# Connect to DB and log
	#
	$self->_connect_all();
	#
	# Say hello to syslog
	#
	if ( $self->debug_mode )
	{
		$start_msg .= ": with debug on";
	}
	$self->info($start_msg);
	my $line = undef;
	my $uncommitted = 0;
	my $commit_interval = $self->_config->{db}->{commit_interval};
	if ( not defined($commit_interval) )
	{
		$commit_interval  = DEFAULT_COMMIT_INTERVAL();
	}
	if ( $self->debug_mode )
	{
		$commit_interval = 1;
	}
	$self->debug("First call to log->read: tailing the log file ...");
	#
	# Start moving data
	#
	while ( defined($line = $self->_log->read()) )
	{
		chomp($line);
		$self->debug("Found in log: $line");
		# the log parser may wish to ignore the log entry it
		# is given.  Its returns undef and we honour that.
		my $data = $self->_parse_log_entry($line);
		if ( defined($data) )
		{
			$self->debug("Insert to DB: '$data'");
			$self->_db_insert($data);
			$uncommitted++;
		}
		else
		{
			$self->debug("Ignored.");
		}
		if ( $commit_interval <= $uncommitted )
		{
			$self->_commit_now();
			$uncommitted = 0;
			$self->_prepare_insert();
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

##################################
#
# To be called by derived classes in THEIR init() method before calling ours.
#

# Establish syslog 
sub _open_syslog()
{
	my $self = shift;
	openlog($self->ident, '', LOG_DAEMON);
}

# Load the config
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

######################################################
#
# This class's internal methods (should not be needed by derived classes)
#

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

#############################
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
		$self->err($DBI::errstr);
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
	my $retval = $self->_sth->execute($date . ' ' . $time, @values);
	if ( not defined($retval) )
	{
		$self->err("Error inserting row to DB.");
		$self->err($DBI::errstr);
		$self->info("Aborting");
		$self->exit_now(1);
	}
	return  $retval;
}

sub _commit_now()
{
	my $self = shift;
	if ( defined($self->_dbh) )
	{
		$self->_dbh->commit();
		$self->debug("Committed to DB");
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
	# Only use port if specified
	my $port = '';
	if ( defined($creds->{'port'}) and 0 < length($creds->{'port'}) )
	{
		$port = ";port=" . $creds->{'port'};
	}
	my $target = "dbi:$type:dbname=$name;host=$host" . $port;
	my $dbi_attr = {AutoCommit=>0, PrintError=>0};
	$self->_dbh(DBI->connect($target, $user, $pass, $dbi_attr));
	if ( not defined($self->_dbh) )
	{
		$self->err
		(
			"Failure connecting to database: check config: " . 
			$self->config_path
		);
		$self->err($DBI::errstr);
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

#############################
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


#############################
#
# Main routine to be overridden by derived classes.
#
# Skeleton:
#
sub _parse_log_entry($)
{
	my ($self, $line) = @_;
	#
	# Look at $line.
	#
	# check that it makes sense and that you wish to insert to DB.
	#
	# if so, cut out what you need to match the insert statement
	# return as a whitespace delimited string of fields
	#
	# if you dont want it inserted into the DB, return undef
	#
	# if you want to abort, do:
	#
	# $self->err("Something horrible happened");
	# $self->exit_now(1)
	#
	# In pseudo code:
	#
	my $retval = undef;
	if ( $self->_all_is_good($line) )
	{
		my @fields = $self->parse_out_fields($line);
		$retval = join(' ', @fields);
	}
	else
	{
		if ( $self->_is_disaster($line) )
		{
			$self->err("disaster ...");
			$self->exit_now(1);
		}
		else
		{
			# ignore line
			$retval = undef;
		}
	}
	return $retval;
}

1;
