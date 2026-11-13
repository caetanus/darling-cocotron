/* OSXER APPKIT (symbols): system symbol images drawn with Phosphor Icons.

   SF Symbols are Apple's artwork and cannot ship with Darling, so +[NSImage
   imageWithSystemSymbolName:...] used to return a square placeholder for every name. Here a
   symbol name is mapped to the closest Phosphor icon (MIT, Fonts/Phosphor-LICENSE): first an
   explicit table (OSXERPhosphorGlyphs.h), then a heuristic (".fill" selects the filled font,
   words are translated through the single-word table and joined with hyphens, trailing
   modifiers are dropped until a match). The glyph is drawn from Phosphor's fonts as a
   template image, like SF Symbols; names without a match keep the placeholder. */

#import <AppKit/NSImage.h>
#import <AppKit/NSImageRep.h>
#import <AppKit/NSCustomImageRep.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSStringDrawing.h>
#import <AppKit/NSAttributedString.h>
#import <Foundation/Foundation.h>
#import <CoreText/CTFontManager.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>
#include "OSXERPhosphorGlyphs.h"

static int OSXERCompareGlyph(const void *key, const void *entry) {
    return strcmp(key, ((const OSXERPhosphorGlyph *) entry)->name);
}

static int OSXERCompareAlias(const void *key, const void *entry) {
    return strcmp(key, ((const OSXERSymbolAlias *) entry)->sf);
}

static unsigned OSXERGlyphNamed(NSString *phosphor) {
    const OSXERPhosphorGlyph *found = bsearch([phosphor UTF8String], OSXERPhosphorGlyphs,
            sizeof OSXERPhosphorGlyphs / sizeof *OSXERPhosphorGlyphs, sizeof *OSXERPhosphorGlyphs, OSXERCompareGlyph);
    return found ? found->codepoint : 0;
}

static NSString *OSXERAlias(NSString *sf) {
    const OSXERSymbolAlias *found = bsearch([sf UTF8String], OSXERSymbolAliases,
            sizeof OSXERSymbolAliases / sizeof *OSXERSymbolAliases, sizeof *OSXERSymbolAliases, OSXERCompareAlias);
    return found ? [NSString stringWithUTF8String: found->phosphor] : nil;
}

// Glyph for an SF Symbols name: the explicit table, then the words translated one by one.
static unsigned OSXERGlyphForParts(NSArray *parts) {
    NSString *joined = [parts componentsJoinedByString: @"."];
    NSString *alias = OSXERAlias(joined);
    if (alias) return OSXERGlyphNamed(alias);
    NSMutableArray *words = [NSMutableArray array];
    for (NSString *part in parts) [words addObject: OSXERAlias(part) ?: part];
    return OSXERGlyphNamed([words componentsJoinedByString: @"-"]);
}

BOOL OSXERSymbolGlyph(NSString *name, unichar *glyph, BOOL *fill) {
    if (![name length]) return NO;
    NSMutableArray *parts = [[[name componentsSeparatedByString: @"."] mutableCopy] autorelease];
    *fill = [parts containsObject: @"fill"];
    [parts removeObject: @"fill"];
    for (NSUInteger count = [parts count]; count > 0; count--) {
        unsigned codepoint = OSXERGlyphForParts([parts subarrayWithRange: NSMakeRange(0, count)]);
        if (codepoint) {
            *glyph = (unichar) codepoint;
            return YES;
        }
    }
    return NO;
}

static void OSXERRegisterPhosphor(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSBundle *appKit = [NSBundle bundleForClass: [NSImage class]];
        for (NSString *name in @[@"Phosphor", @"Phosphor-Fill"]) {
            NSString *path = [appKit pathForResource: name ofType: @"ttf" inDirectory: @"Fonts"];
            if (path) CTFontManagerRegisterFontsForURL((CFURLRef) [NSURL fileURLWithPath: path], kCTFontManagerScopeProcess, NULL);
        }
    });
}

@interface OSXERSymbolDrawer : NSObject {
@public
    unichar _glyph;
    BOOL _fill;
}
@end

@implementation OSXERSymbolDrawer
// Black glyph centred in the representation; template drawing tints it.
- (void) drawSymbol: (NSCustomImageRep *) rep {
    OSXERRegisterPhosphor();
    NSSize size = [rep size];
    NSFont *font = [NSFont fontWithName: _fill ? @"Phosphor-Fill" : @"Phosphor" size: floor(size.height * 0.9)];
    if (!font) return;
    NSString *text = [NSString stringWithCharacters: &_glyph length: 1];
    NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: [NSColor blackColor]};
    NSSize textSize = [text sizeWithAttributes: attributes];
    if (getenv("OSXER_SYMBOL_DEBUG")) {
        CGAffineTransform m = CGContextGetCTM([[NSGraphicsContext currentContext] graphicsPort]);
        NSLog(@"symbol U+%04X rep %@ font %@ %.1f text %@ ctm a=%.2f d=%.2f", _glyph, NSStringFromSize(size),
              [font fontName], [font pointSize], NSStringFromSize(textSize), m.a, m.d);
    }
    [text drawAtPoint: NSMakePoint((size.width - textSize.width) / 2, (size.height - textSize.height) / 2)
       withAttributes: attributes];
}
@end

