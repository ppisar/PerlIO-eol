#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "perlio.h"
#include "perliol.h"
#include "fill.h"

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
        Perl_die(aTHX_ "Unknown eol '%s'; must pass CRLF, CR or LF or Native to :eol().", eol_w);
    }

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
    STDCHAR *buf = NULL, *ptr = NULL;

    if (code != 0) {
	return code;
    }

    /* OK, we got a buffer... now deal with it. */

    if (s->read_cr && *start == 012) {
        start++;
    }
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

    if (buf != NULL) {
        if (i > start) {
            Copy(start, ptr, i - start, STDCHAR);
            ptr += i - start;
        }
        Copy(buf, b->buf, ptr - buf, STDCHAR);
        b->ptr = b->buf;
        b->end = b->buf + (ptr - buf);
        Safefree(buf);
    }

    return 0;
}

SSize_t
PerlIOEOL_read(pTHX_ PerlIO *f, void *vbuf, Size_t count)
{
    STDCHAR *buf = (STDCHAR *) vbuf;
    if (f) {
        if (!(PerlIOBase(f)->flags & PERLIO_F_CANREAD)) {
	    PerlIOBase(f)->flags |= PERLIO_F_ERROR;
	    SETERRNO(EBADF, SS_IVCHAN);
	    return 0;
	}
	while (count > 0) {
	    SSize_t avail = PerlIOBuf_get_cnt(aTHX_ f);
	    SSize_t take = 0;
	    if (avail > 0)
		take = ((SSize_t)count < avail) ? count : avail;
	    if (take > 0) {
		STDCHAR *ptr = PerlIOBuf_get_ptr(aTHX_ f);
		Copy(ptr, buf, take, STDCHAR);
		PerlIOBuf_set_ptrcnt(aTHX_ f, ptr + take, (avail -= take));
		count -= take;
		buf += take;
	    }
	    if (count > 0 && avail <= 0) {
		if (PerlIOEOL_fill(aTHX_ f) != 0) {
		    /* We do not consider this an error. */
		    PerlIOBase_clearerr(aTHX_ f);
		    break;
		}
	    }
	}
	return (buf - (STDCHAR *) vbuf);
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
    PerlIOEOL_read,
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
