package Test::Synopsis;

use strict;
use warnings;
use 5.008_001;

# VERSION

use base qw( Test::Builder::Module );
our @EXPORT = qw( synopsis_ok all_synopsis_ok );

use ExtUtils::Manifest qw( maniread );
my %ARGS;
 # = ( dump_all_code_on_error => 1 ); ### REMOVE THIS FOR PRODUCTION!!!
sub all_synopsis_ok {
    %ARGS = @_;

    my $manifest = maniread();
    my @files = grep m!^lib/.*\.p(od|m)$!, keys %$manifest
		or __PACKAGE__->builder->skip_all('No files in lib to test');

    __PACKAGE__->builder->no_plan();

    synopsis_ok(@files);

	__PACKAGE__->builder->done_testing();

}

sub synopsis_ok {
    my @modules = @_;

    for my $module (@modules) {
        my($codes, $line, @option) = extract_synopsis($module);
        unless (keys %$codes) {
            __PACKAGE__->builder->ok(1, "No SYNOPSIS code");
            next;
        }

        my $option = join(";", @option);

		for my $entry (sort { $a <=> $b } keys %$codes) {
			for my $file (sort keys %{$codes->{$entry}}) {
				my $number_sections = keys %{ $codes->{$entry}{$file} };
				for my $section (sort { $a <=> $b } keys %{ $codes->{$entry}{$file} }) {
					my $code = $codes->{$entry}{$file}{$section};
					my $test   = qq(#line $line "$module"\n$option; sub { $code });
					my $ok     = _compile($test);

					# See if the user is trying to skip this test using the =for block
					if ( !$ok and $@=~/^SKIP:.+BEGIN failed--compilation aborted/si ) {
						$@ =~ s/^SKIP:\s*//;
						$@ =~ s/\nBEGIN failed--compilation aborted at.+//s;
						__PACKAGE__->builder->skip($@, 1);
					}
					else {
						my $sectionname = $file;
						## Show section number if more than one section only
						if ($number_sections > 1) {
							$sectionname .= " (section $section)";
						}
						__PACKAGE__->builder->ok($ok, $sectionname);
						__PACKAGE__->builder->diag(
							$ARGS{dump_all_code_on_error}
								? "$@\nEVALED CODE:\n$test"
									: $@
							) unless $ok;
					}
				}
			}
		}
	}
}

my $sandbox = 0;
sub _compile {
    package
        Test::Synopsis::Sandbox;
    eval sprintf "package\nTest::Synopsis::Sandbox%d;\n%s",
      ++$sandbox, $_[0]; ## no critic
}

### WARNING: DESPITE THE NAME OF THIS SUBROUTINE (no underscore)
### IT'S A PRIVATE SUB; DO NOT USE IT DIRECTLY IN YOUR CODE!
sub extract_synopsis {
    my $file = shift;

    my $parser = Test::Synopsis::Parser->new;
    $parser->parse_from_file ($file);

	for my $entry (values %{$parser->{'test_synopsis_text'}}) {
		for my $sectionhash (values %{$entry}) {
			for my $section_text ( values %{$sectionhash}) {

				# don't want __END__ blocks in SYNOPSIS chopping our '}' in wrapper sub
				# same goes for __DATA__ and although we'll be sticking an extra '}'
				# into its contents; it shouldn't matter since the code shouldn't be
				# run anyways.
				$section_text =~ s/(?=(?:__END__|__DATA__)\s*$)/}\n/m;

				# trim indent whitespace to make HEREDOCs work properly
				# we'll assume the indent of the first line is the proper indent
				# to use for the whole block
				$section_text =~ s/(\A(\s+).+)/ (my $x = $1) =~ s{^$2}{}gm; $x /se;
			}
		}
	}

    # Correct the reported line number of the error, depending on what
    # =for options we were supplied with.
    my $options_lines = join '', @{ $parser->{'test_synopsis_options'} };
    $options_lines = $options_lines =~ tr/\n/\n/;

    return (
      $parser->{'test_synopsis_text'},
      ($parser->{'test_synopsis_linenum'} || 0) - ($options_lines || 0),
      @{ $parser->{'test_synopsis_options'} }
    );
}

