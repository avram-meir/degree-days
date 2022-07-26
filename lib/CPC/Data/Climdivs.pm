#!/usr/bin/env perl

package CPC::Data::Climdivs;

=pod

=head1 NAME

CPC::Archive::Climdivs - Get data from Climate Prediction Center climate divisions archives

=head1 SYNOPSIS

 use Date::Manip;
 use CPC::Archive::Climdivs;

=head1 DESCRIPTION

=head1 REQUIREMENTS

=over 3

=item * L<CPAN Date::Manip|https://metacpan.org/pod/Date::Manip>

=back

=head1 METHODS

=head2 new

=head2 set_archive

=head2 get_data

=head1 AUTHOR

Adam Allgood

=cut

use strict;
use warnings;
use Carp qw(carp croak cluck confess);
use Scalar::Util qw(blessed looks_like_number reftype);
use File::Basename qw(fileparse);
use List::Util qw(first);

# --- Package data ---

my($pkg_name,$pkg_path,$pkg_suffix,$lib_path);

BEGIN {
    ($pkg_name,$pkg_path,$pkg_suffix) = fileparse(__FILE__, qr/\.[^.]*/);
    $lib_path    = "$pkg_path../../";
}

# --- Inheritance ---

use local::lib $lib_path;
use base qw(CPC::Archive);

# --- CPAN packages ---

use Date::Manip;

my @climdivs = qw(AL01 AL02 AL03 AL04 AL05 AL06 AL07 AL08 AK01 AK02 AK03 AK04 AK05 AK06 AK07 AK08 AK09 AK10 AK11 AK12 AK13 AZ01 AZ02 AZ03 AZ04 AZ05 AZ06 AZ07 AR01 AR02 AR03 AR04 AR05 AR06 AR07 AR08 AR09 CA01 CA02 CA03 CA04 CA05 CA06 CA07 CO01 CO02 CO03 CO04 CO05 CT01 CT02 CT03 DE01 DE02 FL01 FL02 FL03 FL04 FL05 FL06 FL07 GA01 GA02 GA03 GA04 GA05 GA06 GA07 GA08 GA09 HI01 HI02 HI03 HI04 HI05 HI06 ID01 ID02 ID03 ID04 ID05 ID06 ID07 ID08 ID09 ID10 IL01 IL02 IL03 IL04 IL05 IL06 IL07 IL08 IL09 IN01 IN02 IN03 IN04 IN05 IN06 IN07 IN08 IN09 IA01 IA02 IA03 IA04 IA05 IA06 IA07 IA08 IA09 KS01 KS02 KS03 KS04 KS05 KS06 KS07 KS08 KS09 KY01 KY02 KY03 KY04 LA01 LA02 LA03 LA04 LA05 LA06 LA07 LA08 LA09 ME01 ME02 ME03 MD01 MD02 MD03 MD04 MD05 MD06 MD07 MD08 MA01 MA02 MA03 MI01 MI02 MI03 MI04 MI05 MI06 MI07 MI08 MI09 MI10 MN01 MN02 MN03 MN04 MN05 MN06 MN07 MN08 MN09 MS01 MS02 MS03 MS04 MS05 MS06 MS07 MS08 MS09 MS10 MO01 MO02 MO03 MO04 MO05 MO06 MT01 MT02 MT03 MT04 MT05 MT06 MT07 NE01 NE02 NE03 NE05 NE06 NE07 NE08 NE09 NV01 NV02 NV03 NV04 NH01 NH02 NJ01 NJ02 NJ03 NM01 NM02 NM03 NM04 NM05 NM06 NM07 NM08 NY01 NY02 NY03 NY04 NY05 NY06 NY07 NY08 NY09 NY10 NC01 NC02 NC03 NC04 NC05 NC06 NC07 NC08 ND01 ND02 ND03 ND04 ND05 ND06 ND07 ND08 ND09 OH01 OH02 OH03 OH04 OH05 OH06 OH07 OH08 OH09 OH10 OK01 OK02 OK03 OK04 OK05 OK06 OK07 OK08 OK09 OR01 OR02 OR03 OR04 OR05 OR06 OR07 OR08 OR09 PA01 PA02 PA03 PA04 PA05 PA06 PA07 PA08 PA09 PA10 RI01 SC01 SC02 SC03 SC04 SC05 SC06 SC07 SD01 SD02 SD03 SD04 SD05 SD06 SD07 SD08 SD09 TN01 TN02 TN03 TN04 TX01 TX02 TX03 TX04 TX05 TX06 TX07 TX08 TX09 TX10 UT01 UT02 UT03 UT04 UT05 UT06 UT07 VT01 VT02 VT03 VA01 VA02 VA03 VA04 VA05 VA06 WA01 WA02 WA03 WA04 WA05 WA06 WA07 WA08 WA09 WA10 WV01 WV02 WV03 WV04 WV05 WV06 WI01 WI02 WI03 WI04 WI05 WI06 WI07 WI08 WI09 WY01 WY02 WY03 WY04 WY05 WY06 WY07 WY08 WY09 WY10);

my %climdivs = map { $_ => 1 } @climdivs;

# --- Override get_data method ---

sub get_data {
	my $self         = shift;
	confess "Date argument required" unless @_;
	$self->{MISSING} = -9999.;
	my $day          = shift;
	confess "Date argument is not of type Date::Manip::Date" unless(blessed($day) and $day->isa("Date::Manip::Date"));
	confess "No archive found" unless(defined $self->{ARCHIVE});
	my $archive_file = $day->printf($self->{ARCHIVE});
	confess "Archive file $archive_file not found" unless(-e $archive_file);
	open(ARCHIVE,'<',$archive_file) or confess "Could not open $archive_file for reading";
	my @data         = <ARCHIVE>; shift @data; chomp @data;
	close(ARCHIVE);
	my $data         = {};

	LINE: foreach my $line (@data) {
		my($key,$value) = split(/\|/,$line);
		next LINE unless(exists($climdivs{$key}));
		$data->{$key}   = $value;
	}

	foreach my $climdiv (@climdivs) {
		carp $day->printf("WARNING: No data found for climate division $climdiv on %Y/%m/%d") unless($data->{$climdiv});
	}

	return($data);
}

1;

