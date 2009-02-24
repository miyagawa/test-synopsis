use inc::Module::Install;
name 'Test-Synopsis';
all_from 'lib/Test/Synopsis.pm';

requires 'Test::Builder';
use_test_base;
auto_include_deps;
author_tests('xt');
WriteAll;
