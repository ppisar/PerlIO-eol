#define FillInitializeBuffer \
    if (buf == NULL) { \
        New('b', buf, (i - start) + ((end - i + 1) * 2), STDCHAR); \
        ptr = buf; \
    } \
    Copy(start, ptr, i - start, STDCHAR); \
    ptr += i - start;

#define FillCheckForCRLF \
    if (i == end - 1) { \
        s->read_cr = 1; \
    } \
    else if (i[1] == 012) { \
        i++; \
    }

#define FillCheckForCRandCRLF \
    if (*i == 015) FillCheckForCRLF;

#define FillOnlyForCR \
    if (*i != 015) continue; \
    FillInitializeBuffer;

#define FillOnlyForCRorLF \
    if ( (*i != 015) && (*i != 012) ) continue; \
    FillInitializeBuffer;

#define FillLoopBegin \
    for (i = start; i < end; i++) {

#define FillLoopEnd \
        start = i + 1; \
    }

#define FillInsertCR \
    *ptr++ = 015;

#define FillInsertLF \
    *ptr++ = 012;

#define FillWithCRLF \
    FillLoopBegin; \
    FillOnlyForCRorLF; \
    FillInsertCR; \
    FillInsertLF; \
    FillCheckForCRandCRLF; \
    FillLoopEnd;

#define FillWithLF \
    FillLoopBegin; \
    FillOnlyForCR; \
    FillInsertLF; \
    FillCheckForCRLF; \
    FillLoopEnd;

#define FillWithCR \
    FillLoopBegin; \
    FillOnlyForCRorLF; \
    FillInsertCR; \
    FillCheckForCRandCRLF; \
    FillLoopEnd;

/* vim: set filetype=perl: */
