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

my @cadb_vars = qw(stn_id stn_call city state country date lat lon elev tmax tmin report_p final_p p_flag num_6hr_p wxchars trace vp vp_def slp_6 slp_12 slp_18 slp_0 max_rh min_rh at wc wspd_3 wspd_6 wspd_9 wspd_12 wspd_15 wspd_18 wspd_21 wspd_24);

my %cadb_vars = %hash = map { $cadb_vars[$_] => $_ } 0..$#cadb_vars;

# --- Override get_data method ---

sub get_data {
    my $self         = shift;
    confess "Date argument required" unless @_;
    $self->{MISSING} = -99999;
    my $day          = shift;
    confess "Date argument is not of type Date::Manip::Date" unless(blessed($day) and $day->isa("Date::Manip::Date"));
    confess "Variable argument required" unless @_;
    my $var          = shift;
    confess "Variable $var is not an existing CADB variable" unless(exists $cadb_var{$var});
    my $archive_file = $day->printf($self->{ARCHIVE});
    confess "Archive file $archive_file not found" unless(-e $archive_file);
    open(ARCHIVE,'<',$archive_file) or confess "Could not open $archive_file for reading";
    my @data         = <ARCHIVE>; shift @data; chomp @data;
    close(ARCHIVE);
    my $data         = {};

    if(defined $self->{STATIONLIST}) {
        foreach my $station (keys %{$self-{STATIONLIST}}) { $data->{$station} = $self->{MISSING}; }
    }

    LINE: foreach my $line (@data) {
        my @cadb_vals     = split(',',$line);
        my $cadb_id       = $cadb_vals[0];
        my $cadb_val      = $cadb_vals[$cadb_vars{$var}];

        if(defined $self->{STATIONLIST}) {
            if(exists $data->{$cadb_id}) { $data->{$cadb_id} = $cadb_val; }
        }
        else {
            $data->{$cadb_id} = $cadb_val;
        }

    }  # :LINE

    return $data;
}

# --- Package specific method ---

sub set_station_list {
    my $self         = shift;
    confess "Station list argument(s) required" unless @_;
    my @station_list = @_;
    my %station_list = map { $_ => 1 } @station_list;
    $self->{STATIONLIST} = ${%station_list};
    return 0;
}

1;

