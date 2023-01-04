#!/usr/bin/env perl

=pod

=head1 NAME

weighted-degree-days - Create daily weighted degree days data from the climate divisions degree days archive

=head1 SYNOPSIS

 weighted-degree-days.pl [-c|-i|-o]
 weighted-degree-days.pl -h
 weighted-degree-days.pl -man

 [OPTION]            [DESCRIPTION]                                    [VALUES]

 -config, -c         Weights configuration file                       Filename
 -help, -h           Print usage message and exit
 -input, -i          Climate divisions degree days file (input)       Filename
 -manual, -man       Display script documentation
 -output, -o         Output filename for weighted degree days         Filename

=head1 DESCRIPTION

=head2 PURPOSE

=head2 REQUIREMENTS

=over 3

=item * Perl v5.10 or later

=item * External packages installed from CPAN:

=over 3

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

use Config::Simple;

# --- Identify script and location ---

my($script_name,$script_path,$script_suffix);
BEGIN { ($script_name,$script_path,$script_suffix) = fileparse(__FILE__, qr/\.[^.]*/); }

chdir($script_path);

# --- Get the command-line options ---

my $config_file = undef;
my $help        = undef;
my $input_file  = undef;
my $manual      = undef;
my $output_file = undef;

GetOptions(
    'config|c=s'  => \$config_file,
    'help|h'      => \$help,
    'input|i=s'   => \$input_file,
    'manual|man'  => \$manual,
    'output|o=s'  => \$output_file,
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
unless($input_file)     { $opts_failed = join("\n",$opts_failed,'Option -input must be supplied'); }
unless(-s $input_file)  { $opts_failed = join("\n",$opts_failed,'Option -input must be set to an existing file'); }
unless($output_file)    { $opts_failed = join("\n",$opts_failed,'Option -output must be supplied'); }

if($opts_failed) {

    pod2usage( {
        -message => "$opts_failed\n",
        -exitval => 1,
        -verbose => 0,
    } );

}

# --- Create output directory if needed ---

my($output_name,$output_path,$output_suffix) = fileparse($output_file, qr/\.[^.]*/);
unless(-d $output_path) { mkpath($output_path) or die "Could not create output directory $output_path - $! - exiting"; }

# --- Get information from the configuration file ---

my $weights = Config::Simple->new($config_file)->vars();

# --- Get climate divisions degree days data ---

my @climdivs = qw(AL01 AL02 AL03 AL04 AL05 AL06 AL07 AL08 AK01 AK02 AK03 AK04 AK05 AK06 AK07 AK08 AK09 AK10 AK11 AK12 AK13 AZ01 AZ02 AZ03 AZ04 AZ05 AZ06 AZ07 AR01 AR02 AR03 AR04 AR05 AR06 AR07 AR08 AR09 CA01 CA02 CA03 CA04 CA05 CA06 CA07 CO01 CO02 CO03 CO04 CO05 CT01 CT02 CT03 DE01 DE02 FL01 FL02 FL03 FL04 FL05 FL06 FL07 GA01 GA02 GA03 GA04 GA05 GA06 GA07 GA08 GA09 HI01 HI02 HI03 HI04 HI05 HI06 ID01 ID02 ID03 ID04 ID05 ID06 ID07 ID08 ID09 ID10 IL01 IL02 IL03 IL04 IL05 IL06 IL07 IL08 IL09 IN01 IN02 IN03 IN04 IN05 IN06 IN07 IN08 IN09 IA01 IA02 IA03 IA04 IA05 IA06 IA07 IA08 IA09 KS01 KS02 KS03 KS04 KS05 KS06 KS07 KS08 KS09 KY01 KY02 KY03 KY04 LA01 LA02 LA03 LA04 LA05 LA06 LA07 LA08 LA09 ME01 ME02 ME03 MD01 MD02 MD03 MD04 MD05 MD06 MD07 MD08 MA01 MA02 MA03 MI01 MI02 MI03 MI04 MI05 MI06 MI07 MI08 MI09 MI10 MN01 MN02 MN03 MN04 MN05 MN06 MN07 MN08 MN09 MS01 MS02 MS03 MS04 MS05 MS06 MS07 MS08 MS09 MS10 MO01 MO02 MO03 MO04 MO05 MO06 MT01 MT02 MT03 MT04 MT05 MT06 MT07 NE01 NE02 NE03 NE05 NE06 NE07 NE08 NE09 NV01 NV02 NV03 NV04 NH01 NH02 NJ01 NJ02 NJ03 NM01 NM02 NM03 NM04 NM05 NM06 NM07 NM08 NY01 NY02 NY03 NY04 NY05 NY06 NY07 NY08 NY09 NY10 NC01 NC02 NC03 NC04 NC05 NC06 NC07 NC08 ND01 ND02 ND03 ND04 ND05 ND06 ND07 ND08 ND09 OH01 OH02 OH03 OH04 OH05 OH06 OH07 OH08 OH09 OH10 OK01 OK02 OK03 OK04 OK05 OK06 OK07 OK08 OK09 OR01 OR02 OR03 OR04 OR05 OR06 OR07 OR08 OR09 PA01 PA02 PA03 PA04 PA05 PA06 PA07 PA08 PA09 PA10 RI01 SC01 SC02 SC03 SC04 SC05 SC06 SC07 SD01 SD02 SD03 SD04 SD05 SD06 SD07 SD08 SD09 TN01 TN02 TN03 TN04 TX01 TX02 TX03 TX04 TX05 TX06 TX07 TX08 TX09 TX10 UT01 UT02 UT03 UT04 UT05 UT06 UT07 VT01 VT02 VT03 VA01 VA02 VA03 VA04 VA05 VA06 WA01 WA02 WA03 WA04 WA05 WA06 WA07 WA08 WA09 WA10 WV01 WV02 WV03 WV04 WV05 WV06 WI01 WI02 WI03 WI04 WI05 WI06 WI07 WI08 WI09 WY01 WY02 WY03 WY04 WY05 WY06 WY07 WY08 WY09 WY10);
my %climdivs = map { $_ => 1 } @climdivs;

open(INPUT,'<',$input_file) or die "Could not open $input_file for reading - $! - exiting";
my @input_data = <INPUT>; chomp @input_data;
close(INPUT);

my $header = shift(@input_data);
my($dd_regions,$dd_type) = split(',',$header);
my %degree_days;

foreach my $line (@input_data) {
    my($cd,$ddval)    = split(',',$line);
    $degree_days{$cd} = $ddval;
}

# --- Get climate divisions weights ---

my $cdwts_file = "../weights/".$weights->{'climdivs.weights'};
open(CDWTS,'<',$cdwts_file) or die "Could not open $cdwts_file for reading - $! - exiting";
my @cdwts = <CDWTS>; chomp @cdwts;
close(CDWTS);

my %wts_climdivs;

foreach my $line (@cdwts) {
    my($cd,$wt)    = split(',',$line);
    $wts_climdivs{$cd} = $wt;
}

# --- Get population weighted state degree days ---

my @states_names = ("Alabama","Alaska","Arizona","Arkansas","California","Colorado","Connecticut","Delaware","Florida","Georgia","Hawaii","Idaho","Illinois","Indiana","Iowa","Kansas","Kentucky","Louisiana","Maine","Maryland","Massachusetts","Michigan","Minnesota","Mississippi","Missouri","Montana","Nebraska","Nevada","New Hampshire","New Jersey","New Mexico","New York","North Carolina","North Dakota","Ohio","Oklahoma","Oregon","Pennsylvania","Rhode Island","South Carolina","South Dakota","Tennessee","Texas","Utah","Vermont","Virginia","Washington","West Virginia","Wisconsin","Wyoming");
my @us_states   = qw(AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY);
my %states;
@states{@us_states} = @states_names;
my %dd_states   = map { $_ => 0 } @us_states;

foreach my $cd (keys %climdivs) {
    my $st = substr($cd,0,2);
    $dd_states{$st} += $wts_climdivs{$cd}*$degree_days{$cd};
}

# --- Write state degree days to file ---

open(OUTPUT,'>',$output_file) or die "Could not open $output_file for writing - $! - exiting";

print OUTPUT join(',','Population Weighted States',$dd_type)."\n";

foreach my $st (@us_states) {
    print OUTPUT join(',',$states{$st},int($dd_states{$st}+0.5))."\n";
}

# --- Get Census division, CONUS, and US weighted degree days ---

my %census_regions = split(' ', q(1 CT,ME,MA,NH,RI,VT 2 NJ,NY,PA 3 IN,IL,MI,OH,WI 4 IA,KS,MN,MO,NE,ND,SD 5 DE,FL,GA,MD,NC,SC,VA,WV 6 AL,KY,MS,TN 7 AR,LA,OK,TX 8 AZ,CO,ID,NM,MT,VT,UT,NV,WY 9 CA,OR,WA));
my %census_names   = (
    1 => 'NEW ENGLAND',
    2 => 'MIDDLE ATLANTIC',
    3 => 'E N CENTRAL',
    4 => 'W N CENTRAL',
    5 => 'SOUTH ATLANTIC',
    6 => 'E S CENTRAL',
    7 => 'W S CENTRAL',
    8 => 'MOUNTAIN',
    9 => 'PACIFIC',
);

my $n = 0;

while(exists $weights->{"states$n.name"}) {

    # --- Get the weights needed for Census Divisions, CONUS, and US degree days ---

    my $censuswts_file = "../weights/".$weights->{"states$n.census"};
    open(CENSUSWTS,'<',$censuswts_file) or die "Could not open $censuswts_file for reading - $! - exiting";
    my @censuswts = <CENSUSWTS>; chomp @censuswts;
    close(CENSUSWTS);

    my %wts_states_census;

    foreach my $line (@censuswts) {
        my($st,$wt)    = split(',',$line);
        $wts_states_census{$st} = $wt;
    }

    my $conuswts_file = "../weights/".$weights->{"states$n.conus"};
    open(CONUSWTS,'<',$conuswts_file) or die "Could not open $conuswts_file for reading - $! - exiting";
    my @conuswts = <CONUSWTS>; chomp @conuswts;
    close(CONUSWTS);

    my %wts_states_conus;
    
    foreach my $line (@conuswts) {
        my($st,$wt)    = split(',',$line);
        $wts_states_conus{$st} = $wt;
    }

    $wts_states_conus{'AK'} = 0;
    $wts_states_conus{'HI'} = 0;

    my $uswts_file = "../weights/".$weights->{"states$n.us"};
    open(USWTS,'<',$uswts_file) or die "Could not open $uswts_file for reading - $! - exiting";
    my @uswts = <USWTS>; chomp @uswts;
    close(USWTS);

    my %wts_states_us;

    foreach my $line (@uswts) {
        my($st,$wt)    = split(',',$line);
        $wts_states_us{$st} = $wt;
    }

    # --- Calculate the weighted degree days ---

    my %dd_census = map { $_ => 0 } keys %census_regions;
    my $dd_conus  = 0;
    my $dd_us     = 0;

    foreach my $st (@us_states) {

        for(my $div=1; $div<10; $div++) {
            my $states_in_div = $census_regions{$div};
            my @states_in_div = split(',',$states_in_div);
            my %states_in_div = map { $_ => 1 } @states_in_div;
            if(exists $states_in_div{$st}) { $dd_census{$div} += $wts_states_census{$st}*$dd_states{$st}; }
        }

        $dd_conus += $wts_states_conus{$st}*$dd_states{$st};
        $dd_us    += $wts_states_us{$st}*$dd_states{$st};
    }

    # --- Write Census division, CONUS, and US degree days to file ---

    print OUTPUT join(',',"\"".$weights->{"states$n.name"}."\"",$dd_type)."\n";

    for(my $div=1; $div<10; $div++) {
        print OUTPUT join(',',$census_names{$div},int($dd_census{$div}+0.5))."\n";
    }

    print OUTPUT join(',','CONUS',int($dd_conus+0.5))."\n";
    print OUTPUT join(',','US',int($dd_us+0.5))."\n";
    $n++;
}

close(OUTPUT);

print "   $output_file written!\n";
exit 0;

