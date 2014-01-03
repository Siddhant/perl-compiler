#! /usr/bin/env perl
# http://code.google.com/p/perl-compiler/issues/detail?id=148
# Opening Bareword Filehandles for Writing Does not work
use Test::More tests => 2;
use strict;
BEGIN {
  unshift @INC, 't';
  require "test.pl";
}

my $tmp = "ccode148i.tmp";
ctestok(1, "C,-O3", 'ccode148i', '$tmp="ccode148i.tmp";open(FH,">",$tmp);print FH "1\n";close FH;print "ok" if -s $tmp', "#148 bareword IO") and unlink $tmp;

ctestok(2, "C,-O3", 'ccode148i', <<'EOF', '#149 format with bareword IO');
format Comment =
ok
.

{
  local $~ = "Comment";
  write;
}
EOF
