#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "perlio.h"
#include "perliol.h"

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

IV
PerlIOEOL_pushed(pTHX_ PerlIO *f, const char *mode, SV *arg, PerlIO_funcs *tab)
{
    PerlIOEOL *s = PerlIOSelf(f, PerlIOEOL);
    register U8 *p, *eol_w = NULL, *eol_r = NULL;
    STRLEN len;
    
    if (PerlIOBase(PerlIONext(f))->flags & PERLIO_F_UTF8) {
        PerlIOBase(f)->flags |= PERLIO_F_UTF8;
    }
    else {
        PerlIOBase(f)->flags &= ~PERLIO_F_UTF8;
    }

    s->read_cr = s->write_cr = 0;

    p = (U8*)SvPV(arg, len);
    if (len) {
        register U8 *end = p + len;
        Newz('e', eol_r, len + 1, U8);
        Copy(p, eol_r, len, U8);

        p = eol_r; end = p + len;
        for (; p < end; p++) {
            *p = toLOWER(*p);
            if ((*p == '-') && (eol_w == NULL)) {
                *p = '\0';
                eol_w = p+1;
            }
        }
    }
    else {
        Perl_die(aTHX_ "Must pass CRLF, CR, LF or Native to :eol().");
    }

    /* split off eol using strchr */
    if (eol_w == NULL) { eol_w = eol_r; }

    if ( strEQ( eol_r, "cr" ) )           { s->read_eol = PerlIOEOL_CR; }
    else if ( strEQ( eol_r, "lf" ) )      { s->read_eol = PerlIOEOL_LF; }
    else if ( strEQ( eol_r, "crlf" ) )    { s->read_eol = PerlIOEOL_CRLF; }
    else if ( strEQ( eol_r, "native" ) )  { s->read_eol = PerlIOEOL_NATIVE; }
    else {
        Perl_die(aTHX_ "Unknown eol '%s'; must pass CRLF, CR or LF or Native to :eol().", eol_r);
    }

    if ( strEQ( eol_w, "cr" ) )           { s->write_eol = PerlIOEOL_CR; }
    else if ( strEQ( eol_w, "lf" ) )      { s->write_eol = PerlIOEOL_LF; }
    else if ( strEQ( eol_w, "crlf" ) )    { s->write_eol = PerlIOEOL_CRLF; }
    else if ( strEQ( eol_w, "native" ) )  { s->write_eol = PerlIOEOL_NATIVE; }
    else {
        Perl_die(aTHX_ "Unknown eol '%s'; must pass CRLF, CR or LF or Native to :eol().", eol_r);
    }

    return PerlIOBuf_pushed(aTHX_ f, mode, arg, tab);
}

void
PerlIOEOL_clearerr(pTHX_ PerlIO *f)
{
    PerlIOEOL *s;
    
    if (PerlIOValid(f)) {
        s = PerlIOSelf(f, PerlIOEOL);
        if (PerlIOBase(f)->flags & PERLIO_F_EOF) {
            s->read_cr = s->write_cr = 0;
        }
    }

    PerlIOBase_clearerr(aTHX_ f);
}

SSize_t
PerlIOEOL_write(pTHX_ PerlIO *f, const void *vbuf, Size_t count)
{
    PerlIOEOL *s = PerlIOSelf(f, PerlIOEOL);
    PerlIOBuf *b = PerlIOSelf(f, PerlIOBuf);
    const STDCHAR *i, *start = vbuf, *end = vbuf;
    bool is_crlf = (strEQ( s->write_eol, PerlIOEOL_CRLF ));

    end += (unsigned int)count;

    if (s->write_cr && *start == 012) {
        start++;
    }
    s->write_cr = 0;
    
    if (!(PerlIOBase(f)->flags & PERLIO_F_CANWRITE)) {
        return 0;
    }

    for (i = start; i < end; i++) {
        if (*i == 015 || *i == 012) {
            if (PerlIOBuf_write(aTHX_ f, start, i - start) < i - start) {
                return i - (STDCHAR*)vbuf;
            }

            if (is_crlf) {
                if (PerlIOBuf_write(aTHX_ f, PerlIOEOL_CRLF, 2) < 2) {
                    return i - (STDCHAR*)vbuf;
                }
            }
            else {
                if (PerlIOBuf_write(aTHX_ f, s->write_eol, 1) < 1) {
                    return i - (STDCHAR*)vbuf;
                }
            }

            if (*i == 015) {
                if (i == end - 1) {
                    s->write_cr = 1;
                }
                else if (i[1] == 012) {
                    i++;
                }
            }

            start = i + 1;
        }
    }

    if (start < end) {
        return (
            (start + PerlIOBuf_write(aTHX_ f, start, end - start))
                - (STDCHAR*)vbuf
        );
    }

    return count;
}

