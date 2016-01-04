use Test::Builder::Tester tests => 1;
use Test::More;
use Test::Synopsis;

test_out('ok 1 - t/lib/TestMultipleChunks.pm (section 1)
not ok 2 - t/lib/TestMultipleChunks.pm (section 2)');

test_diag(q{  Failed test 't/lib/TestMultipleChunks.pm (section 2)'
#   at t/05-multi-chunks-clash.t line 13.
# Bareword "bob" not allowed while "strict subs" in use at t/lib/TestMultipleChunks.pm line 31.});

synopsis_ok("t/lib/TestMultipleChunks.pm");
test_test("synopsis with multiple chunks fails");
