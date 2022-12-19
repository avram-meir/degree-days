#!/usr/bin/env perl

package CPC::DegreeDays::Archive;

=pod

=head1 NAME

CPC::DegreeDays::Archive - Access CPC's daily degree days archives

=head1 SYNOPSIS

 use Date::Manip;
 use CPC::DegreeDays::Archive;
 
 my $heating = CPC::DegreeDays::Archive->new({
    DATA      => "/path/to/degree_days/archive/%Y/hdd_%Y%m%d.txt",
    CLIM      => "/path/to/degree_days/climo/hdd_%m%d.txt",
    LOCATIONS => \@locations,
 });

 my $hdd      = $heating->get_data($day);
 my $hdd      = $heating->get_clim($day);

=head1 DESCRIPTION

=head1 REQUIREMENTS

=head1 METHODS

=head2 new

=head2 get_data

=head2 get_clim

=head1 AUTHOR

Adam Allgood

This documentation was last updated on: 19DEC2022

=cut

use strict;
use warnings;
use Carp qw(carp croak cluck confess);
use Scalar::Util qw(blessed looks_like_number reftype);
use File::Basename qw(fileparse basename);
use Date::Manip;

my $package  = __FILE__;
my $app_path = $package =~ s/\/lib\/CPC\/DegreeDays\/Archive.pm//r;

sub new {
    my $class     = shift;
    my $self      = {};
    confess "Argument required" unless(@_);
    my $args      = shift;
    confess "Argument must be a hash" unless(reftype $args eq reftype {});
    confess "DATA not found in hashref arg" unless(exists $args->{DATA});
    confess "CLIM not found in hashref arg" unless(exists $args->{CLIM});
    confess "LOCATIONS not found in hashref arg" unless(exists $args->{LOCATIONS});

    my %allowed_vars = (
        APP_PATH => $app_path,
        DATA_IN  => $ENV{DATA_IN},
        DATA_OUT => $ENV{DATA_OUT},
        FTP_IN   => $ENV{FTP_IN},
    );

    my $data_parsed    = $args->{DATA};
    my $clim_parsed    = $args->{CLIM};
    $data_parsed       =~ s/\$(\w+)/exists $allowed_vars{$1} ? $allowed_vars{$1} : 'illegal000BLORT000illegal'/eg;
    if($data_parsed    =~ /illegal000BLORT000illegal/) { confess "Unallowed variable found in DATA arg"; }
    $clim_parsed       =~ s/\$(\w+)/exists $allowed_vars{$1} ? $allowed_vars{$1} : 'illegal000BLORT000illegal'/eg;
    if($data_parsed    =~ /illegal000BLORT000illegal/) { confess "Unallowed variable found in CLIM arg"; }
    $self->{DATA}      = $data_parsed;
    $self->{CLIM}      = $clim_parsed;
    $self->{LOCATIONS} = $args->{LOCATIONS};
    bless($self,$class);
    return $self;
}

sub get_data {
    my $self = shift;
    return &_get_vals($self,$self->{DATA},@_);
}

sub get_clim {
    my $self = shift;
    return &_get_vals($self,$self->{CLIM},@_);
}

sub _get_vals {
    my $self       = shift;
    my $input      = shift;
    confess "Argument required" unless(@_);
    my $day        = shift;
    confess "Argument must be a Date::Config object" unless(ref $day eq 'Date::Manip');
    my $input_file = $day->printf($input);
    my $values     = {};

    foreach my $loc (@$self->{LOCATIONS}) {
        $values->{$loc} = -999;
    }

    unless(open(INPUT,'<',$input_file)) {
        cluck "Could not open $input_file for reading - $!"
        return $values;
    }

    my @values = <INPUT>; shift @values; chomp @values;
    close(INPUT);

    LINE: foreach my $line (@values) {
        my($loc,$value) = split(',',$line);
        next LINE unless(exists $values->{$loc});
        next LINE unless(looks_like_number($value));
        next LINE unless($value >= 0);
        $values->{$loc} = $value;
    }  # :LINE

    return $values;
}

1;

