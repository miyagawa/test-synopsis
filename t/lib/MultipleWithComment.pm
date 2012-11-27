package Test::Synopsis::__MultipleWithComment;

use strict;
use warnings;

use version; $VERSION = qw/0.0.1/;

1;

__END__

=head1 NAME

MultipleWithComment - for test


=head1 VERSION

This document describes Test::Synopsis::__MultipleWithComment


=head1 SYNOPSIS

    use strict;
    use warnings;

    print "Hello, test!";

=for test_synopsis_comment_begin

THIS IS COMMENT

=for test_synopsis_comment_end
=for test_synopsis_divide

    use strict;
    use warnings;

    print "Goodbye, test!";


=head1 DESCRIPTION

Foo Bar.
