use Test::Synopsis;

BEGIN {
    use Test::More tests => 2;
    use Test::Synopsis;
}

synopsis_ok('t/lib/MultipleWithComment.pm');
