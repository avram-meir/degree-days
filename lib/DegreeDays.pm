#!/usr/bin/env perl

package DegreeDays;

=pod

=head1 NAME

DegreeDays - Degree days calculator for the degree-days application

=head1 SYNOPSIS

 use DegreeDays; # Make sure it's in PATH or make use of `use lib`
 
 my $dd       = CPC::DegreeDays->new();
 my $hdd      = $dd->heating($tmax,$tmin);
 $dd->set_base(50);
 $dd->set_ceil(86);
 my $gdd_corn = $dd->growing($tmax,$tmin);

=head1 DESCRIPTION

The DegreeDays package provides methods to compute cooling, growing, and heating degree days from daily maximum and minimum temperatures.

=head2 Cooling Degree Days

A cooling degree day (CDD) is an index demonstrated to reflect energy demand for cooling of homes and businesses. The index is computed by subtracting a base temperature set close to the ideal temperature for human comfort from the average of the maximum and minimum daily temperatures. No CDDs are accumulated if the daily average temperature equals or is less than the base temperature.

=head2 Growing Degree Days

A growing degree day (GDD) is an index demonstrated to reflect crop development maturity. The index is computed by subtracting a base temperature from the average of the maximum and minimum daily temperatures. Minimum temperatures less than the base temperature are set to the base, and maximum temperatures exceeding a ceiling threshold temperature (ceil) are set to the ceiling temperature, as extreme temperatures beyond this range result in no appreciable crop growth.

=head2 Heating Degree Days

A heating degree day (HDD) is an index demonstrated to reflect energy demand for heating of homes and businesses. The index is computed by subtracting the average of the maximum and minimum daily temperatures from a base temperature set close to the ideal temperature for human comfort. No HDDs are accumulated if the daily average temperature equals or exceeds the base temperature.

=head1 METHODS

=head2 Constructor new

 my $dd1 = DegreeDays->new();
 my $dd2 = DegreeDays->new($base,$ceil,$missing);

Returns a DegreeDays object (a reference blessed into the DegreeDays package). The base, ceiling, and missing values can be set upon creation of the object by passing them as arguments.

Default values are base = 65, ceil = 86, and missing_value = -999.

=head2 base

 $dd->base($base);
 $base = $dd->base();

Sets the base to the argument value, if supplied, and returns the base value.

=head2 ceil

 $dd->ceil($ceil);
 $ceil = $dd->ceil();

Sets the ceil to the argument value, if supplied, and returns the ceil value.

=head2 missing

 $dd->missing($missing);
 $missing = $dd->missing();

Sets the missing value to the argument, if supplied, and returns the missing value.

=head2 cooling

 my $cdd = $dd->cooling($tmax,$tmin);

Given a daily maximum and minimum temperature, return the cooling degree days.

=head2 growing

 my $gdd = $dd->growing($tmax,$tmin);

Given a daily maximum and minimum temperature, return the growing degree days.

=head2 heating

 $my $hdd = $dd->heating($tmax,$tmin);

Given a daily maximum and minimum temperature, return the heating degree days.

=head1 AUTHOR

Adam Allgood

=cut

use strict;
use warnings;
use Carp qw(carp croak cluck confess);
use Scalar::Util qw(blessed looks_like_number reftype);
use List::Util qw(first);

sub new {
    my $class        = shift;
    my $self         = {};
    $self->{BASE}    = 65;
    $self->{CEIL}    = 86;
    $self->{MISSING} = -999.0;

    if(@_) {
        my $base         = shift;
        confess "BASE argument is invalid" unless(looks_like_number($base));
        $self->{BASE}    = $base;
    }

    if(@_) {
        my $ceil         = shift;
        confess "CEIL argument is invalid" unless(looks_like_number($ceil));
        $self->{CEIL}    = $ceil;
    }

    if(@_) {
        my $missing      = shift;
        confess "MISSING argument is invalid" unless(looks_like_number($missing));
        $self->{MISSING} = $missing;
    }

    bless($self,$class);
    return $self;
}

sub base {
    my $self      = shift;

    if(@_) {
        my $base  = shift;
        if(looks_like_number($base)) { $self->{BASE} = $base; }
        else                         { carp "BASE value not changed - invalid argument"; }
    }

    if($self->{BASE} >= $self->{CEIL}) { carp "BASE >= CEIL - no growing degree days can be counted"; }
    return $self->{BASE};
}

sub ceil {
    my $self      = shift;
    
    if(@_) {
        my $ceil  = shift;
        if(looks_like_number($ceil)) { $self->{CEIL} = $ceil; }
        else                         { carp "CEIL value not changed - invalid argument"; }
    }
    
    if($self->{BASE} >= $self->{CEIL}) { carp "BASE >= CEIL - no growing degree days can be counted"; }
    return $self->{CEIL};
}

sub missing {
    my $self      = shift;
    
    if(@_) {
        my $miss         = shift;
        $self->{MISSING} = $miss;
    }
    
    return $self->{MISSING};
}

sub cooling {
    my $self = shift;
    confess "TMAX, TMIN arguments required" unless(@_ >= 2);
    my $tmax = shift;
    my $tmin = shift;
    if($tmax == $self->{MISSING} or $tmin == $self->{MISSING}) { return $self->{MISSING}; }
    my $cdd  = (($tmax + $tmin)/2) - $self->{BASE};
    if($cdd <= 0) { return 0;    }
    else          { return int($cdd+0.5); }
}

sub growing {
    my $self = shift;
    confess "TMAX, TMIN arguments required" unless(@_ >= 2);
    my $tmax = shift;
    my $tmin = shift;
    if($tmax == $self->{MISSING} or $tmin == $self->{MISSING}) { return $self->{MISSING}; }
    if($tmax > $self->{CEIL}) { $tmax = $self->{CEIL}; }
    if($tmin > $self->{CEIL}) { $tmin = $self->{CEIL}; }
    my $gdd  = (($tmax + $tmin)/2) - $self->{BASE};
    if($gdd <= 0) { return 0;    }
    else          { return int($gdd+0.5); }
}

sub heating {
    my $self = shift;
    confess "TMAX, TMIN arguments required" unless(@_ >= 2);
    my $tmax = shift;
    my $tmin = shift;
    if($tmax == $self->{MISSING} or $tmin == $self->{MISSING}) { return $self->{MISSING}; }
    my $hdd  = $self->{BASE} - (($tmax + $tmin)/2);
    if($hdd <= 0) { return 0;    }
    else          { return int($hdd+0.5); }
}

1;

