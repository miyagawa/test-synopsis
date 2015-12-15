#!/usr/bin/env perl
use warnings;
use strict;

use feature 'say';

use Test::Synopsis;
use Cwd;

my $file = cwd() . '/' . $0;
say $file;

synopsis_ok($file);

__END__

=head1 NAME

test.pl - Script to test a new feature.

=head1 SYNOPSIS

    my @array = (1..10);

    for my $i (@array) {
        if ($i eq 10) {
            print "GREAT!\n";
        }
    }

=head1 DESCRIPTION

This is completely useless.

=head1 AUTHOR

Me and myself.

=head1 SYNOPSIS

    my %hash = (
        first => 1,
        second => 2 
    );

    while (my ($k, $v) = each %hash) {
        print "$k => $v\n";
    }

=head1 DESCRIPTION

Another synopsis!
