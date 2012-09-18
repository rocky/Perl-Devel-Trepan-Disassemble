# -*- coding: utf-8 -*-
# Copyright (C) 2011, 2012 Rocky Bernstein <rocky@cpan.org>
use warnings; no warnings 'redefine';

use rlib '../../../..';

# Our local modules

package Devel::Trepan::CmdProcessor::Command::Disassemble;

## FIXME:: Make conditional
use Syntax::Highlight::Perl::Improved ':FULL';
use Devel::Trepan::DB::Colors;

my $perl_formatter = Devel::Trepan::DB::Colors::setup();

use Getopt::Long qw(GetOptionsFromArray);
use B::Concise qw(set_style);

use if !@ISA, Devel::Trepan::CmdProcessor::Command ;

unless (@ISA) {
    eval <<"EOE";
    use constant ALIASES    => qw(disasm);
    use constant CATEGORY   => 'data';
    use constant SHORT_HELP => 'Disassemble subroutine(s)';
    use constant MIN_ARGS  => 0;  # Need at least this many
    use constant MAX_ARGS  => undef;  # Need at most this many - undef -> unlimited.
    use constant NEED_STACK => 0;

EOE
}

use strict;

use vars qw(@ISA $DEFAULT_OPTIONS); 
@ISA = qw(Devel::Trepan::CmdProcessor::Command); 

use vars @CMD_VARS;  # Value inherited from parent

$DEFAULT_OPTIONS = {
    line_style => 'debug',
    order      => '-basic',
    tree_style => '-ascii',
    highlight  => 1,
};

our $NAME = set_name();
our $HELP = <<'HELP';
=pod

B<disassemble> [I<options>] [I<subroutine>|I<package-name> ...]

options: 
    -concise
    -terse 
    -linenoise
    -debug
    -compact
    -exec
    -tree
    -loose
    -vt
    -ascii

Use L<B::Concise> to disassemble a list of subroutines or a packages.  If
no subroutine or package is specified, use the subroutine where the
program is currently stopped.

=cut
HELP

sub complete($$) 
{
    no warnings 'once';
    my ($self, $prefix) = @_;
    my @subs = keys %DB::sub;
    my @opts = (qw(-concise -terse -linenoise -debug -basic -exec -tree 
                   -compact -loose -vt -ascii),
		@subs);
    Devel::Trepan::Complete::complete_token(\@opts, $prefix) ;
}
    
sub parse_options($$)
{
    my ($self, $args) = @_;
    my $opts = $DEFAULT_OPTIONS;
    my $result = &GetOptionsFromArray($args,
          '-concise'    => sub { $opts->{line_style} = 'concise'},
          '-terse'      => sub { $opts->{line_style} = 'terse'},
          '-linenoise'  => sub { $opts->{line_style} = 'linenoise'},
          '-debug'      => sub { $opts->{line_style} = 'debug'},
	  # FIXME: would need to check that ENV vars B_CONCISE_FORMAT, B_CONCISE_TREE_FORMAT
	  # and B_CONCISE_GOTO_FORMAT are set
          # '-env'        => sub { $opts->{line_style} = 'env'},

          '-basic'      => sub { $opts->{order} = '-basic'; },
          '-exec'       => sub { $opts->{order} = '-exec'; },
          '-tree'       => sub { $opts->{order} = '-tree'; },

          '-compact'    => sub { $opts->{tree_style} = '-compact'; },
          '-loose'      => sub { $opts->{tree_style} = '-loose'; },
          '-vt'         => sub { $opts->{tree_style} = '-vt'; },
          '-ascii'      => sub { $opts->{tree_style} = '-ascii'; },
          '-highlight'  => sub { $opts->{highlight} = 1; },
          '-no-highlight' => sub { $opts->{highlight} = 0; },
	);
    $opts;
}

sub highlight_string($)
{
    my ($string) = shift;
    $perl_formatter->reset();
    $string = $perl_formatter->format_string($string);
    chomp $string;
    $string;
  }

sub markup_basic($$$) 
{
    my ($lines, $highlight, $proc) = @_;
    my @lines = split /\n/, $lines;
    foreach (@lines) {
	my $marker = '    ';
	if (/^#(\s+)(\d+):(\s+)(.+)$/) {
	    my ($space1, $lineno, $space2, $perl_code) = ($1, $2, $3, $4);
	    my $marked;
	    if ($perl_code eq '-src not supported for -e' || 
		$perl_code eq '-src unavailable under -e') {
		my $opts = {
		    output => $highlight,
		    max_continue => 5,
		};
		my $filename = $proc->{frame}{file};
		$marked = DB::LineCache::getline($filename, $lineno, $opts);
		$_ = "#${space1}${lineno}:${space2}$marked" if $marked;
	    } else {
		# print "FOUND line $lineno\n";
		if ($highlight) {
		    $marked = highlight_string($perl_code);
		    $_ = "#${space1}${lineno}:${space2}$marked";
		}
	    }
	    ## FIXME: move into DB::Breakpoint and adjust List.pm
	    if (exists($DB::dbline{$lineno}) and 
		my $brkpts = $DB::dbline{$lineno}) {
		my $found = 0;
		for my $bp (@{$brkpts}) {
		    if (defined($bp)) {
			$marker = sprintf('%s%02d ', $bp->icon_char, $bp->id);
			$found = 1;
			last;
		    }
		}
	    }
	    ## FIXME move above code
	    
	} elsif (/^([A-Z]+) \((0x[0-9a-f]+)\)/) {
	    my ($op, $hex_str) = ($1, $2);
	    # print "FOUND $op, $hex_str\n";
	    if (defined($DB::OP_addr)) {
		my $check_hex_str = sprintf "0x%x", $DB::OP_addr;
		$marker = '=>  ' if ($check_hex_str eq $hex_str);
	    }
	    if ($highlight) {
		$op = $perl_formatter->format_token($op, 'Subroutine');
		$hex_str = $perl_formatter->format_token($hex_str, 'Number');
		$_ = "$op ($hex_str)";
	    }

	}
	$_ = $marker . $_;
    }
    return join("\n", @lines);
}

