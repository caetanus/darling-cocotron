// OSXER FOCUS (regression) / OSXER BIGSUR DARK (regression).
// Public contracts: NSWindow.makeKeyWindow/isKeyWindow, NSApplication.appearance,
// NSAppearance.currentDrawingAppearance and semantic NSColor resolution.
// https://developer.apple.com/documentation/appkit/nswindow/makekey()
// https://developer.apple.com/documentation/appkit/nsapplication/appearance
// The private style query tests the implementation of the supplied macOS 15
// light-focus-window.png observation, without inspecting application contents.
#import <AppKit/AppKit.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

@class CGWindow;
@interface NSWindow (FocusTestBackend)
- (CGWindow *) platformWindow;
@end
@interface NSObject (FocusTestStyle)
- (id) graphicsStyle;
- (BOOL) cellHasFocus: (NSCell *) cell;
- (NSColor *) tableTextColor: (NSTableView *) table row: (NSInteger) row;
- (NSColor *) tableSelectionTextColor: (NSTableView *) table;
@end

static void expect(BOOL condition, const char *message) {
    if (!condition) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}

// Deliberately acknowledge no native focus event. This isolates the contract
// from the compositor, including a WM that defers/denies input focus entirely.
@interface DeferredNativeFocus : NSProxy {
    id _backing;
@public
    NSUInteger requests;
}
- (id) initWithTarget: (id) target;
- (void) makeKey;
@end
@implementation DeferredNativeFocus
- (id) initWithTarget: (id) target {
    _backing = [target retain];
    return self;
}
- (void) makeKey { requests++; }
// Field-editor setup may ask the platform for a drawing context. Keep every
// operation except input-focus acquisition available to the normal window.
- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector {
    return [_backing methodSignatureForSelector: selector];
}
- (void) forwardInvocation: (NSInvocation *) invocation {
    [invocation invokeWithTarget: _backing];
}
- (void) dealloc { [_backing release]; [super dealloc]; }
@end

@interface FocusWindow : NSWindow {
@public
    DeferredNativeFocus *deferredFocus;
    NSUInteger keyNotifications;
}
- (void) becameKey: (NSNotification *) notification;
@end
@implementation FocusWindow
- (CGWindow *) platformWindow {
    return deferredFocus ? (CGWindow *)deferredFocus : [super platformWindow];
}
- (void) becameKey: (NSNotification *) notification { keyNotifications++; }
@end

static unsigned rgb(NSColor *color) {
    CGFloat r, g, b, a;
    NSColor *converted = [color colorUsingColorSpaceName: NSDeviceRGBColorSpace];
    expect(converted != nil, "semantic colour converts to RGB");
    [converted getRed: &r green: &g blue: &b alpha: &a];
    return ((unsigned)lround(r*255) << 16) | ((unsigned)lround(g*255) << 8) | (unsigned)lround(b*255);
}

