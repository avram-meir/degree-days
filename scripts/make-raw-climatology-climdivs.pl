#!/usr/bin/perl

=pod

=head1 NAME

make-raw-climatology - Create a climatology using a CPC degree days formatted archive

=head1 SYNOPSIS

 make-raw-climatology.pl [-a|-p|-o]
 make-raw-climatology.pl -h
 make-raw-climatology.pl -man

 [OPTION]            [DESCRIPTION]                                    [VALUES]

 -archive, -a        Archive where the daily dataset is found. Unix   Filename
                     date wildcards can be used in the path. Certain 
                     environment variables can also be used in the 
                     path. To refer to this application's location, 
                     use the variable $APP_PATH.
 -help, -h           Print usage message and exit
 -manual, -man       Display script documentation
 -output, -o         Output archive where the daily climatology 
                     will be written. Unix date wildcards and 
                     allowed variables are the same as in the 
                     archive argument.
 -period, -p         Climatology period to use in the calculation     yyyy1-yyyy2 (e.g., 1991-2020)

=head1 DESCRIPTION

=head2 PURPOSE

=head2 REQUIREMENTS

=over 3

=item * Perl v5.10 or later

=item * Date::Manip installed from CPAN

=back

=head1 AUTHOR

Adam Allgood

This documentation was last updated on: 23FEB2022

=cut

use strict;
use warnings;
use Getopt::Long;
use File::Basename qw(fileparse basename);
use File::Copy qw(copy move);
use File::Path qw(mkpath);
require File::Temp;
use File::Temp ();
use File::Temp qw(:seekable);
use Scalar::Util qw(blessed looks_like_number openhandle);
use Pod::Usage;
use Date::Manip;
use Config::Simple;
use utf8;

# --- Identify script ---

my($script_name,$script_path,$script_suffix);
BEGIN { ($script_name,$script_path,$script_suffix) = fileparse(__FILE__, qr/\.[^.]*/); }

# --- Get the command-line options ---

my $archive     = undef;
my $help        = undef;
my $manual      = undef;
my $output      = undef;
my $period      = undef;

GetOptions(
	'archive|a=s'    => \$archive,
	'help|h'         => \$help,
	'manual|man'     => \$manual,
	'output|o=s'     => \$output,
	'period|p=s'     => \$period,
);

# --- Process options -help or -manual if invoked ---

if($help or $manual) {
	my $verbose = 0;
	if($manual) { $verbose = 2; }

	pod2usage( {
		-message => ' ',
		-exitval => 0,
		-verbose => $verbose,
	} );

}

my $opts_failed = '';

# --- List of allowed variables that can be in the archive and output args ---

my %allowed_vars = (
	APP_PATH => "$script_path../..",
	DATA_IN  => $ENV{DATA_IN},
	DATA_OUT => $ENV{DATA_OUT},
	FTP_IN   => $ENV{FTP_IN},
	FTP_OUT  => $ENV{FTP_OUT},
);

# --- Validate archive argument ---

unless($archive) { $opts_failed = join("\n",$opts_failed,'Option -archive must be supplied'); }
$archive =~ s/\$(\w+)/exists $allowed_vars{$1} ? $allowed_vars{$1} : 'illegal000BLORT000illegal'/eg;
if($archive =~ /illegal000BLORT000illegal/) { $opts_failed = join("\n",$opts_failed,'Illegal variable(s) found in -archive argument'); }

# --- Validate output argument ---

unless($output) { $opts_failed = join("\n",$opts_failed,'Option -output must be supplied'); }
$output =~ s/\$(\w+)/exists $allowed_vars{$1} ? $allowed_vars{$1} : 'illegal000BLORT000illegal'/eg;
if($output =~ /illegal000BLORT000illegal/) { $opts_failed = join("\n",$opts_failed,'Illegal variable(s) found in -output argument'); }

# --- Validate period argument ---

my($start_year,$end_year);
unless($period)        { $opts_failed = join("\n",$opts_failed,'Option -period must be supplied'); }

if(not $period =~ /-/) {
	$opts_failed = join("\n",$opts_failed,'Option -period is invalid');
}
else {
	($start_year,$end_year) = split(/-/,$period);
	unless(looks_like_number($start_year) and int($start_year) == $start_year) { $opts_failed = join("\n",$opts_failed,"$start_year is an invalid start year in the -period argument"); }
	unless(looks_like_number($end_year) and int($end_year) == $end_year)       { $opts_failed = join("\n",$opts_failed,"$end_year is an invalid end year in the -period argument");     }
}