IV
PerlIOEOL_fill(pTHX_ PerlIO * f)
{
    IV code = PerlIOBuf_fill(aTHX_ f);
    PerlIOEOL *s = PerlIOSelf(f, PerlIOEOL);
    PerlIOBuf *b = PerlIOSelf(f, PerlIOBuf);
    const STDCHAR *i, *start = b->ptr, *end = b->end;
    bool is_crlf = (strEQ( s->read_eol, PerlIOEOL_CRLF ));
    STDCHAR *buf = NULL, *ptr = NULL;

    if (code == -1) {
        return code;
    }

    /* OK, we got a buffer... now deal with it. */

    if (s->read_cr && *start == 012) {
        start++;
    }
    s->read_cr = 0;

    for (i = start; i < end; i++) {
        if (*i == 015 || *i == 012) {
            if (buf == NULL) {
                New('b', buf, (i - start) + ((end - i + 1) * 2), STDCHAR);
                ptr = buf;
            }

            Copy(start, ptr, i - start, STDCHAR);
            ptr += i - start;

            if (is_crlf) {
                *ptr++ = 015;
                *ptr++ = 012;
            }
            else {
                *ptr++ = *(s->read_eol);
            }

            if (*i == 015) {
                if (i == end - 1) {
                    s->read_cr = 1;
                }
                else if (i[1] == 012) {
                    i++;
                }
            }

            start = i + 1;
        }
    }

    if (buf != NULL) {
        if (i > start) {
            Copy(start, ptr, i - start, STDCHAR);
            ptr += i - start;
        }
        b->ptr = b->buf = buf;
        b->end = ptr;
    }

    return 0;
}

PerlIO_funcs PerlIO_eol = {
    sizeof(PerlIO_funcs),
    "eol",
    sizeof(PerlIOEOL),
    PERLIO_K_BUFFERED | PERLIO_K_UTF8, 
    PerlIOEOL_pushed,
    PerlIOBuf_popped,
    NULL,
    PerlIOBase_binmode,
    NULL,
    PerlIOBase_fileno,
    PerlIOBuf_dup,
    PerlIOBuf_read,
    PerlIOBuf_unread,
    PerlIOEOL_write,
    PerlIOBuf_seek,
    PerlIOBuf_tell,
    PerlIOBuf_close,
    PerlIOBuf_flush,
    PerlIOEOL_fill,
    PerlIOBase_eof,
    PerlIOBase_error,
    PerlIOEOL_clearerr,
    PerlIOBase_setlinebuf,
    PerlIOBuf_get_base,
    PerlIOBuf_bufsiz,
    PerlIOBuf_get_ptr,
    PerlIOBuf_get_cnt,
    PerlIOBuf_set_ptrcnt
};

MODULE = PerlIO::eol            PACKAGE = PerlIO::eol

PROTOTYPES: DISABLE

BOOT:  
  #ifdef PERLIO_LAYERS
        PerlIO_define_layer(aTHX_ &PerlIO_eol);
  #endif

#define PerlIOEOL_Seen(sym) \
    if (seen && (seen != sym)) { \
        RETVAL = (p + len - end); \
        break; \
    } \
    seen = sym;

unsigned int
eol_is_mixed(arg)
        SV  *arg
    CODE:
        STRLEN len;
        register U8 *p, *end;
        register unsigned int seen = 0;
        p = (U8*)SvPV(arg, len);
        end = p + len;
        RETVAL = 0;
        for (; p < end; p++) {
            if (*p == 012) {
                PerlIOEOL_Seen(*p); /* LF */
            }
            else if (*p == 015) {
                if ((p == end - 1) || p[1] != 012 ) {
                    PerlIOEOL_Seen(*p); /* CR */
                }
                else {
                    PerlIOEOL_Seen(015 + 012); /* CRLF */
                    p++;
                }
            }
        }
    OUTPUT:
        RETVAL
