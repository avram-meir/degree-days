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
use Text::ParseWords;

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

# --- Only allow data types we can handle ---

unless($data_type =~ /cadb/i or $data_type =~ /climdivs/i) { die "Data type $type is unsupported - exiting"; }

# --- Get location information ---

my $locations = $config->{'archive.location_list'};
my @location_ids;
open(LOCATIONS,'<',$locations) or die "Could not open $locations - $! - exiting";
my @locations = <LOCATIONS>; chomp @locations;
close(LOCATIONS);

foreach my $location (@locations) {
    my @location_info = Text::ParseWords::parse_line(',', 0, $location);
    push(@location_ids,$location_info[0]);
}

# --- Set up CPC::TemperatureData object ---

my($temperatures,$missing_val);

if($data_type =~ /cadb/i) {
    $temperatures = CPC::TemperatureData::CADB->new();
    $missing_val  = -99999;
}
elsif($data_type =~ /climdivs/i) {
    $temperatures = CPC::TemperatureData::Climdivs->new();
    $missing_val  = -9999;
}
else {
    die "Tell the software dev to add support for this data type - exiting";
}

# --- Get daily temperature data ---

$temperatures->set_max_archive($config->{'archive.max'});
$temperatures->set_min_archive($config->{'archive.min'});
my $tmax = $temperatures->get_max_data($day);
my $tmin = $temperatures->get_min_data($day);

# --- Set up output information and open output files ---

my %degree_day_types;
my %output_FH;
my %output_headers;

my %degree_day_subs = (
    cooling => \&cooling,
    growing => \&growing,
    heating => \&heating,
);

foreach my $dd qw(cooling growing heating) {

    if(defined $config->{"output.$dd"}) {
        $degree_day_types{$dd} = $day->printf($config->{"output.$dd"});
        $degree_day_FH{$dd}    = uc($dd);
        if(defined $config->{"output.$dd\_header"}) { $output_headers{$dd} = $config->{"output.$dd\_header"}; }
        else { $output_headers{$dd} = ucfirst($dd) . " Degree Days"; }
        open($degree_day_FH{$dd},'>',$degree_day_types{$dd}) or die "Could not open " . $degree_day_types{$dd} . " for writing - $! - exiting";
        print $degree_day_FH{$dd} $output_headers{$dd} . "\n";
    }

}

# --- Calculate and write out degree days data ---

foreach my $location (@location_ids) {

    foreach my $dd (keys %degree_day_types) {
        
    }

}

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

