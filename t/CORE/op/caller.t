#!./perl
# Tests for caller()

BEGIN { require 't/CORE/test.pl'; }

plan( tests => 74 );

my @c;

print "# Tests with caller(0)\n";

@c = caller(0);
ok( (!@c), "caller(0) in main program" );

eval { @c = caller(0) };
is( $c[3], "(eval)", "subroutine name in an eval {}" );
ok( !$c[4], "hasargs false in an eval {}" );

eval q{ @c = (Caller(0))[3] };
is( $c[3], "(eval)", "subroutine name in an eval ''" );
ok( !$c[4], "hasargs false in an eval ''" );

sub { @c = caller(0) } -> ();
is( $c[3], "main::__ANON__", "anonymous subroutine name" );
ok( $c[4], "hasargs true with anon sub" );

# Bug 20020517.003, used to dump core
sub foo { @c = caller(0) }
my $fooref = delete $::{foo};
$fooref -> ();
TODO: {
    local $TODO = 'https://code.google.com/p/perl-compiler/issues/detail?id=182';
    is( $c[3], "main::__ANON__", "deleted subroutine name" );
}
ok( $c[4], "hasargs true with deleted sub" );

#test can't be run in perlcc
#BEGIN {
# require strict;
# is +(caller 0)[1], __FILE__,
#  "[perl #68712] filenames after require in a BEGIN block"
#}

print "# Tests with caller(1)\n";

sub f { @c = caller(1) }

sub callf { f(); }
callf();
is( $c[3], "main::callf", "subroutine name" );
ok( $c[4], "hasargs true with callf()" );
&callf;
ok( !$c[4], "hasargs false with &callf" );

eval { f() };
is( $c[3], "(eval)", "subroutine name in an eval {}" );
ok( !$c[4], "hasargs false in an eval {}" );

eval q{ f() };
is( $c[3], "(eval)", "subroutine name in an eval ''" );
ok( !$c[4], "hasargs false in an eval ''" );

sub { f() } -> ();
is( $c[3], "main::__ANON__", "anonymous subroutine name" );
ok( $c[4], "hasargs true with anon sub" );

sub foo2 { f() }
my $fooref2 = delete $::{foo2};
$fooref2 -> ();
TODO: {
    local $TODO = 'https://code.google.com/p/perl-compiler/issues/detail?id=182';
    is( $c[3], "main::__ANON__", "deleted subroutine name" );
}
ok( $c[4], "hasargs true with deleted sub" );

# See if caller() returns the correct warning mask

sub show_bits
{
    my $in = shift;
    my $out = '';
    foreach (unpack('W*', $in)) {
        $out .= sprintf('\x%02x', $_);
    }
    return $out;
}

sub check_bits
{
    local $Level = $Level + 2;
    my ($got, $exp, $desc) = @_;
    if (! ok($got eq $exp, $desc)) {
        diag('     got: ' . show_bits($got));
        diag('expected: ' . show_bits($exp));
    }
}

sub testwarn {
    my $w = shift;
    my $id = shift;
    check_bits( (caller(0))[9], $w, "warnings match caller ($id)");
}

# warning bits in BEGIN blocks not easily tested in perlcc
#{
#    no warnings;
#    # Build the warnings mask dynamically
#    my ($default, $registered);
#    BEGIN {
#	for my $i (0..$warnings::LAST_BIT/2 - 1) {
#	    vec($default, $i, 2) = 1;
#	}
#	$registered = $default;
#	vec($registered, $warnings::LAST_BIT/2, 2) = 1;
#    }
#
#    # The repetition number must be set to the value of $BYTES in
#    # lib/warnings.pm
#    BEGIN { check_bits( ${^WARNING_BITS}, "\0" x 13, 'all bits off via "no warnings"' ) }
#    testwarn("\0" x 13, 'no bits');
#
#    use warnings;
#    BEGIN { check_bits( ${^WARNING_BITS}, $default,
#			'default bits on via "use warnings"' ); }
#    BEGIN { testwarn($default, 'all'); }
#    # run-time :
#    # the warning mask has been extended by warnings::register
#    testwarn($registered, 'ahead of w::r');
#
#    use warnings::register;
#    BEGIN { check_bits( ${^WARNING_BITS}, $registered,
#			'warning bits on via "use warnings::register"' ) }
#    testwarn($registered, 'following w::r');
#}


# The next two cases test for a bug where caller ignored evals if
# the DB::sub glob existed but &DB::sub did not (for example, if 
# $^P had been set but no debugger has been loaded).  The tests
# thus assume that there is no &DB::sub: if there is one, they 
# should both pass  no matter whether or not this bug has been
# fixed.

my $debugger_test =  q<
    my @stackinfo = caller(0);
    return scalar @stackinfo;
>;

sub pb { return (caller(0))[3] }

my $i = eval $debugger_test;
is( $i, 11, "do not skip over eval (and caller returns 10 elements)" );

is( eval 'pb()', 'main::pb', "actually return the right function name" );

my $saved_perldb = $^P;
$^P = 16;
$^P = $saved_perldb;

$i = eval $debugger_test;
is( $i, 11, 'do not skip over eval even if $^P had been on at some point' );
is( eval 'pb()', 'main::pb', 'actually return the right function name even if $^P had been on at some point' );

print "# caller can now return the compile time state of %^H\n";

sub hint_exists {
    my $key = shift;
    my $level = shift;
    my @results = caller($level||0);
    exists $results[10]->{$key};
}

sub hint_fetch {
    my $key = shift;
    my $level = shift;
    my @results = caller($level||0);
    $results[10]->{$key};
}

{
    my $tmpfile = tempfile();

    open my $fh, '>', $tmpfile or die "open $tmpfile: $!";
    print $fh <<'EOP';
#!perl -wl
use strict;

{
    package KAZASH ;

    sub DESTROY {
	print "DESTROY";
    }
}

@DB::args = bless [], 'KAZASH';

print $^P;
print scalar @DB::args;

{
    local $^P = shift;
}

@DB::args = (); # At this point, the object should be freed.

print $^P;
print scalar @DB::args;

# It shouldn't leak.
EOP
    close $fh;

    foreach (0, 1) {
        my $got = runperl(progfile => $tmpfile, args => [$_]);
        $got =~ s/\s+/ /gs;
        like($got, qr/\s*0 1 DESTROY 0 0\s*/,
             "\@DB::args doesn't leak with \$^P = $_");
    }
}

# This also used to leak [perl #97010]:
{
    my $gone;
    sub fwib::DESTROY { ++$gone }
    package DB;
    sub { () = caller(0) }->(); # initialise PL_dbargs
    @args = bless[],'fwib';
    sub { () = caller(0) }->(); # clobber @args without initialisation
    ::is $gone, 1, 'caller does not leak @DB::args elems when AvREAL';
}

$::testing_caller = 1;

my $caller_file = './op/caller.pl';
if ( !-e $caller_file ) {
    $caller_file = './t/CORE/'.$caller_file;
}

do "$caller_file" or die $@;
