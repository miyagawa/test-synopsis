use Test::Synopsis;

BEGIN {
    use Test::More tests => 1;
    use Test::Synopsis;
}

synopsis_ok('t/lib/Comment.pm');
