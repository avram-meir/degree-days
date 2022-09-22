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

my $config    = Config::Simple->new($config_file)->vars();
foreach my $var (keys %{$config}) { $config->{$var} = parse_param($config->{$var},$day); }
my($cd_tmax,$cd_tmin,$st_temp,$stations,$cd_output,$st_output);
if(exists $config->{'input.climdivs_tmax'}) { $cd_tmax   = $config->{'input.climdivs_tmax'}; }
if(exists $config->{'input.climdivs_tmin'}) { $cd_tmin   = $config->{'input.climdivs_tmin'}; }
if(exists $config->{'input.cadb'})          { $st_temp   = $config->{'input.cadb'};          }
if(exists $config->{'input.cadb_stations'}) { $stations  = $config->{'input.cadb_stations'}; }
if(exists $config->{'output.climdivs'})     { $cd_output = $config->{'output.climdivs'};     }
if(exists $config->{'output.cadb'})         { $st_output = $config->{'output.cadb'};         }

# --- Get station list ---

my(@station_ids);

if($stations) {

    if(-s $stations) {
        open(STATIONS,'<',$stations) or die "Could not open $stations - $! - exiting";
        my @stations_contents = <STATIONS>; chomp @stations_contents;
        close(STATIONS);

        foreach my $station (@stations_contents) {
            my @station_info = Text::ParseWords::parse_line(',', 0, $station);
            push(@station_ids,$station_info[0]);
        }

    }
    else {
        warn "Cannot load stations list - $stations file does not exist";
    }

}

# --- Get temperature data ---

my $cd_data = CPC::DailyTemperatures::Climdivs->new();
my $st_data = CPC::DailyTemperatures::CADB->new();
$cd_data->set_missing(-9999);
$st_data->set_missing(-99999);
if(@station_ids) { $st_data->set_locations(@station_ids); }
my($climdivs_tmax,$climdivs_tmin,$stations_tmax,$stations_tmin);
if($cd_tmax) { $climdivs_tmax = $cd_data->get_data($cd_tmax);        }
if($cd_tmin) { $climdivs_tmin = $cd_data->get_data($cd_tmin);        }
if($st_temp) { $stations_tmax = $st_data->get_data($st_temp,'tmax');
               $stations_tmin = $st_data->get_data($st_temp,'tmin'); }

# --- Calculate degree days ---

my $dd = DegreeDays->new();
my($cd_cdd,$cd_gdd,$cd_hdd);
my($st_cdd,$st_gdd,$st_hdd);
my($output_climdivs,$output_stations);

if($climdivs_tmax and $climdivs_tmin) {

    foreach my $cd (keys %{$climdivs_tmax}) {
        my $cdd = $dd->cooling($climdivs_tmax->{$cd},$climdivs_tmin->{$cd});
        my $gdd = $dd->growing($climdivs_tmax->{$cd},$climdivs_tmin->{$cd});
        my $hdd = $dd->heating($climdivs_tmax->{$cd},$climdivs_tmin->{$cd});
        $cd_cdd->{$cd} = $cdd;
        $cd_gdd->{$cd} = $gdd;
        $cd_hdd->{$cd} = $hdd;
    }

    $output_climdivs = 1;
}
elsif($climdivs_tmax and not $climdivs_tmin) {
    warn "No tmin data on climate divisions ingested";
}
elsif($climdivs_tmin and not $climdivs_tmax) {
    warn "No tmax data on climate divisions ingested";
}

if($stations_tmax and $stations_tmin) {

    foreach my $stn (keys %{$stations_tmax}) {
        my $cdd = $dd->cooling($stations_tmax->{$stn},$stations_tmin->{$stn});
        my $gdd = $dd->growing($stations_tmax->{$stn},$stations_tmin->{$stn});
        my $hdd = $dd->heating($stations_tmax->{$stn},$stations_tmin->{$stn});
        $st_cdd->{$stn} = $cdd;
        $st_gdd->{$stn} = $gdd;
        $st_hdd->{$stn} = $hdd;
    }

    $output_stations = 1;
}
elsif($stations_tmax and not $stations_tmin) {
    warn "No tmin data from the CADB ingested";
}
elsif($stations_tmin and not $stations_tmax) {
    warn "No tmax data from the CADB ingested";
}

# --- Write degree days data to files ---

if($output_climdivs) {
    my $locations  = $cd_data->get_locations();
    my $output_cdd = join('_',$cd_output,'cdd.txt');
    my $output_gdd = join('_',$cd_output,'gdd.txt');
    my $output_hdd = join('_',$cd_output,'hdd.txt');
    open(CDD,'>',$output_cdd) or die "Could not open $output_cdd for writing - $! - exiting";
    open(GDD,'>',$output_gdd) or die "Could not open $output_gdd for writing - $! - exiting";
    open(HDD,'>',$output_hdd) or die "Could not open $output_hdd for writing - $! - exiting";
    print CDD "Climdiv,Cooling Degree Days\n";
    print GDD "Climdiv,Growing Degree Days\n";
    print HDD "Climdiv,Heating Degree Days\n";

    foreach my $location (@{$locations}) {
        print CDD join(',',$location,$cd_cdd->{$location}."\n");
        print GDD join(',',$location,$cd_gdd->{$location}."\n");
        print HDD join(',',$location,$cd_hdd->{$location}."\n");
    }

    close(CDD);
    close(GDD);
    close(HDD);
    print "   $output_cdd written!\n";
    print "   $output_gdd written!\n";
    print "   $output_hdd written!\n";
}

if($output_stations) {
    my $locations  = $st_data->get_locations();
    my $output_cdd = join('_',$st_output,'cdd.txt');
    my $output_gdd = join('_',$st_output,'gdd.txt');
    my $output_hdd = join('_',$st_output,'hdd.txt');
    open(CDD,'>',$output_cdd) or die "Could not open $output_cdd for writing - $! - exiting";
    open(GDD,'>',$output_gdd) or die "Could not open $output_gdd for writing - $! - exiting";
    open(HDD,'>',$output_hdd) or die "Could not open $output_hdd for writing - $! - exiting";
    print CDD "Station,Cooling Degree Days\n";
    print GDD "Station,Growing Degree Days\n";
    print HDD "Station,Heating Degree Days\n";

    foreach my $location (@{$locations}) {
        print CDD join(',',$location,$st_cdd->{$location}."\n");
        print GDD join(',',$location,$st_gdd->{$location}."\n");
        print HDD join(',',$location,$st_hdd->{$location}."\n");
    }

    close(CDD);
    close(GDD);
    close(HDD);
    print "   $output_cdd written!\n";
    print "   $output_gdd written!\n";
    print "   $output_hdd written!\n";
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