static void appearanceTests(BOOL initialDark) {
    NSAppearance *light = [NSAppearance appearanceNamed: NSAppearanceNameAqua];
    NSAppearance *dark = [NSAppearance appearanceNamed: NSAppearanceNameDarkAqua];
    expect(light && dark && light != dark, "distinct named appearances");
    expect([[dark name] isEqualToString: NSAppearanceNameDarkAqua], "Dark Aqua has a name");
    expect([NSAppearance appearanceNamed: nil] == nil, "nil name rejected");
    expect([NSAppearance appearanceNamed: @"OSXERUnknownAppearance"] == nil, "unknown name rejected");
    expect([NSApp appearance] == nil, "default application appearance is nil");
    expect([[[NSApp effectiveAppearance] name] isEqualToString:
            initialDark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua], "env/default selection");

    [NSApp setAppearance: light];
    NSColor *background = [[NSColor windowBackgroundColor] retain];
    NSColor *ink = [[NSColor textColor] retain];
    NSColor *accent = [[NSColor controlAccentColor] retain];
    NSColor *explicitColor = [[NSColor colorWithSRGBRed: .2 green: .3 blue: .4 alpha: 1] retain];
    unsigned explicitRGB = rgb(explicitColor);
    expect(rgb(background) == 0xF6F6F6, "measured light background");
    expect(rgb(ink) == 0x262626, "measured light ink");
    expect(rgb(accent) == 0x007AFF, "light accent");
    NSWindow *window = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 220, 120)
            styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: YES];
    NSTextField *field = [[NSTextField alloc] initWithFrame: NSMakeRect(10, 10, 138, 24)];
    [field setBezeled: YES];
    [[window contentView] addSubview: field];

    [NSApp setAppearance: dark];
    // OSXER BIGSUR DARK (calibration regression): macOS 15 dark-window.png,
    // window (10,100), field ink (207,210), slider accent (410,245).
    expect(rgb(background) == 0x282828 && rgb(ink) == 0xE1E1E1, "measured retained Dark Aqua colours");
    expect(rgb(accent) == 0x177BE5, "measured retained Dark Aqua accent");
    expect(rgb([NSColor controlBackgroundColor]) == 0x1E1E1E, "table row (100,380)");
    expect(rgb([NSColor textBackgroundColor]) == 0x333333, "field fill (170,216)");
    expect(rgb([NSColor controlColor]) == 0x5E5E5E, "normal button (150,48)");
    expect(rgb([NSColor disabledControlTextColor]) == 0x626262, "disabled field ink (336,210)");
    expect(rgb([NSColor unemphasizedSelectedContentBackgroundColor]) == 0x464646,
            "unemphasized table selection (100,400)");
    expect(rgb([NSColor colorWithCatalogName: @"System" colorName: @"focusRing"]) == 0x216993,
            "focused dark-window ring (15,210)");
    NSTableView *table = [[NSTableView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)];
    [table setUsesAlternatingRowBackgroundColors: YES];
    id tableStyle = [table graphicsStyle];
    expect(rgb([tableStyle tableTextColor: table row: 0]) == 0xDEDEDE, "normal row ink (26,378)");
    expect(rgb([tableStyle tableTextColor: table row: 1]) == 0xDFDFDF, "alternate row ink (36,444)");
    expect(rgb([tableStyle tableSelectionTextColor: table]) == 0xE3E3E3, "unemphasized row ink (34,400)");
    [table setUsesAlternatingRowBackgroundColors: NO];
    expect(rgb([tableStyle tableTextColor: table row: 1]) == 0xDEDEDE, "unstriped odd row uses normal ink");
    expect(rgb([window backgroundColor]) == rgb(background), "existing window follows application");
    expect(CGColorEqualToColor([background CGColor], [[NSColor windowBackgroundColor] CGColor]),
            "CGColor and NSColor resolve the same appearance");
    expect(rgb(explicitColor) == explicitRGB, "explicit RGB colour preserved");
    NSTextView *editor = [[NSTextView alloc] initWithFrame: NSMakeRect(0, 0, 100, 20)];
    [[field cell] setUpFieldEditorAttributes: editor];
    expect(rgb([editor backgroundColor]) == rgb([NSColor textBackgroundColor]), "editor background follows field default");
    expect(rgb([editor textColor]) == rgb(ink), "editor ink follows field default");

    [light performAsCurrentDrawingAppearance: ^{
        expect(rgb(background) == 0xF6F6F6, "drawing appearance overrides application");
        [dark performAsCurrentDrawingAppearance: ^{
            expect(rgb(background) != 0xF6F6F6, "nested drawing appearance");
        }];
        expect(rgb(background) == 0xF6F6F6, "outer drawing appearance restored");
    }];
    expect(rgb(background) != 0xF6F6F6, "application appearance restored");
    [NSApp setAppearance: light];
    expect(rgb(background) == 0xF6F6F6 && rgb(ink) == 0x262626, "retained colours return to Light");
    expect(rgb([editor backgroundColor]) == 0xFFFFFF, "existing editor returns to Light");
    expect(rgb([tableStyle tableTextColor: table row: 0]) == 0x262626, "existing table returns to Light");
    [NSApp setAppearance: nil];
    expect([[[NSApp effectiveAppearance] name] isEqualToString:
            initialDark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua], "nil restores env/default");
    [editor release]; [field release]; [window release];
    [table release];
    [background release]; [ink release]; [accent release]; [explicitColor release];
}

