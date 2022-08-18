#!/usr/bin/env perl

package CPC::TemperatureData::CADB;

=pod

=head1 NAME

CPC::TemperatureData::CADB - Get temperature data from Climate Prediction Center Climate Assessment Database (CADB) archives

=head1 SYNOPSIS

 use Date::Manip;
 use CPC::TemperatureData::CADB;

=head1 DESCRIPTION

=head1 REQUIREMENTS

=over 3

=item * L<CPAN Date::Manip|https://metacpan.org/pod/Date::Manip>

=back

=head1 METHODS

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
use base qw(CPC::TemperatureData);

# --- CPAN packages ---

use Date::Manip;

my @cadb_vars = qw(stn_id stn_call city state country date lat lon elev tmax tmin report_p final_p p_flag num_6hr_p wxchars trace vp vp_def slp_6 slp_12 slp_18 slp_0 max_rh min_rh at wc wspd_3 wspd_6 wspd_9 wspd_12 wspd_15 wspd_18 wspd_21 wspd_24);

my %cadb_vars = map { $cadb_vars[$_] => $_ } 0..$#cadb_vars;

sub get_max_data {
    my $self = shift;
    confess "Date argument required" unless @_;
    my $date = shift;
    return &_get_data($date,$self->{TMAX_ARCHIVE},'tmax');
}

sub get_min_data {
    my $self = shift;
    confess "Date argument required" unless @_;
    my $date = shift;
    return &_get_data($date,$self->{TMIN_ARCHIVE},'tmin');
}

sub _get_data {
    my $date    = shift;
    my $archive = shift;
    my $var     = shift;
    my $missing = -99999;
    confess "No archive found (did you forget to set it using set_max_archive()?)" unless(defined $archive);
    confess "Date argument is not of type Date::Manip::Date" unless(blessed($day) and $day->isa("Date::Manip::Date"));
    my $dataset = $day->printf($archive);
    confess "Dataset $dataset not found" unless(-e $dataset);
    open(DATASET,'<',$dataset) or confess "Could not open $dataset for reading";
    my @data    = <DATASET>; shift @data; chomp @data;
    close(DATASET);
    my $data    = {};

    LINE: foreach my $line (@data) {
        my @vals     = split(',',$line);
        my $id       = $vals[0];
        my $val      = $vals[$cadb_vars{$var}];
        $data->{$id} = $val;
    }  # :LINE

    return($data);
}

1;

