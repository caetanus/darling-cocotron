// OSXER FIX (gallery diagnostics): no control contents or full filesystem paths.
#ifndef OSXER_GALLERY_DEBUG_H
#define OSXER_GALLERY_DEBUG_H

#include <stdio.h>
#include <stdlib.h>

static inline int OSXERGalleryDebugEnabled(void) {
    const char *value = getenv("OSXER_GALLERY_DEBUG");
    return value != NULL && value[0] == '1' && value[1] == '\0';
}

#define OSXERGalleryDebug(...) do { \
    if (OSXERGalleryDebugEnabled()) { \
        fprintf(stderr, "OSXER gallery: " __VA_ARGS__); \
        fflush(stderr); \
    } \
} while (0)

#endif
