#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(:config default no_ignore_case);
use Pod::Usage;
use File::Basename;
use English;

# command-line options
use constant OPT_FILE	=> 'file';
use constant OPT_HELP   => 'help';
use constant OPT_MANUAL => 'manual';
use constant OPT_VERSION => 'Version';

# filtering now down internally (ignore FILTER)
# use constant FILTER	=> " grep --line-buffered '[ ]rewrite[ ]' ";
use constant OUTPUT_SEP	=> ' ';

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
	elsif 
	( 
		(! -f $options{OPT_FILE()} or ! -r $options{OPT_FILE()})
	and
		# useful for testing; use stdin
		'-' ne $options{OPT_FILE()}
	)
	{
		err("Log file argument '" . $options{OPT_FILE()} . 
			"' does not exist or cant be read.");
		exit(1);
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
sub reformat($)
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

# All we do is tail the log file and reformat it to provide the data
# that the 'to db' logger wants.
sub main()
{
	local $| = 1;
	my $retval = 1;
	my $file = $options{OPT_FILE()};
	# my $cmd = " tail -f $file | " . FILTER() . " | ";
	my $cmd = " tail -f $file | ";
	if ( ! open(STREAM, $cmd) )
	{
		err("Failure attempting to watch '$file'.  Aborting.");
	}
	else
	{
		# msg("Running '$cmd'");
		my $data = undef;
		while ( <STREAM> )
		{
			chomp($_);
			if ( m/ rewrite / )
			{
				$data = reformat($_);
				print "$data\n" if defined($data);
			}
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

rpzla-bind-filter.pl - parse a BIND query log extracting RPZ responses

=head1 SYNOPSIS

        rpzla-bind-filter.pl <-h|-m|-V>
or
        rpzla-bind-filter.pl <-f path-to-file>

=head1 DESCRIPTION

rpzla-bind-filter.pl watches (ie. tail(1)) a log containing
data for queries to a BIND server utilising Response
Policy Zone (RPZ) that have used the RPZ facility.

For each line that matches a response policy being used the following
data is printed to stdout:

  Date (28-Mar-2012)
  Time (17:34:59, not that we strip the fractional seconds)
  IP address of the client (IPv4 or IPv6, whatever the log records)
  Query (i.e www.verynasty.com)
  Name of rpz zone which responded (e.g rpz.local)

The output is all on one line and single whitspace separated, which
is expected by the rpzla-bind-to-db.pl script.

=head1 OPTIONS

=over

=item B<-f, --file path-to-file>

The file must be a bind log containing RPZ log data.

=item B<-h, -?, --help>

Prints a help message.

=item B<-m, --man, --manual>

Prints the manual page.

=item B<-V, --Version>

Print the software version.

=back

=head1 SEE ALSO

rpzla-bind-to-db.pl(1)

=head1 AUTHOR

Hugo M. Connery

=head1 LICENSE

GNU Public License version 2. (GPLv2)

=cut