# --- Process failed options ---

if($opts_failed) {

        pod2usage( {
                -message => "$opts_failed\n",
                -exitval => 1,
                -verbose => 0,
        } );

}

# --- Switch start and end years if needed ---

if($start_year > $end_year) {
	print "WARNING: period start $start_year is later than period end $end_year - switching the order\n";
	my $temp    = $start_year;
	$start_year = $end_year;
	$end_year   = $temp;
}

# --- Build climo data structure ---

my @climdivs = qw(AL01 AL02 AL03 AL04 AL05 AL06 AL07 AL08 AK01 AK02 AK03 AK04 AK05 AK06 AK07 AK08 AK09 AK10 AK11 AK12 AK13 AZ01 AZ02 AZ03 AZ04 AZ05 AZ06 AZ07 AR01 AR02 AR03 AR04 AR05 AR06 AR07 AR08 AR09 CA01 CA02 CA03 CA04 CA05 CA06 CA07 CO01 CO02 CO03 CO04 CO05 CT01 CT02 CT03 DE01 DE02 FL01 FL02 FL03 FL04 FL05 FL06 FL07 GA01 GA02 GA03 GA04 GA05 GA06 GA07 GA08 GA09 HI01 HI02 HI03 HI04 HI05 HI06 ID01 ID02 ID03 ID04 ID05 ID06 ID07 ID08 ID09 ID10 IL01 IL02 IL03 IL04 IL05 IL06 IL07 IL08 IL09 IN01 IN02 IN03 IN04 IN05 IN06 IN07 IN08 IN09 IA01 IA02 IA03 IA04 IA05 IA06 IA07 IA08 IA09 KS01 KS02 KS03 KS04 KS05 KS06 KS07 KS08 KS09 KY01 KY02 KY03 KY04 LA01 LA02 LA03 LA04 LA05 LA06 LA07 LA08 LA09 ME01 ME02 ME03 MD01 MD02 MD03 MD04 MD05 MD06 MD07 MD08 MA01 MA02 MA03 MI01 MI02 MI03 MI04 MI05 MI06 MI07 MI08 MI09 MI10 MN01 MN02 MN03 MN04 MN05 MN06 MN07 MN08 MN09 MS01 MS02 MS03 MS04 MS05 MS06 MS07 MS08 MS09 MS10 MO01 MO02 MO03 MO04 MO05 MO06 MT01 MT02 MT03 MT04 MT05 MT06 MT07 NE01 NE02 NE03 NE05 NE06 NE07 NE08 NE09 NV01 NV02 NV03 NV04 NH01 NH02 NJ01 NJ02 NJ03 NM01 NM02 NM03 NM04 NM05 NM06 NM07 NM08 NY01 NY02 NY03 NY04 NY05 NY06 NY07 NY08 NY09 NY10 NC01 NC02 NC03 NC04 NC05 NC06 NC07 NC08 ND01 ND02 ND03 ND04 ND05 ND06 ND07 ND08 ND09 OH01 OH02 OH03 OH04 OH05 OH06 OH07 OH08 OH09 OH10 OK01 OK02 OK03 OK04 OK05 OK06 OK07 OK08 OK09 OR01 OR02 OR03 OR04 OR05 OR06 OR07 OR08 OR09 PA01 PA02 PA03 PA04 PA05 PA06 PA07 PA08 PA09 PA10 RI01 SC01 SC02 SC03 SC04 SC05 SC06 SC07 SD01 SD02 SD03 SD04 SD05 SD06 SD07 SD08 SD09 TN01 TN02 TN03 TN04 TX01 TX02 TX03 TX04 TX05 TX06 TX07 TX08 TX09 TX10 UT01 UT02 UT03 UT04 UT05 UT06 UT07 VT01 VT02 VT03 VA01 VA02 VA03 VA04 VA05 VA06 WA01 WA02 WA03 WA04 WA05 WA06 WA07 WA08 WA09 WA10 WV01 WV02 WV03 WV04 WV05 WV06 WI01 WI02 WI03 WI04 WI05 WI06 WI07 WI08 WI09 WY01 WY02 WY03 WY04 WY05 WY06 WY07 WY08 WY09 WY10);

my $daily_sums  = {};
my $daily_count = {};

