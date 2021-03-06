#!/usr/bin/perl
use strict;
use warnings;

use Config::General;
use English;
use Getopt::Long qw(:config default no_ignore_case);
use Pod::Usage;
use File::Basename;

# command-line options
use constant OPT_CONFIG		=> 'config';
use constant OPT_HELP           => 'help';
use constant OPT_MANUAL         => 'manual';
use constant OPT_VERSION        => 'Version';

use constant OPT_CONFIG_DEFAULT	=> '/etc/rpzla/rpzla.conf';

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
                $options{OPT_CONFIG()} = OPT_CONFIG_DEFAULT();
        }
	if ( ! -f $options{OPT_CONFIG()} or ! -r $options{OPT_CONFIG()} )
	{
		err("Config file '" . $options{OPT_CONFIG()} . 
			"' does not exist or cant be read.");
		exit(1);
	}
        return $retval;
}

sub make_insert_user($$$)
{
	my ($schema,$user,$pass) = @_;
	print "
CREATE USER $user WITH PASSWORD '$pass';
GRANT USAGE on SCHEMA $schema to $user;
GRANT INSERT on TABLE $schema.web to $user;
GRANT INSERT on TABLE $schema.dns to $user;
";
}

sub make_select_user($$$)
{
	my ($schema,$user,$pass) = @_;
	print "
CREATE USER $user WITH PASSWORD '$pass';
GRANT USAGE on SCHEMA $schema to $user;
GRANT SELECT on TABLE $schema.web to $user;
GRANT SELECT on TABLE $schema.dns to $user;
";
	#
	# TODO:
	#
	# This is crap, should use the database to find out all the view
	# names.  Needs fixing.
	#
	my @views = 
	(
		"dns_day",
		"dns_week",
		"dns_month",
		"dns_day_trunc",
		"dns_week_trunc",
		"dns_month_trunc",
		"dns_day_frequency",
		"dns_week_frequency",
		"dns_month_frequency",
		"dns_day_all",
		"dns_week_all",
		"dns_month_all",
		"web_day",
		"web_week",
		"web_month",
		"web_day_trunc",
		"web_week_trunc",
		"web_month_trunc",
		"web_day_frequency",
		"web_week_frequency",
		"web_month_frequency",
		"web_day_all",
		"web_week_all",
		"web_month_all",
		"cor_day_web",
		"cor_week_web",
		"cor_month_web",
		"cor_day_dns",
		"cor_week_dns",
		"cor_month_dns",
	);
	for my $view ( @views )
	{
		# Note if you add 'VIEW' as in 'SELECT on VIEW foo' 
		# it **FAILS**  wot?
		print "GRANT SELECT on $schema.$view to $user;\n";
	}
}

sub main()
{
	my $conf = new Config::General($options{OPT_CONFIG()});
	my %config = $conf->getall();
	my $schema = $config{db}{schema};
	my $user;
	my $pass;
	$user = $config{db}{log}{user};
	$pass = $config{db}{log}{pass};
	make_insert_user($schema, $user, $pass);
	$user = $config{db}{analysis}{user};
	$pass = $config{db}{analysis}{pass};
	make_select_user($schema, $user, $pass);
	return 1;
}

parse_command_line();

exit( main() ? 0 : 1 );

# UNREACHED

__END__

=head1 NAME

create_users.pl - Produce CREATE USER statement for RPZLA on PostgreSQL

=head1 SYNOPSIS

        create_users.pl <-h|-m|-V>
or
        create_users.pl [-c path-to-config] 

=head1 DESCRIPTION

create_users.pl prints out 'CREATE USER' type statements (and associated
GRANT statements) for users in RPZLA access.

The config file provices the names and passwords of users (used in 
creation) and the names of the schema (used for privilege control).

=over

=item B<-c, --config path-to-config>

Override the default config location /etc/rpzla/rpzla.conf

=item B<-h, -?, --help>

Prints a help message.

=item B<-m, --man, --manual>

Prints the manual page.

=item B<-V, --Version>

Print the software version.

=back

=head1 AUTHOR

Hugo M. Connery

=head1 LICENSE

GNU Public License version 2. (GPLv2)

=cut

