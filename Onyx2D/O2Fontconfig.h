// OSXER FIX (scalable fonts): shared by Onyx2D and AppKit's X11 backend.
#ifndef O2FONTCONFIG_H
#define O2FONTCONFIG_H

#include <fontconfig/fontconfig.h>
#include "OSXERGalleryDebug.h"
#include <string.h>

static inline int O2FontconfigHasOutlines(FcPattern *font) {
    FcBool scalable = FcFalse, outline = FcFalse;
    return font != NULL &&
           FcPatternGetBool(font, FC_SCALABLE, 0, &scalable) == FcResultMatch &&
           FcPatternGetBool(font, FC_OUTLINE, 0, &outline) == FcResultMatch &&
           scalable && outline;
}

static inline void O2FontconfigDebugMatch(const char *stage, FcPattern *request,
                                         FcPattern *font) {
    if (!OSXERGalleryDebugEnabled() || font == NULL)
        return;
    FcChar8 *requested = NULL, *family = NULL, *file = NULL;
    FcBool scalable = FcFalse, outline = FcFalse;
    int index = 0;
    FcPatternGetString(request, FC_FAMILY, 0, &requested);
    FcPatternGetString(font, FC_FAMILY, 0, &family);
    FcPatternGetString(font, FC_FILE, 0, &file);
    FcPatternGetInteger(font, FC_INDEX, 0, &index);
    FcPatternGetBool(font, FC_SCALABLE, 0, &scalable);
    FcPatternGetBool(font, FC_OUTLINE, 0, &outline);
    const char *basename = file ? strrchr((const char *)file, '/') : NULL;
    basename = basename ? basename + 1 : (file ? (const char *)file : "?");
    OSXERGalleryDebug("font %s request=%s family=%s file=%s index=%d scalable=%d outline=%d\n",
                      stage, requested ? (const char *)requested : "(default)",
                      family ? (const char *)family : "?", basename, index,
                      scalable, outline);
}

// Caller substitutes the request first and destroys the returned pattern.
static inline FcPattern *O2FontconfigMatchScalable(FcConfig *config, FcPattern *request) {
    FcResult result;
    if (OSXERGalleryDebugEnabled()) {
        FcPattern *original = FcFontMatch(config, request, &result);
        if (!O2FontconfigHasOutlines(original))
            O2FontconfigDebugMatch("rejected-unconstrained", request, original);
        if (original != NULL)
            FcPatternDestroy(original);
    }

    FcPatternDel(request, FC_SCALABLE);
    FcPatternDel(request, FC_OUTLINE);
    FcPatternAddBool(request, FC_SCALABLE, FcTrue);
    FcPatternAddBool(request, FC_OUTLINE, FcTrue);
    FcPattern *match = FcFontMatch(config, request, &result);
    if (O2FontconfigHasOutlines(match))
        return match;
    if (match != NULL)
        FcPatternDestroy(match);

    // These properties are matching preferences, not a hard filter. A named
    // bitmap family can still win. Keep all candidates (trim=false), then
    // reject bitmap faces, including color emoji with scalable=true/outline=false.
    FcFontSet *sorted = FcFontSort(config, request, FcFalse, NULL, &result);
    match = NULL;
    if (sorted != NULL) {
        for (int i = 0; i < sorted->nfont; i++) {
            if (O2FontconfigHasOutlines(sorted->fonts[i])) {
                match = FcFontRenderPrepare(config, request, sorted->fonts[i]);
                break;
            }
        }
        FcFontSetDestroy(sorted);
    }
    if (match != NULL && !O2FontconfigHasOutlines(match)) {
        FcPatternDestroy(match);
        match = NULL;
    }
    return match;
}

#endif
