#!/usr/bin/env perl

=pod

=head1 NAME

calculate-degree-days - Create daily degree days data from Climate Prediction Center datasets and write to an archive

=head1 SYNOPSIS

 calculate-degree-days.pl [-c|-d]
 calculate-degree-days.pl -h
 calculate-degree-days.pl -man

 [OPTION]            [DESCRIPTION]                                    [VALUES]

 -config, -c         Degree days input/output configuration           Filename
 -date, -d           Date argument                                    YYYYMMDD
 -help, -h           Print usage message and exit
 -manual, -man       Display script documentation

=head1 DESCRIPTION

=head2 PURPOSE

=head2 REQUIREMENTS

=over 3

=item * Perl v5.10 or later

=item * External packages installed from CPAN:

=over 3

=item * Date::Manip

=item * Config::Simple

=back

=back

=head1 AUTHOR

Adam Allgood

=cut

use strict;
use warnings;
use Getopt::Long;
use File::Basename qw(fileparse basename);
use File::Copy qw(copy move);
use File::Path qw(mkpath);
use Scalar::Util qw(blessed looks_like_number openhandle);
use Pod::Usage;

# --- External CPAN packages ---

use Date::Manip;
use Config::Simple;

# --- Identify script and location ---

my($script_name,$script_path,$script_suffix);
BEGIN { ($script_name,$script_path,$script_suffix) = fileparse(__FILE__, qr/\.[^.]*/); }

# --- Application library packages ---

use lib "$script_path../lib";
use DegreeDays;
use CPC::TemperatureData::Climdivs;
use CPC::TemperatureData::CADB;

# --- Get the command-line options ---

my $config_file = '';
my $date        = ParseDateString('two days ago');  # Defaults to two days prior to system date if no -date option is supplied
my $help        = undef;
my $manual      = undef;

GetOptions(
    'config|c=s'     => \$config_file,
    'date|d=s'       => \$date,
    'help|h'         => \$help,
    'manual|man'     => \$manual,
);

# --- Handle options -help or -manual ---

if($help or $manual) {
        my $verbose = 0;
        if($manual) { $verbose = 2; }

        pod2usage( {
                -message => ' ',
                -exitval => 0,
                -verbose => $verbose,
        } );

}

# --- Validate options ---

my $opts_failed = '';

unless($config_file)    { $opts_failed = join("\n",$opts_failed,'Option -config must be supplied'); }
unless(-s $config_file) { $opts_failed = join("\n",$opts_failed,'Option -config must be set to an existing file'); }

my $day = Date::Manip::Date->new();
my $err = $day->parse($date);
if($err) { $opts_failed = join("\n",$opts_failed,"Invalid -date argument: $date"); }

if($opts_failed) {

    pod2usage( {
        -message => "$opts_failed\n",
        -exitval => 1,
        -verbose => 0,
    } );

}

print "Running calculate-degree-days for " . $day->printf("%Y%m%d") . " using parameters in $config_file\n";

# --- Pull information from the configuration file ---

my $config    = Config::Simple->new($config_file)->vars();
my $data_type = $config->{'archive.type'};
unless($data_type =~ /cadb/i or $data_type =~ /climdivs/i) { die "Data type $type is unsupported - exiting"; }
my $locations = $config->{'archive.location_list'};
open(LOCATIONS,'<',$locations) or die "Could not open $locations - $! - exiting";

# Do stuff with locations here?

close(LOCATIONS);

my($temperatures);

if($data_type =~ /cadb/i) {
    $temperatures = CPC::TemperatureData::CADB->new();
}
elsif($data_type =~ /climdivs/i) {
    $temperatures = CPC::TemperatureData::Climdivs->new();
}
else {
    die "Tell the software dev to add support for this data type - exiting";
}

# --- Get daily temperature data ---

$temperatures->set_max_archive($config->{'archive.max'});
$temperatures->set_min_archive($config->{'archive.min'});
my $tmax = $temperatures->get_max_data($day);
my $tmin = $temperatures->get_min_data($day);



# --- Calculate and write out degree days data ---




# --- End of script ---

exit 0;

sub parse_param {
    my $param = shift;
    my $day   = shift;

    # --- List of allowed variables that can be in the config file ---

    my %allowed_vars = (
        APP_PATH => "$script_path..",
        DATA_IN  => $ENV{DATA_IN},
        DATA_OUT => $ENV{DATA_OUT},
    );

    my $param_parsed = $param;
    $param_parsed    =~ s/\$(\w+)/exists $allowed_vars{$1} ? $allowed_vars{$1} : 'illegal000BLORT000illegal'/eg;
    if($param_parsed =~ /illegal000BLORT000illegal/) { die "Illegal variable found in $param"; }
    return $day->printf($param_parsed);
}

