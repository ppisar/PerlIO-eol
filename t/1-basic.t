use Test::More tests => 15;

my ($CR, $LF) = ("\015", "\012");

use_ok('PerlIO::eol', qw( eol_is_mixed ));
is( eol_is_mixed("."), 0 );
is( eol_is_mixed(".$CR$LF."), 0 );
is( eol_is_mixed(".$CR.$LF."), 3 );
is( eol_is_mixed(".$CR$LF.$CR"), 4 );

$/ = undef;

{
    open my $w, ">:raw", "read" or die "can't create testfile: $!";
    print $w "...$CR$LF$LF$CR...";
}

{
    ok(open(my $r, "<:raw:eol(CR)", "read"), "open for read");
    is <$r>, "...$CR$CR$CR...", "read";
}

{
    ok(open(my $r, "<:raw:eol(LF)", "read"), "open for read");
    is <$r>, "...$LF$LF$LF...", "read";
}

{
    ok(open(my $r, "<:raw:eol(CRLF)", "read"), "open for read");
    is <$r>, "...$CR$LF$CR$LF$CR$LF...", "read";
}

{
    ok(open(my $w, ">:raw:eol(CrLf-lf)", "write"), "open for write");
    print $w "$CR";
}

{
    open my $r, "<:raw", "write" or die "can't read testfile: $!";
    is(<$r>, "$LF", "write");
}

{
    ok(open(my $w, ">:raw:eol(LF-Native)", "write"), "open for write");
    print $w "$CR";
}

{
    open my $r, "<", "write" or die "can't read testfile: $!";
    is(<$r>, "\n", "write");
}

END {
    unlink "read";
    unlink "write";
}
