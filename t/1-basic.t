use Test::More tests => 8;

$/ = undef;

my ($CR, $LF) = ("\015", "\012");

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
    ok(open(my $w, ">:raw:eol(LF)", "write"), "open for write");
    print $w "$CR";
}

{
    open my $r, "<:raw", "write" or die "can't read testfile: $!";
    is(<$r>, "$LF", "write");
}

unlink "read";
unlink "write";
