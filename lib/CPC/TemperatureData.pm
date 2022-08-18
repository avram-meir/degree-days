#!/usr/bin/env perl

package CPC::TemperatureData;

=pod

=head1 NAME

CPC::TemperatureData - Base class for packages designed to read CPC datasets into Perl data structures

=head1 SYNOPSIS

 use CPC::TemperatureData;

=head1 DESCRIPTION

=head1 REQUIREMENTS

=head1 METHODS

=head2 Constructor new

=head2 set_missing_val

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

my($pkg_name,$pkg_path,$pkg_suffix) = fileparse(__FILE__, qr/\.[^.]*/);
my $app_path     = "$pkg_path../..";

my %allowed_vars = (
    APP_PATH => "$app_path..",
    DATA_IN  => $ENV{DATA_IN},
    DATA_OUT => $ENV{DATA_OUT},
    FTP_IN   => $ENV{FTP_IN},
    FTP_OUT  => $ENV{FTP_OUT},
);

# --- Methods ---

sub new {
    my $class = shift;
    my $self  = {};
    $self->{TMAX_ARCHIVE} = undef;
    $self->{TMIN_ARCHIVE} = undef;
    $self->{MISSING}      = -9999.0;
    bless($self,$class);
    return $self;
}

sub set_missing_val {
    my $self         = shift;
    unless(@_) { carp "Argument required"; return 1; }
    my $missing_val  = shift;
    $self->{MISSING} = $missing_val;
    return 0;
}

sub set_max_archive {
    $self->{TMAX_ARCHIVE} = &_set_archive(@_);
    return 0;
}

sub set_min_archive {
    $self->{TMIN_ARCHIVE} = &_set_archive(@_);
    return 0;
}

sub _set_archive {
    my $self    = shift;
    confess "Archive argument required" unless @_;
    my $archive = shift;

    # --- Parse allowed vars in archive argument ---

    $archive =~ s/\$(\w+)/exists $allowed_vars{$1} ? $allowed_vars{$1} : 'illegal000BLORT000illegal'/eg;
    if($archive =~ /illegal000BLORT000illegal/) { confess "Illegal variable found in $archive"; }
    return $archive;
}

1;

