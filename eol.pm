package PerlIO::eol;

use 5.007003;
use XSLoader;
use Exporter;

our $VERSION = '0.08';
our @ISA = qw(Exporter);

# symbols to export on request
our @EXPORT_OK = qw(eol_is_mixed CR LF CRLF NATIVE);

XSLoader::load __PACKAGE__, $VERSION;

1;

=head1 NAME

PerlIO::eol - PerlIO layer for normalizing line endings

=head1 VERSION

This document describes version 0.08 of PerlIO::eol, released 
October 15, 2004.

=head1 SYNOPSIS

    binmode STDIN, ":raw:eol(LF)";
    binmode STDOUT, ":raw:eol(CRLF)";
    open FH, "+<:raw:eol(LF-Native)", "file";

    use PerlIO::eol qw( eol_is_mixed );
    my $pos = eol_is_mixed( "mixed\nstring\r" );

=head1 DESCRIPTION

This layer normalizes any of C<CR>, C<LF>, C<CRLF> and C<Native> into the
designated line ending.  It works for both input and output handles.

If you specify two different line endings joined by a C<->, it will use the
first one for reading and the second one for writing.  For example, the
C<LF-CRLF> encoding means that all input should be normalized to C<LF>, and
all output should be normalized to C<CRLF>.

It is advised to pop any potential C<:crlf> or encoding layers before this
layer; this is usually done using a C<:raw> prefix.

This module also optionally exports a C<eol_is_mixed> function; it takes a
string and returns the position of the first inconsistent line ending found
in that string, or C<0> if the line endings are consistent.

The C<CR>, C<LF>, <CRLF> and <NATIVE> constants are also exported at request.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

Based on L<PerlIO::nline> by Ben Morrow, E<lt>PerlIO-eol@morrow.me.ukE<gt>.

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
