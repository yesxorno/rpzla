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
use constant FILTER		=> " grep '304 \"GET / HTTP' ";
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

sub reformat($)
{
	my @values = split(' ', shift);
	while ( 5 < scalar(@values) )
	{
		pop(@values);
	}
	return join(' ', @values);
}


sub main()
{
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

apache-access-log-filter.pl - parse an apache access log looking for GET /

=head1 SYNOPSIS

        apache-access-log-filter.pl <-h|-m|-V>
or
        apache-access-log-filter.pl <-f path-to-file>

=head1 DESCRIPTION

apache-access-log-filter.pl watches (ie. tail(1)) an apache access
log.  It looks for successful 'GET / ' requests and reformats the data for 
later upload to a database.  This is a compliment tool to 
bind-query-log-filter-rpz.pl

For each line that matches a 'GET /' the following
data is printed to stdout:

  Date (28-Feb-2012)
  Time (17:12:58)
  IP address of querier (IPv4 type or IPv6, depending on what the log has)
  Hostname of querier (result of the reverse lookup)
  Name of site which was queried (e.g www.verynasty.com)

The output is all on one line and single whitespace separated.

The tool *requires* that you use the following log format in your
site definition:

	LogFormat "%{%d-%b-%Y %T}t %a %h %V %>s \"%r\"" rpz_log

	CustomLog logs/some-path rpz_log

And that you have:

	HostnameLookups On

This tool is (currently) entirely equivalent to:

	tail -f < /path/to/log | grep ' 304 "GET / HTTP' | cut -d ' ' -f 1-5

with the exeption that is more helpful (usage, man page etc.).

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

rpz-log-apache-to-db.pl(1), rpz-log-bind-filter.pl(1), 
rpz-log-bind-to-db.pl(1)

=head1 AUTHOR

Hugo M. Connery

=head1 LICENSE

GNU Public License version 2. (GPLv2)

=cut