package
  Test::Synopsis::Parser; # on new line to avoid indexing

### Parser patch by Kevin Ryde

use base 'Pod::Parser';
sub new {
    my $class = shift;
    my $self =  $class->SUPER::new(
      @_,
	  within_begin => '',
	  test_synopsis_options => [],
	  test_synopsis_section => {},
	  test_synopsis_sequence => 1,
	  test_synopsis_current_file => '',
	  test_synopsis_text => {},
    );
	return $self;
}

sub command {
    my $self = shift;
    my ($command, $text) = @_;

    if ($command eq 'for') {
        if ($text =~ /^test_synopsis\s+(.*)/s) {
            push @{$self->{'test_synopsis_options'}}, $1;
        }
    } elsif ($command eq 'begin') {
        $self->{'within_begin'} = $text;
    } elsif ($command eq 'end') {
        $self->{'within_begin'} = '';
    } elsif ($command eq 'pod') {
        # resuming pod, retain begin/end/synopsis state
    } else {
        # Synopsis is "=head1 SYNOPSIS" through to next command other than
        # the above "=for", "=begin", "=end", "=pod".  This means
        #     * "=for" directives for other programs are skipped
        #       (eg. HTML::Scrubber)
        #     * "=begin" to "=end" for other program are skipped
        #       (eg. Date::Simple)
        #     * "=cut" to "=pod" actual code is skipped (perhaps unlikely in
        #       practice)
        #
        # Could think about not stopping at "=head2" etc subsections of a
        # synopsis, but a synopsis with subsections usually means different
        # sample bits meant for different places and so probably won't
        # actually run.
        #
        $self->{'within_synopsis'}
          = ($command eq 'head1' && $text =~ /^SYNOPSIS\s*$/);
    }
    return '';
}

sub verbatim {
    my ( $self, $text, $linenum ) = @_;

	## If we are in a new file, adjust some things.
	if ($self->{_INFILE} ne $self->{test_synopsis_current_file}) {
		$self->{test_synopsis_current_file} = $self->{_INFILE};
		$self->{test_synopsis_section}{$self->{_INFILE}} = 0;
		$self->{test_synopsis_blocknumber} = 1;
		$self->{test_synopsis_oldblocknumber} = 0;
	}

	## If we are starting a new section, adjust some things.
	if ($self->{test_synopsis_blocknumber} != $self->{test_synopsis_oldblocknumber}) {
		$self->{test_synopsis_oldblocknumber} = $self->{test_synopsis_blocknumber};
		$self->{test_synopsis_section}{$self->{_INFILE}}++;
	}

    if ( $self->{'within_begin'} =~ /^test_synopsis\b/ ) {
        push @{$self->{'test_synopsis_options'}}, $text;

    } elsif ( $self->{'within_synopsis'} && ! $self->{'within_begin'} ) {
        $self->{'test_synopsis_linenum'} = $linenum; # first occurance
		$self->{test_synopsis_text}{
			## Maintain same order on checking as was read in:
			$self->{test_synopsis_sequence}
		}{
			## Current file we are parsing:
			$self->{_INFILE}
		}{
			## What section of the current file we are in:
			$self->{test_synopsis_section}{$self->{_INFILE}}
		} .= $text;
    }
    return '';
}
sub textblock {
    # ignore text paragraphs, only take "verbatim" blocks to be code
	my $self = shift;
	$self->{test_synopsis_blocknumber}++;
    return '';
}

1;
__END__

=encoding utf-8

=for Pod::Coverage extract_synopsis

=for stopwords Goro blogged Znet Zoffix DOHERTY Doherty
  KRYDE Ryde ZOFFIX Gr nauer Grünauer pm HEREDOC HEREDOCs

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
code with C<sub>) and doesn't actually run the code, B<UNLESS>
that code is a C<BEGIN {}> block or a C<use> statement.

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

