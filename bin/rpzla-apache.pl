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
        return $retval;
}

# return the command for the pipeline
sub make_cmd($)
{
	my $conf = shift;
	my $log = $conf->{'walled-garden'}{log};
	return "rpzla-apache-filter.pl -f $log | " .
		"rpzla-apache-to-db.pl -c " .  $options{OPT_CONFIG()}
}

sub main()
{
	my $retval = 1;
	my $conf = new Config::General($options{OPT_CONFIG()});
	my %config = $conf->getall();
	# Should deamonise this ...
	my $cmd = make_cmd(\%config);
	system($cmd);
	return $retval;
}

parse_command_line();

exit( main() ? 0 : 1 );

# UNREACHED

__END__

=head1 NAME

rpzla-apache.pl - watch a walled garden web-site and tranfer access logs

=head1 SYNOPSIS

        rpzla-apache.pl <-h|-m|-V>
or
        rpzla-apache.pl [-c /path/to/config]

=head1 DESCRIPTION

rpzla-apache.pl launches a pipeline to watch the walled garden apache
log (as defined in /etc/rpzla.conf) and transfer access events to 
a database (also defined in the config).

=head1 OPTIONS

=over

=item B<-c, --config>

The path to the config file.  Defaults to /etc/rpzla/rpzla.conf

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

