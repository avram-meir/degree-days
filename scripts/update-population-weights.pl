#!/usr/bin/env perl

=pod

=head1 NAME

update-population-weights - Given a list of regional populations, derive population weights for degree days calculations

=head1 SYNOPSIS

 update-population-weights.pl [-c|-d]
 update-population-weights.pl -h
 update-population-weights.pl -man

 [OPTION]            [DESCRIPTION]                                    [VALUES]

 -help, -h           Print usage message and exit
 -manual, -man       Display script documentation
 -populations, -p    File containing the populations data             Filename
 -output, -o         Output filename where weights will be written    Filename
 -regions, -r        Regions weights would be used to calculate       states, census, conus, us
                     Climate division populations are required for
                     states weighting. State populations are 
                     required for census, conus, or us weighting.

=head1 DESCRIPTION

=head2 PURPOSE

=head2 REQUIREMENTS

=over 3

=item * Perl v5.10 or later

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

# --- Identify script and location ---

my($script_name,$script_path,$script_suffix);
BEGIN { ($script_name,$script_path,$script_suffix) = fileparse(__FILE__, qr/\.[^.]*/); }

# --- Get the command-line options ---

my $help        = undef;
my $manual      = undef;
my $output      = "population_weights.txt";
my $pops_file   = undef;
my $regions     = undef;

