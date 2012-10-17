#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(:config default no_ignore_case);
use Pod::Usage;
use File::Basename;
use English;
use DBI;
use Config::General;

# command-line options
use constant OPT_CONFIG		=> 'config';
use constant OPT_HELP           => 'help';
use constant OPT_MANUAL         => 'manual';
use constant OPT_VERSION        => 'Version';

# We do commits for every X inserts
use constant COMMIT_EVERY	=> 3;

my $version = '0.1';
my $ME = basename($PROGRAM_NAME);
my %options;
my $parse = GetOptions
(
        \%options,
        OPT_CONFIG() . '=s',
        OPT_HELP() . '|?',  # allow -? or --? for help
        OPT_MANUAL(),
        OPT_VERSION(),
);
# We need access to this for the signal handler cleanup (be nice)
my $dbh = undef;
my $sth = undef;

sub err($) { my $s = shift; print STDERR "$ME: Error: $s\n"; }
sub msg($) { my $s = shift; print STDERR "$ME: Info: $s\n"; }

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
        elsif ( !defined($options{OPT_CONFIG()}) )
        {
                pod2usage(2);
        }
	elsif ( ! -f $options{OPT_CONFIG()} or ! -r $options{OPT_CONFIG()} )
	{
		err("Log file argument '" . $options{OPT_CONFIG()} . 
			"' does not exist or cant be read.");
		exit(1);
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
	my $dbh = DBI->connect($target, $user, $pass, {AutoCommit => 0}) or
		die("Failure connecting to database: check your config");
	return $dbh;
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

sub sig_handler($)
{
	my $sig = shift;
	# Not much checking here; just close the door
	$sth->finish();
	$dbh->commit();
	$dbh->disconnect();
	exit(0);
}

$SIG{INT} = $SIG{TERM} = \&sig_handler;

sub main()
{
	my $retval = 1;
	my $conf = new Config::General($options{OPT_CONFIG()});
	my %config = $conf->getall();
	$dbh = db_connect($config{db});
	$sth = prepare_insert($dbh);
	my $uncommitted = 0;
	while ( <STDIN> )
	{
		chomp($_);
		db_insert($sth, $_);
		$uncommitted++;
		if ( COMMIT_EVERY() <= $uncommitted )
		{
			$sth->finish();
			$dbh->commit();
			$uncommitted = 0;
			$sth = prepare_insert($dbh);
		}
	}
	if ( $uncommitted )
	{
		$sth->finish();
		$dbh->commit();
	}
	$dbh->disconnect();
	return $retval;
}

parse_command_line();

exit( main() ? 0 : 1 );

# UNREACHED

__END__

=head1 NAME

rpz-log-apache-to-db.pl - read the output from rpz-log-apache-filter.pl and insert the data into a database

=head1 SYNOPSIS

        rpz-log-apache-to-db.pl <-h|-m|-V>
or
        rpz-log-apache-to-db.pl <-c path-to-config-file>

=head1 DESCRIPTION

rpz-log-apache-to-db.pl reads the output from the rpz-log-apache-filter.pl
log filter and then inserts the gathered data into a database, committing
every so often.

This tool aborts as soon as any error is encountered.

=head1 OPTIONS

=over

=item B<-f, --file path-to-file>

The file must be a bind log of query information of severity info.

=item B<-h, -?, --help>

Prints a help message.

=item B<-m, --man, --manual>

Prints the manual page.

=item B<-V, --Version>

Print the software version.

=back

=head1 SEE ALSO

rpz-log-apache-filter.pl(1), rpz-log-bind-filter.pl(1), 
rpz-log-bind-to-db.pl(1)

=head1 AUTHOR

Hugo M. Connery

=head1 LICENSE

GNU Public License version 2. (GPLv2)

=cut

