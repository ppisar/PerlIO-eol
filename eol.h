typedef struct {
    PerlIOBuf base;
    bool      read_cr,   write_cr;
    STDCHAR   *read_eol, *write_eol;
} PerlIOEOL;

#define PerlIOEOL_CR     "\015"
#define PerlIOEOL_LF     "\012"
#define PerlIOEOL_CRLF   "\015\012"

#ifdef PERLIO_USING_CRLF
#  define PerlIOEOL_NATIVE PerlIOEOL_CRLF
#else
#  ifdef MACOS_TRADITIONAL
#    define PerlIOEOL_NATIVE PerlIOEOL_CR
#  else
#    define PerlIOEOL_NATIVE PerlIOEOL_LF
#  endif
#endif

#define EOL_LoopBegin \
    for (i = start; i < end; i++) {

#define EOL_LoopEnd \
        start = i + 1; \
    }

#define EOL_LoopForCR \
    EOL_LoopBegin; \
    if (*i != 015) continue;

#define EOL_LoopForCRorLF \
    EOL_LoopBegin; \
    if ( (*i != 015) && (*i != 012) ) continue;

#define EOL_CheckForCRLF(s_cr) \
    if (i == end - 1) { \
        s_cr = 1; \
    } \
    else if (i[1] == 012) { \
        i++; \
    }

#define EOL_AssignEOL(eol, s_eol) \
    if ( strEQ( eol, "cr" ) )           { s_eol = PerlIOEOL_CR; } \
    else if ( strEQ( eol, "lf" ) )      { s_eol = PerlIOEOL_LF; } \
    else if ( strEQ( eol, "crlf" ) )    { s_eol = PerlIOEOL_CRLF; } \
    else if ( strEQ( eol, "native" ) )  { s_eol = PerlIOEOL_NATIVE; } \
    else { \
        Perl_die(aTHX_ "Unknown eol '%s'; must pass CRLF, CR or LF or Native to :eol().", eol); \
    }