{
	my $init_day   = Date::Manip::Date->new("20040101");
	my $init_end   = Date::Manip::Date->new("20050101");

	while($init_day->printf("%Y%m%d") lt $init_end->printf("%Y%m%d")) {
		$daily_sums->{$init_day->printf("%m%d")}  = {};
		$daily_count->{$init_day->printf("%m%d")} = {};
		my $delta = $init_day->new_delta();
		$delta->parse("+1 day");
		$init_day = $init_day->calc($delta);
	}

}

foreach my $key (keys %$daily_sums) {
	$daily_sums->{$key}  = {};
	$daily_count->{$key} = {};

	foreach my $climdiv (@climdivs) {
		$daily_sums->{$key}->{$climdiv}  = 0;
		$daily_count->{$key}->{$climdiv} = 0;
	}

}

# --- Loop through every day of the climatology period ---

print "Preparing climatology...\n\n";

my $day        = Date::Manip::Date->new($start_year."0101");
my $end_day    = Date::Manip::Date->new($end_year."1231");
my $status     = $day->printf("%Y") - 1;

while($day->printf("%Y%m%d") le $end_day->printf("%Y%m%d")) {
	my $year = $day->printf("%Y");
	my $mmdd = $day->printf("%m%d");

    if($year > $status) {
        print "Ingesting $year data\n";
        $status++;
    }

	# --- Obtain daily data from the archive ---

	my $archive_file = $day->printf($archive);
	next unless(-s $archive_file);
	open(ARCHIVE,'<',$archive_file) or die "Could not open $archive_file for reading - $! - exiting";
	my @contents = <ARCHIVE>; shift @contents; chomp @contents;
	#print "Data loaded from $archive_file\n";

	LINE: foreach my $line (@contents) {
		my($climdiv,$value) = split(',',$line);

		# --- Validate data ---

		next LINE unless($value >= 0 and looks_like_number($value));

		if(not exists $daily_sums->{$mmdd}->{$climdiv}) {
			warn "Unknown climdiv: $climdiv found in $archive_file\n";
			next LINE;
		}

		# --- Add contribution ---

		$daily_sums->{$mmdd}->{$climdiv} += $value;
		$daily_count->{$mmdd}->{$climdiv}++;

		# --- Use March 1 value for Feb 29 climo if not a leap year ---

		if($mmdd eq '0301') {

			if(not isleap($year)) {
				#print "Using March 1, $year data to compute Feb 29 climo\n";
				$daily_sums->{"0229"}->{$climdiv} += $value;
				$daily_count->{"0229"}->{$climdiv}++;
			}

		}

	}  # :LINE

	# --- Advance to next day ---

	my $delta = $day->new_delta();
	$delta->parse("+1 day");
	$day      = $day->calc($delta);
}

# --- Prepare and write out daily climatology ---

my $threshold = int(0.75*($end_year - $start_year + 1) + 0.5);
print "\nPreparing the raw climatology data...\n";

foreach my $mmdd (sort {$a <=> $b } keys %$daily_sums) {

	# --- Open output file ---

	my $output_day  = Date::Manip::Date->new($end_year.$mmdd);
	my $output_file = $output_day->printf($output);
    my($output_name,$output_path,$output_suffix) = fileparse($output_file, qr/\.[^.]*/);
    unless(-d $output_path) { mkpath($output_path) or die "Could not create directory $output_path - $! - exiting"; }
	open(OUTPUT,'>',$output_file) or die "Could not open $output_file for writing - $! - exiting";
	print OUTPUT join(',','Location',"$period Climatology\n");

	# --- Loop climdivs ---
	
	foreach my $climdiv (@climdivs) {

		# --- Compute and write out climatology data ---

		if($daily_count->{$mmdd}->{$climdiv} < $threshold) {
			warn "Less than $threshold years of data found for $climdiv on $mmdd - setting climo to -999\n";
			print OUTPUT "$climdiv,-999\n";
		}
		else {
			my $climval = int(0.5 + $daily_sums->{$mmdd}->{$climdiv}/$daily_count->{$mmdd}->{$climdiv});
			print OUTPUT "$climdiv,$climval\n";
		}
		
	}

	close(OUTPUT);
	print "$output_file written!\n";
}

sub isleap {
	my ($year) = @_;
	return 1 if (( $year % 400 ) == 0 ); # 400's are leap
	return 0 if (( $year % 100 ) == 0 ); # Other centuries are not
	return 1 if (( $year % 4 ) == 0 ); # All other 4's are leap
	return 0; # Everything else is not
}

exit 0;

