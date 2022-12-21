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
use Scalar::Util qw(blessed looks_like_number openhandle reftype);
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
use CPC::DailyTemperatures::Climdivs;
use CPC::DailyTemperatures::CADB;

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

my $config = Config::Simple->new($config_file)->vars();
foreach my $var (keys %{$config}) { $config->{$var} = parse_param($config->{$var},$day); }

# --- Load locations ---

my @locations;

if(exists $config->{'input.locations'}) {
    open(LOCATIONS,'<',$config->{'input.locations'}) or die "Could not open " . $config->{'input.locations'} . " for reading - $! - exiting";
    my @locations_contents = <LOCATIONS>; chomp @locations_contents;
    close(LOCATIONS);

    foreach my $loc (@locations_contents) {
        $loc =~ s/\'//g;
        my @loc_info = Text::ParseWords::parse_line(',',0,$loc);
        push(@locations,$loc_info[0]);
    }

}
else {
    die "No input locations found in $config_file - exiting";
}

if(scalar(@locations) < 1) {
    die "No locations were found in " . $config->{'input.locations'} . " - exiting";
}

# --- Load temperature data ---

my($tmax,$tmin);

if($config->{'input.type'} eq 'climdivs') {
    unless(-s $config->{'input.tmax'}) { die "No tmax data found in the archive - exiting"; }
    unless(-s $config->{'input.tmin'}) { die "No tmin data found in the archive - exiting"; }
    my $cd_temps = CPC::DailyTemperatures::Climdivs->new();
    $cd_temps->set_missing(-9999);
    $tmax = $cd_temps->get_data($config->{'input.tmax'});
    $tmin = $cd_temps->get_data($config->{'input.tmin'});
    unless(reftype($tmax) eq 'HASH') { die "TMAX data were not loaded - exiting"; }
    unless(reftype($tmin) eq 'HASH') { die "TMIN data were not loaded - exiting"; }
}
elsif($config->{'input.type'} eq 'cadb') {
    unless(-s $config->{'input.tmax'}) { die "No tmax data found in the archive - exiting"; }
    unless(-s $config->{'input.tmin'}) { die "No tmin data found in the archive - exiting"; }
    my $stn_temps = CPC::DailyTemperatures::CADB->new();
    $stn_temps->set_missing(-99999);
    $tmax = $stn_temps->get_data($config->{'input.tmax'},'tmax');
    $tmin = $stn_temps->get_data($config->{'input.tmin'},'tmin');
    unless(reftype($tmax) eq 'HASH') { die "TMAX data were not loaded - exiting"; }
    unless(reftype($tmin) eq 'HASH') { die "TMIN data were not loaded - exiting"; }

    # --- Convert temperatures to Fahrenheit ---

    foreach my $loc (keys %$tmax) { unless($tmax->{$loc} == -999) { $tmax->{$loc} = ($tmax->{$loc}*9/5) + 32; } }
    foreach my $loc (keys %$tmin) { unless($tmin->{$loc} == -999) { $tmin->{$loc} = ($tmin->{$loc}*9/5) + 32; } }
}
elsif(exists $config->{'input.type'}) {
    die "Unknown input type found in $config_file - exiting";
}
else {
    die "No input type found in $config_file - exiting";
}

# --- Calculate and write degree days to output files ---

if(exists $config->{'output.cooling'}) {
    my($output_name,$output_path,$output_suffix) = fileparse($config->{'output.cooling'}, qr/\.[^.]*/);
    unless(-d $output_path) { mkpath($output_path) or die "Could not create directory $output_path - $! - exiting"; }
    unless(open(COOLING,'>',$config->{'output.cooling'})) { die "Could not open " . $config->{'output.cooling'} . " for writing - $! - exiting"; }
    if(exists $config->{'cooling.type'}) { print COOLING join(',','Location',$config->{'cooling.type'}."\n"); }
    else { print COOLING 'Location|Cooling Degree Days'."\n"; }
}

if(exists $config->{'output.growing'}) {
    my($output_name,$output_path,$output_suffix) = fileparse($config->{'output.growing'}, qr/\.[^.]*/);
    unless(-d $output_path) { mkpath($output_path) or die "Could not create directory $output_path - $! - exiting"; }
    unless(open(GROWING,'>',$config->{'output.growing'})) { die "Could not open " . $config->{'output.growing'} . " for writing - $! - exiting"; }
    if(exists $config->{'growing.type'}) { print GROWING join(',','Location',$config->{'growing.type'}."\n"); }
    else { print GROWING 'Location|Growing Degree Days'."\n"; }
}

if(exists $config->{'output.heating'}) {
    my($output_name,$output_path,$output_suffix) = fileparse($config->{'output.heating'}, qr/\.[^.]*/);
    unless(-d $output_path) { mkpath($output_path) or die "Could not create directory $output_path - $! - exiting"; }
    unless(open(HEATING,'>',$config->{'output.heating'})) { die "Could not open " . $config->{'output.heating'} . " for writing - $! - exiting"; }
    if(exists $config->{'heating.type'}) { print HEATING join(',','Location',$config->{'heating.type'}."\n"); }
    else { print HEATING 'Location|Heating Degree Days'."\n"; }
}

my $cdd = DegreeDays->new();
my $gdd = DegreeDays->new();
my $hdd = DegreeDays->new();
if($config->{'cooling.base'}) { $cdd->base($config->{'cooling.base'}); }
if($config->{'growing.base'}) { $gdd->base($config->{'growing.base'}); }
if($config->{'growing.ceil'}) { $gdd->ceil($config->{'growing.ceil'}); }
if($config->{'heating.base'}) { $hdd->base($config->{'heating.base'}); }

LOC: foreach my $loc (@locations) {

    if(exists $config->{'output.cooling'}) {
        my $value = -999;
        if($tmax->{$loc} != -999 and $tmin->{$loc} != -999) { $value = $cdd->cooling($tmax->{$loc},$tmin->{$loc}); }
        print COOLING join(',',$loc,$value."\n");
    }

    if(exists $config->{'output.growing'}) {
        my $value = -999;
        if($tmax->{$loc} != -999 and $tmin->{$loc} != -999) { $value = $gdd->growing($tmax->{$loc},$tmin->{$loc}); }
        print GROWING join(',',$loc,$value."\n");
    }

    if(exists $config->{'output.heating'}) {
        my $value = -999;
        if($tmax->{$loc} != -999 and $tmin->{$loc} != -999) { $value = $hdd->heating($tmax->{$loc},$tmin->{$loc}); }
        print HEATING join(',',$loc,$value."\n");
    }
    
}  # :LOC

if(exists $config->{'output.cooling'}) {
    close(COOLING);
    print "   " . $config->{'output.cooling'} . " written!\n";
}

if(exists $config->{'output.growing'}) {
    close(GROWING);
    print "   " . $config->{'output.growing'} . " written!\n";
}

if(exists $config->{'output.heating'}) {
    close(HEATING);
    print "   " . $config->{'output.heating'} . " written!\n";
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
        FTP_IN   => $ENV{FTP_IN},
    );

    my $param_parsed = $param;
    $param_parsed    =~ s/\$(\w+)/exists $allowed_vars{$1} ? $allowed_vars{$1} : 'illegal000BLORT000illegal'/eg;
    if($param_parsed =~ /illegal000BLORT000illegal/) { die "Illegal variable found in $param"; }
    return $day->printf($param_parsed);
}

