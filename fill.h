#define FillCopyBuffer \
    Copy(start, ptr, i - start, STDCHAR); \
    ptr += i - start;

#define FillInitializeBufferCopy \
    if (buf == NULL) { \
        New('b', buf, (i - start) + ((end - i + 1) * 2), STDCHAR); \
        ptr = buf; \
    } \
    FillCopyBuffer;

#define FillInitializeBuffer \
    if (buf == NULL) { \
        ptr = buf = b->buf; \
    } \
    FillCopyBuffer;

#define FillCheckForCRLF \
    EOL_CheckForCRLF( s->read_cr );

#define FillCheckForCRandCRLF \
    if (*i == 015) FillCheckForCRLF;

#define FillInsertCR \
    *ptr++ = 015;

#define FillInsertLF \
    *ptr++ = 012;

#define FillWithCRLF \
    EOL_LoopForCRorLF; \
    FillInitializeBufferCopy; \
    FillInsertCR; \
    FillInsertLF; \
    FillCheckForCRandCRLF; \
    EOL_LoopEnd;

#define FillWithLF \
    EOL_LoopForCR; \
    FillInitializeBuffer; \
    FillInsertLF; \
    FillCheckForCRLF; \
    EOL_LoopEnd;

#define FillWithCR \
    EOL_LoopForCRorLF; \
    FillInitializeBuffer; \
    FillInsertCR; \
    FillCheckForCRandCRLF; \
    EOL_LoopEnd;

/* vim: set filetype=perl: */
