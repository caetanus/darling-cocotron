#ifndef OSXER_FOCUS_DEBUG_H
#define OSXER_FOCUS_DEBUG_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// OSXER FOCUS (diagnostics): explicitly requested support logging. Only the
// exact value 1 enables it; never log titles, field contents or key events.
static inline int OSXERFocusDebugEnabled(void) {
    const char *value = getenv("OSXER_FOCUS_DEBUG");
    return value != NULL && strcmp(value, "1") == 0;
}
#define OSXERFocusLog(...) do { \
    if (OSXERFocusDebugEnabled()) { \
        fprintf(stderr, "[OSXER_FOCUS_DEBUG] " __VA_ARGS__); \
        fflush(stderr); \
    } \
} while (0)
#endif