// OSXER BIGSUR DARK (gallery entry point): reproduce gallery/ref/main.m's
// public, dynamically dispatched calls. The library need not know GALLERY_*.
static void galleryAppearanceTests(void) {
    if (![[[NSProcessInfo processInfo] environment][@"GALLERY_APPEARANCE"] isEqualToString: @"dark"])
        return;
    NSColor *background = [[NSColor windowBackgroundColor] retain];
    id dark = [NSClassFromString(@"NSAppearance") performSelector: @selector(appearanceNamed:)
                                                     withObject: @"NSAppearanceNameDarkAqua"];
    expect(dark != nil && [NSApp respondsToSelector: @selector(setAppearance:)], "gallery appearance entry point available");
    [NSApp performSelector: @selector(setAppearance:) withObject: dark];
    expect(rgb(background) == 0x282828, "gallery call overrides Light env/default, including retained colours");
    [NSApp setAppearance: nil];
    [background release];
}

static FocusWindow *focusWindow(void) {
    FocusWindow *window = [[FocusWindow alloc] initWithContentRect: NSMakeRect(0, 0, 220, 120)
            styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: YES];
    window->deferredFocus = [[DeferredNativeFocus alloc] initWithTarget: [window platformWindow]];
    [[NSNotificationCenter defaultCenter] addObserver: window selector: @selector(becameKey:)
            name: NSWindowDidBecomeKeyNotification object: window];
    return window;
}

static void focusTests(void) {
    FocusWindow *window = focusWindow();
    NSTextField *field = [[NSTextField alloc] initWithFrame: NSMakeRect(10, 10, 138, 24)];
    [field setBezeled: YES]; [field setEditable: YES]; [field setSelectable: YES];
    [[window contentView] addSubview: field];
    [window setInitialFirstResponder: field];
    [window makeKeyWindow];
    expect([window isKeyWindow], "makeKeyWindow synchronously establishes key state");
    expect(window->deferredFocus->requests == 1, "one native request");
    expect(window->keyNotifications == 1, "one logical key notification");
    expect(![NSApp isActive], "test has no native activation event");
    expect([window makeFirstResponder: field], "field accepts first responder");
    [[field cell] setShowsFirstResponder: NO];
    id style = [field graphicsStyle];
    expect([style respondsToSelector: @selector(cellHasFocus:)], "Big Sur style installed");
    expect([style cellHasFocus: [field cell]], "key field has focus without active app or showsFirstResponder");
    [window becomeKeyWindow];
    expect(window->keyNotifications == 1 && window->deferredFocus->requests == 1,
            "delayed activation neither renotifies nor requests focus");
    [field setEnabled: NO];
    expect(![style cellHasFocus: [field cell]], "disabled field has no ring");
    [field setEnabled: YES]; [[field cell] setFocusRingType: NSFocusRingTypeNone];
    expect(![style cellHasFocus: [field cell]], "explicit ring suppression");
    [[field cell] setFocusRingType: NSFocusRingTypeExterior];
    FocusWindow *other = focusWindow();
    [other makeKeyWindow];
    expect(![window isKeyWindow] && [other isKeyWindow], "only one logical key window");
    expect(![style cellHasFocus: [field cell]], "non-key field has no ring");
    [window makeKeyWindow];
    expect([style cellHasFocus: [field cell]], "ring returns with key status");
    [window resignKeyWindow];
    expect(![window isKeyWindow] && ![style cellHasFocus: [field cell]], "resignation removes ring");
    for (FocusWindow *w in [NSArray arrayWithObjects: window, other, nil]) {
        [[NSNotificationCenter defaultCenter] removeObserver: w];
        [w->deferredFocus release]; w->deferredFocus = nil;
        [w release];
    }
    [field release];
}

int main(int argc, char **argv) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        BOOL initialDark = [[[NSProcessInfo processInfo] environment][@"OSXER_TEST_EXPECT"] isEqualToString: @"dark"];
        appearanceTests(initialDark);
        galleryAppearanceTests();
        focusTests();
        puts("PASS: osxer-focus-dark");
    }
    return 0;
}
