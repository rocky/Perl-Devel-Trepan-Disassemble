#!/usr/bin/env perl
use warnings; use strict;
use English;
use rlib '.';
use Helper;

my $TREPAN_DIR;
BEGIN {
    $TREPAN_DIR =
	File::Spec->catfile(dirname(__FILE__), '..', 'lib', 'Devel', 'Trepan',
			    'CmdProcessor', 'Command');
}

use rlib $TREPAN_DIR;
use Test::More;
if ($OSNAME eq 'MSWin32') {
    plan skip_all => "Strawberry Perl doesn't handle exec well" 
} else {
    plan;
}

my $opts = {
    filter => sub{
	my ($got_lines, $correct_lines) = @_;
	my @result = ();
	for my $line (split("\n", $got_lines)) {
	    $line =~ s/(^[A-Z]+) \(0x[a-f0-9]+\)/$1 (0x1234567)/;
            # use Enbugger; Enbugger->load_debugger('trepan');
	    # Enbugger->stop() if $line =~ /^op_first/;
	    $line =~ s/^\top_(first|last|next|sibling|sv)(\s+)(0x[a-f0-9]+)/\top_$1${2}0x7654321/;
	    push @result, $line;
	}
	$got_lines = join("\n", @result);
	return ($got_lines, $correct_lines);
    }
};

my $test_prog = File::Spec->catfile(dirname(__FILE__), 
				    qw(.. example five.pm));
my $ok = Helper::run_debugger("$test_prog --cmddir $TREPAN_DIR", 
			      'disassemble.cmd', undef, $opts);
done_testing;
