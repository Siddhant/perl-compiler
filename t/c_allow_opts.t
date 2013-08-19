#! /usr/bin/env perl
# test -DALLOW_PERL_OPTIONS
BEGIN {
  print "1..4\n";
}
use strict;

my $pl = "ccode00.pl";
my $d = <DATA>;
open F, ">", $pl;
print F $d;
close F;
my $exe = $^O eq 'MSWin32' ? 'a' : './a';
my $C = $] > 5.007 ? "-qq,C" : "C";
my $X = $^X =~ m/\s/ ? qq{"$^X"} : $^X;
system "$X -Mblib -MO=$C,-O3,-oa.c $pl";
# see if the ldopts libs are picked up correctly. This really depends on your perl package.
system "$X -Mblib script/cc_harness -q -DALLOW_PERL_OPTIONS a.c -o a";
unless (-e 'a' or -e 'a.out') {
  print "ok 1 #skip wrong ldopts for cc_harness. Try -Bdynamic or -Bstatic or fix your ldopts.\n";
  print "ok 2 #skip ditto\n";
  exit;
}
my $ok = `$exe -s -abc=2 -def 2>&1`;
chomp $ok;
print "not " if $ok !~ /Unrecognized switch: -bc=2/;
print "ok 1\n";

$ok = `$exe -s -- -abc=2 -def`;
chomp $ok;
my $exp = "21-";
print $ok ne $exp ? "not " : "", "ok 2",
  $ok ne $exp ? "# want: $exp got: $ok\n" : "\n";

system "$X -Mblib script/cc_harness -q a.c -o a";
$ok = `$exe -s -- -abc=2 -def`;
$exp = "---";
chomp $ok;
print $ok ne $exp ? "not " : "", "ok 3", $ok ne $exp ? " # want: $exp got: $ok\n" : "\n";
$ok = `$exe -s -abc=2 -def 2>&1`;
chomp $ok;
print $ok ne $exp ? "not " : "", "ok 4", $ok ne $exp ? " # want: $exp got: $ok\n" : "\n";

END {
  unlink($exe, "a.out", "a.c", $pl);
}

__DATA__
for (qw/abc def ghi/) {print defined $$_ ? $$_ : q(-)};