=head1 SKIPPING TEST FROM INSIDE THE POD

You can use a C<BEGIN{}> block in the C<=for test_synopsis> to check for
specific conditions (e.g. if a module is present), and possibly skip
the test.

If you C<die()> inside the C<BEGIN{}> block and the die message begins
with sequence C<SKIP:> (note the colon at the end), the test
will be skipped for that document.

  =head1 SYNOPSIS

  =for test_synopsis BEGIN { die "SKIP: skip this pod, it's horrible!\n"; }

      $x; # undeclared variable, but we skipped the test!

  =end

=head1 EXPORTED SUBROUTINES

=head2 C<all_synopsis_ok>

  all_synopsis_ok();

  all_synopsis_ok( dump_all_code_on_error => 1 );

Checks the SYNOPSIS code in all your modules. Takes B<optional>
arguments as key/value pairs. Possible arguments are as follows:

=head3 C<dump_all_code_on_error>

  all_synopsis_ok( dump_all_code_on_error => 1 );

Takes true or false values as a value. B<Defaults to:> false. When
set to a true value, if an error is discovered in the SYNOPSIS code,
the test will dump the entire snippet of code it tried to test. Use this
if you want to copy/paste and play around with the code until the error
is fixed.

The dumped code will include any of the C<=for> code you specified (see
L<VARIABLE DECLARATIONS> section above) as well as a few internal bits
this test module uses to make SYNOPSIS code checking possible.

B<Note:> you will likely have to remove the C<#> and a space at the start
of each line (C<perl -pi -e 's/^#\s//;' TEMP_FILE_WITH_CODE>)

=head2 C<synopsis_ok>

  use Test::More tests => 1;
  use Test::Synopsis;
  synopsis_ok("t/lib/NoPod.pm");
  synopsis_ok(qw/Pod1.pm  Pod2.pm  Pod3.pm/);

Lets you test a single file. B<Note:> you must setup your own plan if
you use this subroutine (e.g. with C<< use Test::More tests => 1; >>).
B<Takes> a list of filenames for documents containing SYNOPSIS code to test.

=head1 CAVEATS

This module will not check code past the C<__END__> or
C<__DATA__> tokens, if one is
present in the SYNOPSIS code.

This module will actually execute C<use> statements and any code
you specify in the C<BEGIN {}> blocks in the SYNOPSIS.

If you're using HEREDOCs in your SYNOPSIS, you will need to place
the ending of the HEREDOC at the same indent as the
first line of the code of your SYNOPSIS.

Redefinition warnings can be turned off with

  =for test_synopsis
  no warnings 'redefine';

=head1 REPOSITORY

Fork this module on GitHub:
L<https://github.com/miyagawa/Test-Synopsis>

=head1 BUGS

To report bugs or request features, please use
L<https://github.com/miyagawa/Test-Synopsis/issues>

If you can't access GitHub, you can email your request
to C<bug-Test-Synopsis at rt.cpan.org>

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

Goro Fuji blogged about the original idea at
L<http://d.hatena.ne.jp/gfx/20090224/1235449381> based on the testing
code taken from L<Test::Weaken>.

=head1 MAINTAINER

Zoffix Znet <cpan (at) zoffix.com>

=head1 CONTRIBUTORS

=over 4

=item * Kevin Ryde (L<KRYDE|https://metacpan.org/author/KRYDE>)

=item * Marcel Grünauer (L<MARCEL|https://metacpan.org/author/MARCEL>)

=item * Mike Doherty (L<DOHERTY|https://metacpan.org/author/DOHERTY>)

=item * Patrice Clement (L<monsieurp|https://github.com/monsieurp>)

=item * Zoffix Znet (L<ZOFFIX|https://metacpan.org/author/ZOFFIX>)

=back

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 COPYRIGHT

This library is Copyright (c) Tatsuhiko Miyagawa

=head1 SEE ALSO

L<Test::Pod>, L<Test::UseAllModules>, L<Test::Inline>

=cut