GetOptions(
    'help|h'          => \$help,
    'manual|man'      => \$manual,
    'output|o=s'      => \$output,
    'populations|p=s' => \$pops_file,
    'regions|r=s'     => \$regions,
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

unless($pops_file)    { $opts_failed = join("\n",$opts_failed,'Option -populations must be supplied'); }
unless(-s $pops_file) { $opts_failed = join("\n",$opts_failed,'Option -populations must be set to an existing file'); }

unless($regions)      { $opts_failed = join("\n",$opts_failed,'Option -regions must be supplied'); }

if($regions) {

    unless($regions =~ /states/i or $regions =~ /census/i or $regions =~ /conus/i or $regions =~ /us/i) {
        $opts_failed = join("\n",$opts_failed,'Argument passed as -regions arg is invalid');
    }

}

if($opts_failed) {

    pod2usage( {
        -message => "$opts_failed\n",
        -exitval => 1,
        -verbose => 0,
    } );

}

print "Running update-population-weights to create weights used to compute $regions data from $pops_file\n";

# --- Set region definitions ---

my @climdivs = qw(AL01 AL02 AL03 AL04 AL05 AL06 AL07 AL08 AK01 AK02 AK03 AK04 AK05 AK06 AK07 AK08 AK09 AK10 AK11 AK12 AK13 AZ01 AZ02 AZ03 AZ04 AZ05 AZ06 AZ07 AR01 AR02 AR03 AR04 AR05 AR06 AR07 AR08 AR09 CA01 CA02 CA03 CA04 CA05 CA06 CA07 CO01 CO02 CO03 CO04 CO05 CT01 CT02 CT03 DE01 DE02 FL01 FL02 FL03 FL04 FL05 FL06 FL07 GA01 GA02 GA03 GA04 GA05 GA06 GA07 GA08 GA09 HI01 HI02 HI03 HI04 HI05 HI06 ID01 ID02 ID03 ID04 ID05 ID06 ID07 ID08 ID09 ID10 IL01 IL02 IL03 IL04 IL05 IL06 IL07 IL08 IL09 IN01 IN02 IN03 IN04 IN05 IN06 IN07 IN08 IN09 IA01 IA02 IA03 IA04 IA05 IA06 IA07 IA08 IA09 KS01 KS02 KS03 KS04 KS05 KS06 KS07 KS08 KS09 KY01 KY02 KY03 KY04 LA01 LA02 LA03 LA04 LA05 LA06 LA07 LA08 LA09 ME01 ME02 ME03 MD01 MD02 MD03 MD04 MD05 MD06 MD07 MD08 MA01 MA02 MA03 MI01 MI02 MI03 MI04 MI05 MI06 MI07 MI08 MI09 MI10 MN01 MN02 MN03 MN04 MN05 MN06 MN07 MN08 MN09 MS01 MS02 MS03 MS04 MS05 MS06 MS07 MS08 MS09 MS10 MO01 MO02 MO03 MO04 MO05 MO06 MT01 MT02 MT03 MT04 MT05 MT06 MT07 NE01 NE02 NE03 NE05 NE06 NE07 NE08 NE09 NV01 NV02 NV03 NV04 NH01 NH02 NJ01 NJ02 NJ03 NM01 NM02 NM03 NM04 NM05 NM06 NM07 NM08 NY01 NY02 NY03 NY04 NY05 NY06 NY07 NY08 NY09 NY10 NC01 NC02 NC03 NC04 NC05 NC06 NC07 NC08 ND01 ND02 ND03 ND04 ND05 ND06 ND07 ND08 ND09 OH01 OH02 OH03 OH04 OH05 OH06 OH07 OH08 OH09 OH10 OK01 OK02 OK03 OK04 OK05 OK06 OK07 OK08 OK09 OR01 OR02 OR03 OR04 OR05 OR06 OR07 OR08 OR09 PA01 PA02 PA03 PA04 PA05 PA06 PA07 PA08 PA09 PA10 RI01 SC01 SC02 SC03 SC04 SC05 SC06 SC07 SD01 SD02 SD03 SD04 SD05 SD06 SD07 SD08 SD09 TN01 TN02 TN03 TN04 TX01 TX02 TX03 TX04 TX05 TX06 TX07 TX08 TX09 TX10 UT01 UT02 UT03 UT04 UT05 UT06 UT07 VT01 VT02 VT03 VA01 VA02 VA03 VA04 VA05 VA06 WA01 WA02 WA03 WA04 WA05 WA06 WA07 WA08 WA09 WA10 WV01 WV02 WV03 WV04 WV05 WV06 WI01 WI02 WI03 WI04 WI05 WI06 WI07 WI08 WI09 WY01 WY02 WY03 WY04 WY05 WY06 WY07 WY08 WY09 WY10);
my %climdivs = map { $_ => 1 } @climdivs;
my @states   = qw(AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY);
my %states   = map { $_ => 1 } @states;
my %census_regions = split(' ', q(1 CT,ME,MA,NH,RI,VT 2 NJ,NY,PA 3 IN,IL,MI,OH,WI 4 IA,KS,MN,MO,NE,ND,SD 5 DE,FL,GA,MD,NC,SC,VA,WV 6 AL,KY,MS,TN 7 AR,LA,OK,TX 8 AZ,CO,ID,NM,MT,VT,UT,NV,WY 9 CA,OR,WA));

# --- Load populations data ---

unless(open(POPS,'<',$pops_file)) { die "Could not open $pops_file for reading - $! - exiting"; }
my @pops_contents = <POPS>; chomp @pops_contents;
close(POPS);

my %populations;

foreach my $line (@pops_contents) {
    my($region,$pop)      = split(',',$line);
    $populations{$region} = $pop;
}

# --- Check that we have the correct regions ---

my @keys_pops     = keys %populations;
my @keys_climdivs = keys %climdivs;
my @keys_states   = keys %states;

if($regions eq 'states') {  # Need climdivs
    if (join($;,sort(@keys_pops)) ne join($;,sort(@keys_climdivs))) { die "Population data in $pops_file did not match climdivs - exiting"; }
}
else { # Need states
    if (join($;,sort(@keys_pops)) ne join($;,sort(@keys_states)))   { die "Population data in $pops_file did not match states - exiting"; }
}

# --- Compute weights ---

my %sums;
if($regions eq 'states') { %sums = map { $_ => 0 } @states;              }
if($regions eq 'census') { %sums = map { $_ => 0 } keys %census_regions; }
if($regions eq 'conus')  { $sums{'conus'} = 0; }
if($regions eq 'us')     { $sums{'us'}    = 0; }

my %sum_group;

foreach my $sum (keys %sums) {
    my $sum_name   = $sum;
    if($regions eq 'census') { $sum_name = $census_regions{$sum}; }

    foreach my $region (keys %populations) {
        my $population = $populations{$region};
        if($regions eq 'states')    { if(substr($region,0,2) =~ /$sum_name/) { $sums{$sum} += $population; $sum_group{$region} = $sum_name; } }
        elsif($regions eq 'census') { if($region =~ /$sum_name/)             { $sums{$sum} += $population; $sum_group{$region} = $sum_name; } }
        else                                                                 { $sums{$sum} += $population; $sum_group{$region} = $sum_name; }
    }

}

my %popwts;

foreach my $region (keys %populations) {
    my $population   = $populations{$region};
    $popwts{$region} = $population/$sums{$sum_group{$region}};
}

# --- Write weights to output file ---

unless(open(OUTPUT,'>',$output)) { die "Could not open $output for writing - $! - exiting"; }
my @regions;
if($regions eq 'states') { @regions = @climdivs; }
else                     { @regions = @states;   }

foreach my $region (@regions) {
    print OUTPUT join(',',$region,$popwts{$region})."\n";
}

close(OUTPUT);
print "\n$output written!\n";

exit 0;

