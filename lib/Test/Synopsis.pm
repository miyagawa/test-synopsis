package Test::Synopsis;
use strict;
use 5.008_001;
our $VERSION = '0.01';

use base qw( Exporter );
our @EXPORT = qw( synopsis_ok all_synopsis_ok );

use ExtUtils::Manifest qw( maniread );

use Test::Builder;
my $Test = Test::Builder->new;

sub all_synopsis_ok {
    my $manifest = maniread();
    my @files = grep m!^lib/.*\.p(od|m)$!, keys %$manifest;
    synopsis_ok(@files);
}

sub synopsis_ok {
    my @modules = @_;
    $Test->plan(tests => 1 * @modules);

    for my $module (@modules) {
        my $code = extract_synopsis($module)
            or $Test->ok(1, "No SYNOPSIS code"), next;
        if (eval "sub { $code }") {
            $Test->ok(1, $module);
        } else {
            $Test->ok(0, $@);
        }
    }
}

sub extract_synopsis {
    my $file = shift;

    my $content = do {
        local $/;
        open my $fh, "<", $file or die "$file: $!";
        <$fh>;
    };

    return ($content =~ m/^=head1\s+SYNOPSIS(.+?)^=head1/ms)[0];
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Test::Synopsis -

=head1 SYNOPSIS

  # xt/synopsis.t (with Module::Install::AuthorTests)
  use Test::Synopsis;
  all_synopsis_ok("lib");

  # Or, run safe without Test::Synopsis
  use Test::More;
  eval "use Test::Synopsis";
  plan skip_all => "Test::Synopsis required for testing" if $@;
  all_synopsis_ok("lib");

=head1 DESCRIPTION

Test::Synopsis is an (author) test module to find .pm or .pod files
under your I<lib> directory and then make sure the example snippet
code in your I<SYNOPSIS> section passes the perl compile check.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

Goro Fuji blogged about the original idea at
L<http://d.hatena.ne.jp/gfx/20090224/1235449381> based on the testing
code taken from L<Test::Weaken>.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Test::Pod>, L<Test::UseAllModules>

=cut
