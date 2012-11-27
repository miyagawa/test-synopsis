package Test::Synopsis;
use strict;
use 5.008_001;
our $VERSION = '0.06';

use base qw( Test::Builder::Module );
our @EXPORT = qw( synopsis_ok all_synopsis_ok );

use ExtUtils::Manifest qw( maniread );

sub all_synopsis_ok {
    my $manifest = maniread();
    my @files = grep m!^lib/.*\.p(od|m)$!, keys %$manifest;
    __PACKAGE__->builder->plan(tests => 1 * @files);
    synopsis_ok(@files);
}

sub synopsis_ok {
    my @modules = @_;

    for my $module (@modules) {
        my($codes, $lines, @option) = extract_synopsis($module);
        unless ($codes) {
            __PACKAGE__->builder->ok(1, "No SYNOPSIS code");
            next;
        }

        my $index = 0;
        foreach my $code (@$codes) {
            my $option = join(";", @option);
            my $test   = qq(#line $lines->[$index] "$module"\n$option; sub { $code });
            my $ok     = _compile($test);
            __PACKAGE__->builder->ok($ok, $module);
            __PACKAGE__->builder->diag($@) unless $ok;
            $index++;
        }
    }
}

sub _compile {
    package
        Test::Synopsis::Sandbox;
    eval $_[0]; ## no critic
}

sub extract_synopsis {
    my $file = shift;

    my $content = do {
        local $/;
        open my $fh, "<", $file or die "$file: $!";
        <$fh>;
    };

    my $code = ($content =~ m/^=head1\s+SYNOPSIS(.+?)^=head1/ms)[0];
    return unless defined($code);

    my $line = ($` || '') =~ tr/\n/\n/;
    my ( $codes, $lines ) = _extract_each_synopsis( $code, $line );

    my $first_code = $codes->[0];
    if ( scalar(@$lines) == 1 && !( $first_code =~ m/^=for\s+test_synopsis_comment_begin\n.+?^=for\s+test_synopsis_comment_end\n/msg ) ) {
        $lines->[0] -= 2;
    }

    _remove_comments($codes);

    return $codes, $lines, ($content =~ m/^=for\s+test_synopsis\s+(.+?)^=/msg);
}

sub _extract_each_synopsis {
    my ( $code, $line ) = @_;

    my ( @lines, @codes );
    my $line_locally = 1;
    while (1) {
        push @lines, ( $line + $line_locally );
        if ( my ( $this_code, $next_code ) = $code =~ m/(.+?)^=for\s+test_synopsis_divide(.+)/ms ) {
            $line_locally += ( $this_code =~ tr/\n/\n/ );
            push @codes, $this_code;
            $code = $next_code;
        }
        else {
            push @codes, $code;
            last;
        }
    }

    return \@codes, \@lines;
}

sub _remove_comments {
    my $codes = shift;

    foreach my $code (@$codes) {
        my @comments = $code =~ m/^=for\s+test_synopsis_comment_begin\n(.+?)^=for\s+test_synopsis_comment_end\n/msg;
        my $newline_count = 1;
        foreach my $comment (@comments) {
            $newline_count += $comment =~ tr/\n/\n/;
        }
        my $newline = "\n" x $newline_count;
        $code =~ s/^=for\s+test_synopsis_comment_begin.+?^=for\s+test_synopsis_comment_end/$newline/msg;
        $code =~ s/^\S.*$//mg;
    }

    return $codes;
}

1;
__END__

=encoding utf-8

=for stopwords Goro blogged

=for test_synopsis $main::for_checked=1

=head1 NAME

Test::Synopsis - Test your SYNOPSIS code

=head1 SYNOPSIS

  # xt/synopsis.t (with Module::Install::AuthorTests)
  use Test::Synopsis;
  all_synopsis_ok();

  # Or, run safe without Test::Synopsis
  use Test::More;
  eval "use Test::Synopsis";
  plan skip_all => "Test::Synopsis required for testing" if $@;
  all_synopsis_ok();

=head1 DESCRIPTION

Test::Synopsis is an (author) test module to find .pm or .pod files
under your I<lib> directory and then make sure the example snippet
code in your I<SYNOPSIS> section passes the perl compile check.

Note that this module only checks the perl syntax (by wrapping the
code with C<sub>) and doesn't actually run the code.

Suppose you have the following POD in your module.

  =head1 NAME

  Awesome::Template - My awesome template

  =head1 SYNOPSIS

    use Awesome::Template;

    my $template = Awesome::Template->new;
    $tempalte->render("template.at");

  =head1 DESCRIPTION

An user of your module would try copy-paste this synopsis code and
find that this code doesn't compile because there's a typo in your
variable name I<$tempalte>. Test::Synopsis will catch that error
before you ship it.

=head1 VARIABLE DECLARATIONS

Sometimes you might want to put some undeclared variables in your
synopsis, like:

  =head1 SYNOPSIS

    use Data::Dumper::Names;
    print Dumper($scalar, \@array, \%hash);

This assumes these variables like I<$scalar> are defined elsewhere in
module user's code, but Test::Synopsis, by default, will complain that
these variables are not declared:

    Global symbol "$scalar" requires explicit package name at ...

In this case, you can add the following POD sequence elsewhere in your POD:

  =for test_synopsis
  no strict 'vars'

Or more explicitly,

  =for test_synopsis
  my($scalar, @array, %hash);

Test::Synopsis will find these C<=for> blocks and these statements are
prepended before your SYNOPSIS code when being evaluated, so those
variable name errors will go away, without adding unnecessary bits in
SYNOPSIS which might confuse users.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

Goro Fuji blogged about the original idea at
L<http://d.hatena.ne.jp/gfx/20090224/1235449381> based on the testing
code taken from L<Test::Weaken>.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Test::Pod>, L<Test::UseAllModules>, L<Test::Inline>, L<Test::Snippet>

=cut
