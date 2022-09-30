#!/usr/bin/env perl

package CPC::DailyTemperatures::CADB;

=pod

=head1 NAME

CPC::DailyTemperatures::CADB - Get daily temperature data from Climate Prediction Center Climate Assessment Database (CADB) CSV files

=head1 SYNOPSIS

 use CPC::DailyTemperatures::CADB;

=head1 DESCRIPTION

=head1 REQUIREMENTS

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

my @cadb_vars = qw(stn_id stn_call city state country date lat lon elev tmax tmin report_p final_p p_flag num_6hr_p wxchars trace vp vp_def slp_6 slp_12 slp_18 slp_0 max_rh min_rh at wc wspd_3 wspd_6 wspd_9 wspd_12 wspd_15 wspd_18 wspd_21 wspd_24);

my %cadb_vars = map { $cadb_vars[$_] => $_ } 0..$#cadb_vars;

sub new {
    my $class = shift;
    my $self  = {};
    $self->{LOCATIONS} = [];
    $self->{MISSING}   = -999;
    bless($self,$class);
    return $self;
}

sub set_locations {
    my $self  = shift;

    unless(@_) {
        carp "No locations provided";
        return undef;
    }

    my @locations = @_;
    $self->{LOCATIONS} = \@locations;
    return 1;
}

sub set_missing {
    my $self = shift;

    unless(@_) {
        carp "No missing value provided";
        return $self->{MISSING};
    }

    $self->{MISSING} = shift;
    return 1;
}

sub get_locations {
    my $self = shift;
    unless(@{$self->{LOCATIONS}}) { carp "No locations are set"; }
    return $self->{LOCATIONS};
}

sub get_missing {
    my $self = shift;
    return $self->{MISSING};
}

sub get_data {
    my $self        = shift;
    my $missing_in  = $self->{MISSING};
    my $missing_out = -999;
    my $data        = {};

    unless(@_) {
        carp "No dataset provided";
        return undef;
    }

    my $data_file = shift;

    unless(-s $data_file) {
        carp "Dataset $data_file not found";
        return undef;
    }

    my $field = undef;

    if(@_) {
        $field = shift;

        unless(exists $cadb_vars{$field}) {
            carp "$field is not a known CADB variable - returning everything";
            undef $field;
        }

    }

    unless(open(INPUT,'<',$data_file)) {
        carp "Could not open $data_file for reading - $!";
        return undef;
    }

    my @contents = <INPUT>; shift @contents; chomp @contents;
    close(INPUT);

    LINE: foreach my $line (@contents) {
        my @vals = split(',',$line);
        my $id   = shift @vals;
        my $val  = undef;

        if(defined $field) {
            $val = $vals[$cadb_vars{$field} - 1];
            if(not looks_like_number($val)) { $val = $missing_out; }
            if($val == $missing_in)         { $val = $missing_out; }
        }
        else {
            $val = {};

            foreach my $f (@cadb_vars) {
                $val->{$f} = shift @vals;
                if(not looks_like_number($val->{$f})) { $val->{$f} = $missing_out; }
                if($val->{$f} == $missing_in)         { $val->{$f} = $missing_out; }
            }

        }

        $data->{$id} = $val;
    }  # :LINE

    if(not @{$self->{LOCATIONS}}) { return $data; }
    else {
        my %locations = map { $_ => 1 } @{$self->{LOCATIONS}};
        foreach my $id (keys %{$data}) { unless(exists($locations{$id})) { delete($data->{$id}); } }
        foreach my $id (@{$self->{LOCATIONS}}) { unless(exists($data->{$id})) { $data->{$id} = $missing_out; } }
        return $data;
    }

}

1;