sub markup_tree($$$) 
{
    my ($lines, $highlight, $proc) = @_;
    my @lines = split /\n/, $lines;
    foreach (@lines) {
	my $marker = '    ';
	if (/^(\s+)\|-#(\s+)(\d+):(.+)$/) {
	    my ($space1, $space2, $lineno, $perl_code) = ($1, $2, $3, $4);
	    my $marked;
	    # FIXME: DRY code with markup_basic
	    if ($perl_code =~ 
		/-src (?:(?:not supported for)|(?:unavailable under)) -e/) {
		my $opts = {
		    output => $highlight,
		    max_continue => 5,
		};
		my $filename = $proc->{frame}{file};
		$marked = DB::LineCache::getline($filename, $lineno, $opts);
		$_ = "${space1}|-#${space2}${lineno}: $marked";
	    } else {
		# print "FOUND line $lineno\n";
		if ($highlight) {
		    $marked = highlight_string($perl_code);
		    $_ = "${space1}|-#${space2}${lineno}: $marked";
		}
	    }
	    ## END above FIXME
	    ## FIXME: move into DB::Breakpoint and adjust List.pm
	    if (exists($DB::dbline{$lineno}) and 
		my $brkpts = $DB::dbline{$lineno}) {
		my $found = 0;
		for my $bp (@{$brkpts}) {
		    if (defined($bp)) {
			$marker = sprintf('%s%02d ', $bp->icon_char, $bp->id);
			$found = 1;
			last;
		    }
		}
	    }
	    ## FIXME move above code
	}
	$_ = $marker . $_;
    }
    return join("\n", @lines);
}

sub do_one($$$$)
{
    my ($proc, $title, $options, $args) = @_;
    no strict 'refs';
    $proc->section($title);
    my $walker = B::Concise::compile($options->{order}, '-src', @{$args});
    B::Concise::set_style_standard($options->{line_style});
    B::Concise::walk_output(\my $buf);
    $walker->();			# walks and renders into $buf;
    my $highlight = $options->{highlight} && $proc->{settings}{highlight};
    ## FIXME: syntax highlight the output.a
    if ('-tree' eq $options->{order}) {
	$buf = markup_tree($buf, $options->{highlight}, $proc);
    } elsif ('-basic' eq $options->{order}) {
	$buf = markup_basic($buf, $options->{highlight}, $proc);
    }
    $proc->msg($buf);
}

sub run($$)
{
    my ($self, $args) = @_;
    my @args = @$args;
    shift @args;
    my $options = parse_options($self, \@args);
    my $proc = $self->{proc};
    unless (scalar(@args)) {
	if ($proc->funcname && $proc->funcname ne 'DB::DB') {
	    push @args, $proc->funcname;
	} else {
	    do_one($proc, "Package Main", $options, ['-main']);
	}
    }

    for my $disasm_unit (@args) {
	no strict 'refs';
	if (%{$disasm_unit.'::'}) {
	    do_one($proc, "Package $disasm_unit", $options, 
		   ["-stash=$disasm_unit"]);
	} elsif ($proc->is_method($disasm_unit)) {
	    do_one($proc, "Subroutine $disasm_unit", $options, [$disasm_unit]);
	} else {
	    $proc->errmsg("Don't know $disasm_unit as a package or function");
	}
    }
}

  
# Demo it
unless (caller) {
    require Devel::Trepan::CmdProcessor;
    eval { use Devel::Callsite };
    my $proc = Devel::Trepan::CmdProcessor->new(undef, 'bogus');
    my $cmd = __PACKAGE__->new($proc);
    eval {
        sub create_frame() {
            my ($pkg, $file, $line, $fn) = caller(0);
	    no warnings 'once';
            $DB::package = $pkg;
            return [
                {
                    file      => $file,
                    fn        => $fn,
                    line      => $line,
                    pkg       => $pkg,
                }];
        }
    };
    # use Enbugger 'trepan'; Enbugger->stop;
    sub site { return callsite() };
    $DB::OP_addr = site();
    $cmd->run([$NAME, '-tree']);
    print '=' x 50, "\n";
    $cmd->run([$NAME, '-basic']);
    print '=' x 50, "\n";
    $cmd->run([$NAME, '-basic', '--no-highlight']);
}

1;
