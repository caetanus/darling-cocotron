// Temporary drawing diagnostics; remove after the Darling investigation.
#ifndef OSXER_TABLE_DEBUG_H
#define OSXER_TABLE_DEBUG_H

#include <stdio.h>
#include <stdlib.h>

static inline int OSXERTableDebugEnabled(void) {
    const char *value = getenv("OSXER_TABLE_DEBUG");
    return value != NULL && value[0] == '1' && value[1] == '\0';
}

#endif
