#define WriteInsert(sym, len) \
    if (PerlIOBuf_write(aTHX_ f, sym, len) < len) \
        return i - (STDCHAR*)vbuf;

#define WriteOutBuffer \
    WriteInsert( start, (i - start) );

#define WriteCheckForCRLF \
    EOL_CheckForCRLF( s->write_cr );

#define WriteCheckForCRandCRLF \
    if (*i == 015) WriteCheckForCRLF;

#define WriteWithCRLF \
    EOL_LoopForCRorLF; \
    WriteOutBuffer; \
    WriteInsert( PerlIOEOL_CRLF, 2 ); \
    WriteCheckForCRandCRLF; \
    EOL_LoopEnd;

#define WriteWithLF \
    EOL_LoopForCR; \
    WriteOutBuffer; \
    WriteInsert( PerlIOEOL_LF, 1 ); \
    WriteCheckForCRLF; \
    EOL_LoopEnd;

#define WriteWithCR \
    EOL_LoopForCRorLF; \
    WriteOutBuffer; \
    WriteInsert( PerlIOEOL_CR, 1 ); \
    WriteCheckForCRandCRLF; \
    EOL_LoopEnd;

/* vim: set filetype=perl: */
