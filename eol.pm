package PerlIO::eol;

use 5.007003;
use XSLoader;
our $VERSION = '0.01';
XSLoader::load __PACKAGE__, $VERSION;

1;

=head1 NAME

PerlIO::eol - PerlIO layer for normalizing line endings

=head1 VERSION

This document describes version 0.01 of PerlIO::eol, released 
October 7, 2004.

=head1 SYNOPSIS

    binmode STDIN, ":raw:eol(LF)";
    binmode STDOUT, ":raw:eol(CRLF)";

=head1 DESCRIPTION

This layer normalizes any of C<CR>, C<LF> and C<CRLF> into the designated
line ending.  It works for both input and output handles.

It is advised to pop any potential C<:crlf> or encoding layers before this
layer; this is usually done using a C<:raw> prefix.

=head1 CAVEATS

If the source stream ends with a single C<CR>, it may be silently dropped;
this is a limitation inherited from L<PerlIO::nline>'s design.  Patches to
implement the correct C<Flush> and C<Unread> handlers are most welcome.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

Based on L<PerlIO::nline> by Ben Morrow, E<lt>PerlIO-eol@morrow.me.ukE<gt>.

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
