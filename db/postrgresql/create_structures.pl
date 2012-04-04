#!/usr/bin/perl
use strict;
use warnings;

use Config::General;
use Getopt::Long qw(:config default no_ignore_case);
use Pod::Usage;
use File::Basename;
use English;

# command-line options
use constant OPT_CONFIG		=> 'config';
use constant OPT_USER           => 'user';
use constant OPT_NOOP           => 'noop';
use constant OPT_HELP           => 'help';
use constant OPT_MANUAL         => 'manual';
use constant OPT_VERSION        => 'Version';

use constant OPT_CONFIG_DEFAULT	=> '/etc/rpzla/rpzla.conf';
use constant OPT_USER_DEFAULT	=> 'postgres';

use constant SQL		=> 'psql';
use constant FIND		=> '<<<<SCHEMA>>>>';

my $version = '0.1';
my $ME = basename($PROGRAM_NAME);
my %options;
my $parse = GetOptions
(
        \%options,
        OPT_CONFIG() . '=s',
        OPT_USER() . '=s',
        OPT_NOOP(),
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
        if ( !defined($options{OPT_USER()}) )
        {
                $options{OPT_USER()} = OPT_USER_DEFAULT();
        }
        return $retval;
}

sub transform($)
{
	my $schema_name = shift;
	return "sed 's/" . FIND() . "/$schema_name/g'";
}

sub main()
{
	# Load the Config, needed for names/passwords
	my $conf_file = $options{OPT_CONFIG()};
	my $conf = new Config::General($conf_file);
	my %config = $conf->getall();
	my $schema = $config{db}{schema};
	my $db = $config{db}{name};
	my $user = $options{OPT_USER()};
	#
	# Create the DB first, the everything in it.  Check NOOP for testing.
	#
	my $create_db = "CREATE DATABASE $db;";
	print "\nMust create DB first, enter password:\n\n";
	system
	(
		"echo '$create_db' " . 
		( $options{OPT_NOOP()} ? 
			'' : 
			" | " . SQL() . " $user $user"
		)
	);
	print("\nNow we create everything else (password again):\n\n");
	my @cmds =
	(
		# the '(' .... ')' is IMPORTANT (pass it all to transform)
		"( echo CREATE SCHEMA $schema ",
		"cat create_tables.sql",
		"cat create_views.sql",
		"./create_users.pl -c $conf_file )",
	);
	#
	# 'transform' just does a global search replace with the chosen
	# schema name as obtained from the config.
	#
	# create_users.pl also loads the config an obeys its choices.
	#
	my $cmd = join(' && ', @cmds) ." | ". transform($schema) .
		( $options{OPT_NOOP()} ? '' : " | ". SQL() . " $db $user" );
	system($cmd);
	return $?;
}

parse_command_line();

exit( main() );

# UNREACHED

__END__

=head1 NAME

create_structures.pl - Create an RPZLA DB with data structures and access

=head1 SYNOPSIS

        create_structures.pl <-h|-m|-V>
or
        create_structures.pl [-c path-to-config] [-u super_user] [-n]

=head1 DESCRIPTION

create_structures.pl creates the database, schema, users, tables and 
views required for RPZLA based on the names (and passwords) found in
the config file.

All it does is print out the correct commands for the RDBMS type
and pipes them to the command-line tool for the RDBMS.

You provide the password (or not, depending on your RDBMS config) 
at the terminal after invocation and the SQL tool does the work.

See --noop for just printing out the commands and not running them
(careful passwords are printed).

=over

=item B<-c, --config path-to-config>

Override the default config location /etc/rpzla/rpzla.conf

=item B<-u, --user super_user>

Override the default super user of 'postgres'.  Password still required
in the terminal.

=item B<-n, --noop>

Just print out the 'SQL' commands and dont invoke the processing tool
(thus no terminal supplied password required).

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

