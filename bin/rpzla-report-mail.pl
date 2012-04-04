#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(:config default no_ignore_case);
use Pod::Usage;
use File::Basename;
use English;
use Config::General;

# command-line options
use constant OPT_CONFIG		=> 'config';
# choose the period
use constant OPT_PERIOD		=> 'period';
# choose the data
use constant OPT_REPORT		=> 'report';
# summary or all data
use constant OPT_SUMMARIZE	=> 'summarize';
# General options
use constant OPT_HELP           => 'help';
use constant OPT_MANUAL         => 'manual';
use constant OPT_VERSION        => 'Version';

use constant CONFIG_DEFAULT	=> '/etc/rpzla/rpzla.conf';

my $version = '0.1';
my $ME = basename($PROGRAM_NAME);
my %options;
my $parse = GetOptions
(
        \%options,
        OPT_CONFIG() . '=s',
        OPT_PERIOD() . '=s',
        OPT_REPORT() . '=s',
        OPT_SUMMARIZE(),
        OPT_HELP() . '|?',  # allow -? or --? for help
        OPT_MANUAL(),
        OPT_VERSION(),
);

sub err($) { my $s = shift; print STDERR "$ME: Error: $s\n"; }
sub msg($) { my $s = shift; print STDERR "$ME: Info: $s\n"; }

sub check_period($)
{
	my $p = lc(shift);
	if ( 'day' ne $p and 'week' ne $p and 'month' ne $p )
	{
		err("'$p' is not a valid period (day, week, month)");
		exit(1);
	}
}

sub check_report($)
{
	my $r = lc(shift);
	if ( 'dns' ne $r and 'web' ne $r and 'cor_web' ne $r and 'cor_dns' ne $r )
	{
		err("'$r' is not a valid report (dns, web, cor_dns, cor_web)");
		exit(1);
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
		err("Config file argument '" . $options{OPT_CONFIG()} . 
			"' does not exist or cant be read.");
		exit(1);
	}
        if ( !defined($options{OPT_REPORT()}) )
        {
                $options{OPT_REPORT()} = 'cor_web';
        }
	check_report($options{OPT_REPORT()});
        if ( !defined($options{OPT_PERIOD()}) )
        {
                $options{OPT_PERIOD()} = 'week';
        }
	check_period($options{OPT_PERIOD()});
        if ( !defined($options{OPT_SUMMARIZE()}) )
        {
                $options{OPT_SUMMARIZE()} = 0;
        }
	# And finally we need to email addresses ...
	if ( 0 == scalar(@ARGV) )
	{
		err("Please supply some email address for report delivery.");
		exit(1);
	}
        return $retval;
}

# return the command for the pipeline
sub make_report_cmd()
{
	my $conf = $options{OPT_CONFIG()};
	my $cmd = "rpzla-report-text.pl";
	return join
	(
		' ',
		$cmd,
		'-c', $options{OPT_CONFIG()},
		'-r', $options{OPT_REPORT()},
		'-p', $options{OPT_PERIOD()},
		( $options{OPT_SUMMARIZE()} ? '-s' : '' )
	)
}

sub main()
{
	my $retval = 1;
	my $cmd = make_report_cmd();
	system("$cmd | mail -s 'Report from RPZLA' @ARGV");
	return ( 0 == $! );
}

parse_command_line();

exit( main() ? 0 : 1 );

# UNREACHED

__END__

=head1 NAME

rpzla-report-mail.pl - Produce an RPZLA report and mail it

=head1 SYNOPSIS

  rpzla-report-mail.pl <-h|-m|-V>
or
  rpzla-report-mail.pl [-c /path/to/conf] [-p period] [-r report] [-s] addr ...

=head1 DESCRIPTION

rpzla-report-mail.pl queries the RPZLA analysis web site and emails a
report to the addresses provided as arguments.  The options
configure what type of report is produced (i.e how the web site
is contacted).

=head1 OPTIONS

=over

=item B<-c, --config>

The path to the config file.  Defaults to /etc/rpzla/rpzla.conf

=item B<-r, --report>

Which report: dns, web, cor_dns (DNS-Web), cor_web (DNS+Web)

=item B<-p, --period>

How far back in the past to use as data (day, week or month).

=item B<-s, --summarize>

Whether to 'group by' and included totals, or include all raw
data.

=item B<-h, -?, --help>

Prints a help message.

=item B<-m, --man, --manual>

Prints the manual page.

=item B<-V, --Version>

Print the software version.

=back

=head1 SEE ALSO

rpzla.conf

=head1 AUTHOR

Hugo M. Connery

=head1 LICENSE

GNU Public License version 2. (GPLv2)

=cut