// AppKit's standard named images (NSImageName...), which macOS ships as artwork Darling does not
// have: the closest Phosphor glyph. kind 0: template; 1: gray icon (32 pt, not a template);
// 2..5: status lights (green, yellow, red, gray).
typedef struct { const char *name; const char *phosphor; BOOL fill; int kind; CGFloat side; } OSXERNamedImage;
static const OSXERNamedImage OSXERNamedImages[] = {
    {"NSActionTemplate", "gear", NO, 0, 16}, {"NSAddTemplate", "plus", NO, 0, 12},
    {"NSAdvanced", "gear-six", NO, 1, 32}, {"NSBluetoothTemplate", "bluetooth", NO, 0, 16},
    {"NSBookmarksTemplate", "book-open", NO, 0, 16}, {"NSCaution", "warning", YES, 1, 32},
    {"NSColorPanel", "palette", NO, 1, 32}, {"NSColumnViewTemplate", "columns", NO, 0, 16},
    {"NSComputer", "desktop", NO, 1, 32}, {"NSEnterFullScreenTemplate", "arrows-out-simple", NO, 0, 16},
    {"NSEveryone", "users-three", NO, 1, 32}, {"NSExitFullScreenTemplate", "arrows-in-simple", NO, 0, 16},
    {"NSFlowViewTemplate", "cards", NO, 0, 16}, {"NSFolder", "folder", YES, 1, 32},
    {"NSFolderBurnable", "folder", YES, 1, 32}, {"NSFolderSmart", "folder-star", YES, 1, 32},
    {"NSFollowLinkFreestandingTemplate", "arrow-circle-right", YES, 0, 14}, {"NSFontPanel", "text-aa", NO, 1, 32},
    {"NSGoBackTemplate", "caret-left", NO, 0, 12}, {"NSGoForwardTemplate", "caret-right", NO, 0, 12},
    {"NSGoLeftTemplate", "caret-left", NO, 0, 12}, {"NSGoRightTemplate", "caret-right", NO, 0, 12},
    {"NSHomeTemplate", "house", NO, 0, 16}, {"NSIChatTheaterTemplate", "video-camera", NO, 0, 16},
    {"NSIconViewTemplate", "squares-four", NO, 0, 16}, {"NSInfo", "info", YES, 1, 32},
    {"NSInvalidDataFreestandingTemplate", "warning-circle", YES, 0, 14}, {"NSLeftFacingTriangleTemplate", "caret-left", YES, 0, 10},
    {"NSListViewTemplate", "list", NO, 0, 16}, {"NSLockLockedTemplate", "lock", NO, 0, 14},
    {"NSLockUnlockedTemplate", "lock-open", NO, 0, 14}, {"NSMenuCheckmark", "check", NO, 0, 12},
    {"NSMenuMixedState", "minus", NO, 0, 12}, {"NSMenuOnStateTemplate", "check", NO, 0, 12},
    {"NSMenuMixedStateTemplate", "minus", NO, 0, 12}, {"NSMultipleDocuments", "files", NO, 1, 32},
    {"NSNetwork", "network", NO, 1, 32}, {"NSPathTemplate", "path", NO, 0, 16},
    {"NSPreferencesGeneral", "gear", NO, 1, 32}, {"NSQuickLookTemplate", "eye", NO, 0, 18},
    {"NSRefreshFreestandingTemplate", "arrow-clockwise", NO, 0, 14}, {"NSRefreshTemplate", "arrow-clockwise", NO, 0, 14},
    {"NSRemoveTemplate", "minus", NO, 0, 12}, {"NSRevealFreestandingTemplate", "arrow-circle-right", YES, 0, 14},
    {"NSRightFacingTriangleTemplate", "caret-right", YES, 0, 10}, {"NSShareTemplate", "export", NO, 0, 16},
    {"NSSlideshowTemplate", "presentation", NO, 0, 16}, {"NSSmartBadgeTemplate", "gear", YES, 0, 14},
    {"NSStatusAvailable", "circle", YES, 2, 16}, {"NSStatusNone", "circle", YES, 5, 16},
    {"NSStatusPartiallyAvailable", "circle", YES, 3, 16}, {"NSStatusUnavailable", "circle", YES, 4, 16},
    {"NSStopProgressFreestandingTemplate", "x-circle", YES, 0, 14}, {"NSStopProgressTemplate", "x", NO, 0, 12},
    {"NSTouchBarBookmarksTemplate", "book-open", NO, 0, 16}, {"NSTrashEmpty", "trash", NO, 1, 32},
    {"NSTrashFull", "trash", YES, 1, 32}, {"NSUser", "user", NO, 1, 32},
    {"NSUserAccounts", "users-three", NO, 1, 32}, {"NSUserGroup", "users", NO, 1, 32},
    {"NSUserGuest", "user", NO, 1, 32},
};

