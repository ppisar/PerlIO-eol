#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "perlio.h"
#include "perliol.h"

#include "eol.h"
#include "fill.h"
#include "write.h"

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

    EOL_AssignEOL( eol_r, s->read_eol );
    EOL_AssignEOL( eol_w, s->write_eol );

    Safefree( eol_r );

    return PerlIOBuf_pushed(aTHX_ f, mode, arg, tab);
}

STDCHAR *
PerlIOEOL_get_base(pTHX_ PerlIO *f)
{
    PerlIOBuf *b = PerlIOSelf(f, PerlIOBuf);
    if (!b->buf) {
        PerlIOEOL *s = PerlIOSelf(f, PerlIOEOL);

	if (!b->bufsiz)
	    b->bufsiz = 4096;

	b->buf = Newz(
            'B',
            b->buf,
            b->bufsiz * strlen( s->read_eol ),
            STDCHAR
        );

	if (!b->buf) {
	    b->buf = (STDCHAR *) & b->oneword;
	    b->bufsiz = sizeof(b->oneword);
	}
	b->ptr = b->buf;
	b->end = b->ptr;
    }
    return b->buf;
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

    if (s->write_cr && *start == 012) { start++; }
    s->write_cr = 0;
    
    if (!(PerlIOBase(f)->flags & PERLIO_F_CANWRITE)) {
        return 0;
    }

    if (strEQ( s->write_eol, PerlIOEOL_LF )) {
        WriteWithLF;
    }
    else if (strEQ( s->write_eol, PerlIOEOL_CRLF )) {
        WriteWithCRLF;
    }
    else if (strEQ( s->write_eol, PerlIOEOL_CR )) {
        WriteWithCR;
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
    STDCHAR *buf = NULL, *ptr = NULL;

    if (code != 0) { return code; }

    /* OK, we got a buffer... now deal with it. */

    if (s->read_cr && *start == 012) { start++; }
    s->read_cr = 0;

    if (strEQ( s->read_eol, PerlIOEOL_LF )) {
        FillWithLF;
    }
    else if (strEQ( s->read_eol, PerlIOEOL_CRLF )) {
        FillWithCRLF;
    }
    else if (strEQ( s->read_eol, PerlIOEOL_CR )) {
        FillWithCR;
    }

    if (buf == NULL) { return 0; }

    if (i > start) {
        Copy(start, ptr, i - start, STDCHAR);
        ptr += i - start;
    }

    b->ptr = b->buf;
    b->end = b->buf + (ptr - buf);

    if (buf != b->buf) {
        Copy(buf, b->buf, ptr - buf, STDCHAR);
        Safefree(buf);
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
    PerlIOEOL_get_base,
    PerlIOBuf_bufsiz,
    PerlIOBuf_get_ptr,
    PerlIOBuf_get_cnt,
    PerlIOBuf_set_ptrcnt
};

MODULE = PerlIO::eol            PACKAGE = PerlIO::eol

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
    PROTOTYPE: $
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

char *
CR()
    PROTOTYPE:
    CODE:
        RETVAL = PerlIOEOL_CR;
    OUTPUT:
        RETVAL

char *
LF()
    PROTOTYPE:
    CODE:
        RETVAL = PerlIOEOL_LF;
    OUTPUT:
        RETVAL

char *
CRLF()
    PROTOTYPE:
    CODE:
        RETVAL = PerlIOEOL_CRLF;
    OUTPUT:
        RETVAL

char *
NATIVE()
    PROTOTYPE:
    CODE:
        RETVAL = PerlIOEOL_NATIVE;
    OUTPUT:
        RETVAL
