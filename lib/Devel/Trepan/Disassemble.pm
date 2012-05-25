#!/usr/bin/env perl 
# Copyright (C) 2012 Rocky Bernstein <rocky@cpan.org>
package Devel::Trepan::Disassemble;
our $VERSION='1.1';
"All of the real action is in Devel::Trepan::CmdProcessor::Command::Disassemble.pm";

=pod

=head1 NAME

Perl Disassembly plugin for L<Devel::Trepan> via L<B::Concise>

=head1 SUMMARY

This adds a "disassemble" command to the L<Devel::Trepan> debugger.

This plugin uses B::Concise to disassemble a list of subroutines or a
packages.  

See "help" inside the debugger or a list of options.

=head1 AUTHORS

Rocky Bernstein

=head1 COPYRIGHT

Copyright (C) 2012 Rocky Bernstein <rocky@cpan.org>

This program is distributed WITHOUT ANY WARRANTY, including but not
limited to the implied warranties of merchantability or fitness for a
particular purpose.

The program is free software. You may distribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation (either version 2 or any later version) and
the Perl Artistic License as published by O’Reilly Media, Inc. Please
open the files named gpl-2.0.txt and Artistic for a copy of these
licenses.

=cut