@interface OSXERColoredDrawer : OSXERSymbolDrawer {
@public
    NSColor *_color;
}
@end

@implementation OSXERColoredDrawer
- (void) drawSymbol: (NSCustomImageRep *) rep {
    OSXERRegisterPhosphor();
    NSSize size = [rep size];
    NSFont *font = [NSFont fontWithName: _fill ? @"Phosphor-Fill" : @"Phosphor" size: floor(size.height * 0.9)];
    if (!font) return;
    NSString *text = [NSString stringWithCharacters: &_glyph length: 1];
    NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: _color};
    NSSize textSize = [text sizeWithAttributes: attributes];
    [text drawAtPoint: NSMakePoint((size.width - textSize.width) / 2, (size.height - textSize.height) / 2)
       withAttributes: attributes];
}
- (void) dealloc { [_color release]; [super dealloc]; }
@end

NSImageRep *OSXERSymbolRep(unichar glyph, BOOL fill, NSSize size);

// Stand-in for a standard named image, or nil.
NSImage *OSXERStandardImageNamed(NSString *name) {
    if ([name isEqualToString: @"NSApplicationIcon"]) {
        NSString *file = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleIconFile"];
        if (![file length]) return nil;
        NSString *path = [[NSBundle mainBundle] pathForResource: [file stringByDeletingPathExtension]
                                                         ofType: [[file pathExtension] length] ? [file pathExtension] : @"icns"];
        return path ? [[[NSImage alloc] initWithContentsOfFile: path] autorelease] : nil;
    }
    const char *wanted = [name UTF8String];
    for (size_t i = 0; wanted && i < sizeof OSXERNamedImages / sizeof *OSXERNamedImages; i++) {
        const OSXERNamedImage *entry = &OSXERNamedImages[i];
        if (strcmp(entry->name, wanted) != 0) continue;
        unsigned glyph = OSXERGlyphNamed([NSString stringWithUTF8String: entry->phosphor]);
        if (!glyph) return nil;
        NSSize size = NSMakeSize(entry->side, entry->side);
        NSImageRep *rep;
        if (entry->kind == 0) {
            rep = OSXERSymbolRep((unichar) glyph, entry->fill, size);
        } else {
            OSXERColoredDrawer *drawer = [[OSXERColoredDrawer new] autorelease];
            drawer->_glyph = (unichar) glyph;
            drawer->_fill = entry->fill;
            NSColor *colors[] = {nil, [NSColor colorWithCalibratedWhite: 0.45 alpha: 1],
                [NSColor colorWithCalibratedRed: 0.20 green: 0.78 blue: 0.35 alpha: 1],
                [NSColor colorWithCalibratedRed: 1.00 green: 0.80 blue: 0.00 alpha: 1],
                [NSColor colorWithCalibratedRed: 1.00 green: 0.23 blue: 0.19 alpha: 1],
                [NSColor colorWithCalibratedWhite: 0.60 alpha: 1]};
            drawer->_color = [colors[entry->kind] retain];
            NSCustomImageRep *custom = [[[NSCustomImageRep alloc] initWithDrawSelector: @selector(drawSymbol:) delegate: drawer] autorelease];
            objc_setAssociatedObject(custom, @selector(drawSymbol:), drawer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [custom setSize: size];
            rep = custom;
        }
        NSImage *image = [[[NSImage alloc] initWithSize: size] autorelease];
        [image addRepresentation: rep];
        [image setTemplate: entry->kind == 0];
        return image;
    }
    return nil;
}

// A custom representation drawing the symbol; the drawer stays alive with it.
NSImageRep *OSXERSymbolRep(unichar glyph, BOOL fill, NSSize size) {
    OSXERSymbolDrawer *drawer = [[OSXERSymbolDrawer new] autorelease];
    drawer->_glyph = glyph;
    drawer->_fill = fill;
    NSCustomImageRep *rep = [[[NSCustomImageRep alloc] initWithDrawSelector: @selector(drawSymbol:) delegate: drawer] autorelease];
    objc_setAssociatedObject(rep, @selector(drawSymbol:), drawer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [rep setSize: size];
    return rep;
}
