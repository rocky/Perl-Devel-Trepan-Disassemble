# -*- coding: utf-8 -*-
# Copyright (C) 2011 Rocky Bernstein <rocky@cpan.org>
use warnings; no warnings 'redefine';

use rlib '../../../..';

# Our local modules
## use Devel::Trepan::Options; or is it default

package Devel::Trepan::CmdProcessor::Command::Disassemble;
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
};

our $NAME = set_name();
our $HELP = <<"HELP";
${NAME} [options] [SUBROUTINE|PACKAGE-NAME ...]

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

Use B::Concise to disassemble a list of subroutines or a packages.  If
no subroutine or package is specified, use the subroutine where the
program is currently stopped.
HELP

sub complete($$) 
{
    no warnings 'once';
    my ($self, $prefix) = @_;
    my @subs = keys %DB::sub;
    my @opts = (qw(-concise -terse -linenoise -debug -basic -exec -tree -compact -loose -vt -ascii),
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
	);
    $opts;
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
    ## FIXME: syntax highlight the output.
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
}

1;
