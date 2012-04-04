#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long qw(:config default no_ignore_case);
use Pod::Usage;
use File::Basename;
use English;
use Config::General;
use Net::HTTP;

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

# Report config with defaults (overriden by cmd line)
my %report =
(
	'report'	=> 'corweb',
	'period'	=> 'week',
	'summarize'	=> 1,
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
	if ( defined($r) ) { $r = lc($r); }
	if ('dns' ne $r and 'web' ne $r and 'cor_web' ne $r and 'cor_dns' ne $r)
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
		# Defaults to 'Off' which is not what we really want, but
		# otherwise the options is 'dont summarise' which is a bit
		# double negative
                $options{OPT_SUMMARIZE()} = 0;
        }
        return $retval;
}

sub main()
{
	my $retval = 1;
	my $conf = new Config::General($options{OPT_CONFIG()});
	my %config = $conf->getall();
	# use the site details from config
	my $protocol = $config{'analyse'}{'protocol'};
	my $host = $config{'analyse'}{'host'};
	# set up the POST parameters
	my $data_type = $options{OPT_REPORT()};
	my $period = $options{OPT_PERIOD()};
	my $summarize = $options{OPT_SUMMARIZE()};
	my $format = 'text';
	my $button = "Load+Selection";
	# join all of the data fields into a POST data string
	my $post_data = join
	(
		'&',
		'data_type=' . $data_type,
		'period=' . $period,
		'summarize=' . ( $summarize ? 'frequency' : 'all' ),
		'format=' . $format,
	);
	# Connect to the site with POST parameters ...
	my $http_client = Net::HTTP->new
	(
		Host            => $host,
		HTTPVersion     => '1.1',
		send_te         => 0,
		KeepAlive       => 0,
	);
	$http_client->write_request
	(
		POST => '/data',
		Referrer => $protocol . '://' . $host,
		'Content-type' => 'application/x-www-form-urlencoded',
		$post_data
	);
	# and get / splat the data if successful response from the site
	my ($code, $mess, %h) = $http_client->read_response_headers();
	if ( '200' eq $code )
	{
		# Ripped straight off the Net:HTTP cpan page (thanks Gisle Aas)
		while (1) 
		{
			my $buf;
			my $n = $http_client->read_entity_body($buf, 1024);
			die "read failed: $!" unless defined $n;
			last unless $n;
			print $buf;
		}
	}
	else
	{
		err("RPZLA site did not like our request");
		err("Response: $code: $mess");
		err("POST data was: $post_data");
		$retval = 0;
	}
	return $retval;
}

parse_command_line();

exit( main() ? 0 : 1 );

# UNREACHED

__END__

=head1 NAME

rpzla-report-text.pl - Produce an RPZLA report and mail it

=head1 SYNOPSIS

rpzla-report-text.pl <-h|-m|-V>

or

rpzla-report-text.pl [-c /conf/path] [-p period] [-r report] [-s] addr...

=head1 DESCRIPTION

rpzla-report-text.pl queries the RPZLA website and prints
out the report in text.  It essentially just does a HTTP POST
with the relevant parameters.

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

