#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(:config default no_ignore_case);
use Pod::Usage;
use File::Basename;
use English;

# command-line options
use constant OPT_FILE		=> 'file';
use constant OPT_HELP           => 'help';
use constant OPT_MANUAL         => 'manual';
use constant OPT_VERSION        => 'Version';

# cut out the fields we need from the BIND query log (input filter)
use constant FILTER		=> " grep ':rpz QNAME CNAME rewrite ' ";
use constant OUTPUT_SEP		=> ' ';

my $version = '0.1';
my $ME = basename($PROGRAM_NAME);
my %options;
my $parse = GetOptions
(
        \%options,
        OPT_FILE() . '=s',
        OPT_HELP() . '|?',  # allow -? or --? for help
        OPT_MANUAL(),
        OPT_VERSION(),
);

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
        elsif ( !defined($options{OPT_FILE()}) )
        {
                pod2usage(2);
        }
	elsif ( ! -f $options{OPT_FILE()} or ! -r $options{OPT_FILE()} )
	{
		err("Log file argument '" . $options{OPT_FILE()} . 
			"' does not exist or cant be read.");
		exit(1);
	}
        return $retval;
}

# given a line from the named log, reformat to:
# date, time, client ip, query domain, rpz zone
sub reformat($)
{
	my @w = split(' ', shift);
	# unclear; needs improvement: too much 'magic'
	my ($date, $time, $ip_port, $response, $query_zone) = 
		($w[0], $w[1], $w[5], $w[10], $w[12]);
	my ($hms, $fractional_seconds) = split('[.]', $time);
	my ($ip, $rest) = split('[#]', $ip_port);
	# Wrong way to do this: strip the query domain, rather than 
	# relying on the fact that the rpz zone name starts with rpz (idiot)
	my @domains = split('[.]', $query_zone);
	my @rpz_zone = ( );
	my $current = '';
	# FIX ME: dont rely on rpz as the first part of the rpz zone name
	while ( 'rpz' ne $current and scalar(@domains) )
	{
		$current = pop(@domains);
		unshift(@rpz_zone, $current);
	}
	# what is left is the query
	my @query = @domains;
	return join
	(
		OUTPUT_SEP(), $date, $hms, $ip, 
		join('.', @query), 
		join('.', @rpz_zone)
	);
}

# All we do is tail the log file and reformat it to provide the data
# that the 'to db' logger wants.
sub main()
{
	local $| = 0;
	my $retval = 1;
	my $file = $options{OPT_FILE()};
	my $cmd = " tail -f $file | " . FILTER() . " | ";
	if ( ! open(STREAM, $cmd) )
	{
		err("Failure attempting to watch '$file'.  Aborting.");
	}
	else
	{
		# msg("Running '$cmd'");
		while ( <STREAM> )
		{
			chomp($_);
			print reformat($_) . "\n";
		}
		msg("Ending");
	}
	return $retval;
}

parse_command_line();

exit( main() ? 0 : 1 );

# UNREACHED

__END__

=head1 NAME

bind-query-log-filter-rpz.pl - parse a BIND query log extracting RPZ responses

=head1 SYNOPSIS

        bind-query-log-filter-rpz.pl <-h|-m|-V>
or
        bind-query-log-filter-rpz.pl <-f path-to-file>

=head1 DESCRIPTION

bind-query-log-filter-rpz.pl watches (ie. tail(1)) a log containing
severity info data for queries to a BIND server utilising Response
Policy Zones.

It is required that all RPZ zones start with 'rpz.'.  This is used
in parsing.

For each line that matches a response policy being used the following
data is printed to stdout:

  Date (28-Mar-2012)
  Time (17:34:59, not that we strip the fractional seconds)
  IP address of querier (IPv4 or IPv6, whatever the log records)
  Query (i.e www.verynasty.com)
  Name of rpz zone which responded (e.g rpz.local)

Could give 

  Response (Whatever the DNS gave.  E.g an IP or a CNAME)

Should we ??  Makes no sense for a constant walled garden.
Perhaps useful otherwise.

The output is all on one line and single whitspace separated.

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

rpz-log-apache-filter.pl(1), rpz-log-apache-to-db.pl(1), 
rpz-log-bind-to-db.pl(1)

=head1 AUTHOR

Hugo M. Connery

=head1 LICENSE

GNU Public License version 2. (GPLv2)

=cut

