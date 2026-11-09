// OSXER TEXTEDIT LOOK (memory): ownership regressions, no sanitizer required.
// Exercise independently owned fonts/cells across pool drains and destruction
// in both orders. Run only via osxer-font-overrelease.sh inside Darling.
#import <AppKit/AppKit.h>
#import "../AppKit/NSTextView.subproj/NSUndoTextOperation.h"
#include <stdio.h>
#include <stdlib.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); exit(1); } } while (0)

// Existing Cocotron initializer: force distinct instances of the same request
// to exercise the cache invariant even when the factory reuses live fonts.
@interface NSFont (MemoryRegression)
- (id) initWithName: (NSString *) name size: (CGFloat) size;
@end

static unsigned deadScrolls, deadRulers, deadTextViews, deadUndoManagers, deadImages;
@interface MemoryScrollView : NSScrollView @end
@implementation MemoryScrollView
- (void) dealloc { deadScrolls++; [super dealloc]; }
@end
@interface MemoryRulerView : NSRulerView @end
@implementation MemoryRulerView
- (void) dealloc { deadRulers++; [super dealloc]; }
@end
@interface MemoryTextView : NSTextView @end
@implementation MemoryTextView
- (void) dealloc { deadTextViews++; [super dealloc]; }
@end
@interface MemoryUndoManager : NSUndoManager @end
@implementation MemoryUndoManager
- (void) dealloc { deadUndoManagers++; [super dealloc]; }
@end
@interface MemoryImage : NSImage @end
@implementation MemoryImage
- (void) dealloc { deadImages++; [super dealloc]; }
@end

// A keyed archive fixture for the existing normal-image decoding path. Its
// objects are borrowed, as with decodeObjectForKey:, and outlive the decoder.
@interface MemoryCellCoder : NSCoder { NSImage *_fixtureImage; }
- (id) initWithImage: (NSImage *) image;
@end
@implementation MemoryCellCoder
- (id) initWithImage: (NSImage *) image { self = [super init]; _fixtureImage = image; return self; }
- (BOOL) allowsKeyedCoding { return YES; }
- (BOOL) containsValueForKey: (NSString *) key { return NO; }
- (int) decodeIntForKey: (NSString *) key { return 0; }
- (id) decodeObjectForKey: (NSString *) key {
    if ([key isEqual: @"NSNormalImage"]) return _fixtureImage;
    if ([key isEqual: @"NSContents"]) return @"copy";
    return nil;
}
@end

static void checkFontCache(void) {
    // Repeated creation from an alias and a fontconfig request used to create
    // two equal resolved names. Destroying the second removed the first slot.
    for (unsigned order = 0; order < 2; order++) {
        for (unsigned iteration = 0; iteration < 16; iteration++) {
            NSAutoreleasePool *pool = [NSAutoreleasePool new];
            CGFloat size = 21.125 + iteration;
            NSFont *a = [[NSFont fontWithName: @"Noto Sans" size: size] retain];
            NSFont *b = [[NSFont fontWithName: @"Noto Sans:style=Regular" size: size] retain];
            CHECK(a && b && [[a fontName] isEqual: [b fontName]]);
            [pool drain];
            pool = [NSAutoreleasePool new];
            NSFont *survivor = order ? b : a;
            [(order ? a : b) release];
            CHECK([[survivor fontName] length] && [survivor ascender] > 0);
            NSFont *again = [NSFont fontWithName: @"Noto Sans" size: size];
            CHECK([[again fontName] isEqual: [survivor fontName]]);
            [survivor release];
            [pool drain];
        }
    }
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSFont *a = [[NSFont alloc] initWithName: @"Noto Sans" size: 39.125];
    NSFont *b = [[NSFont alloc] initWithName: @"Noto Sans" size: 39.125];
    CHECK(a && b && a != b);
    [b release];
    CHECK([NSFont fontWithName: @"Noto Sans" size: 39.125] == a);
    [a release];
    // Decoding releases a placeholder before returning the resolved font.
    [[NSFont alloc] release];
    [pool drain];

    pool = [NSAutoreleasePool new];
    NSFont *owned = [[NSFont fontWithName: @"Noto Sans" size: 41.125] retain];
    [pool drain];
    pool = [NSAutoreleasePool new];
    NSFont *borrowed = [NSFont fontWithName: @"Noto Sans" size: 41.125];
    [owned release];
    CHECK([borrowed pointSize] == 41.125 && [[borrowed fontName] length]);
    [pool drain];
}

static void checkCells(void) {
    for (unsigned order = 0; order < 2; order++) {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        MemoryImage *image = [[MemoryImage alloc] initWithSize: NSMakeSize(3, 3)];
        MemoryCellCoder *coder = [[MemoryCellCoder alloc] initWithImage: image];
        NSButtonCell *cell = [[NSButtonCell alloc] initWithCoder: coder];
        [coder release];
        [image release];
        [cell setIdentifier: [NSString stringWithFormat: @"owned-cell-identifier-%u", order]];
        [cell setFont: [NSFont systemFontOfSize: 11]];
        [cell setControlSize: NSSmallControlSize];
        NSButtonCell *copy = [cell copy];
        [pool drain];
        pool = [NSAutoreleasePool new];
        NSButtonCell *survivor = order ? copy : cell;
        [(order ? cell : copy) release];
        CHECK(deadImages == order);
        CHECK([[survivor identifier] hasPrefix: @"owned-cell-identifier-"]);
        CHECK([[survivor font] pointSize] == 11);
        [survivor setFont: [survivor font]];
        [survivor setControlSize: NSSmallControlSize];
        [survivor release];
        [pool drain];
        CHECK(deadImages == order + 1);
    }
}

static void checkRulersAndInspector(void) {
    for (unsigned iteration = 0; iteration < 8; iteration++) {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        MemoryScrollView *scroll = [[MemoryScrollView alloc] initWithFrame: NSMakeRect(0,0,601,400)];
        MemoryTextView *text = [[MemoryTextView alloc] initWithFrame: NSMakeRect(0,0,601,350)];
        [text setUsesInspectorBar: YES];
        [text setRichText: YES];
        [scroll setDocumentView: text];
        MemoryRulerView *ruler = [[MemoryRulerView alloc] initWithScrollView: scroll orientation: NSHorizontalRuler];
        [scroll setHorizontalRulerView: ruler];
        [scroll setRulersVisible: YES];
        NSImage *image = [[NSImage alloc] initWithSize: NSMakeSize(3,3)];
        NSRulerMarker *marker = [[NSRulerMarker alloc] initWithRulerView: ruler
            markerLocation: 12 image: image imageOrigin: NSZeroPoint];
        [image release];
        [marker setImage: [marker image]];
        CHECK([[marker image] size].width == 3);
        [ruler addMarker: marker];
        [marker release];
        marker = [marker copy];
        [marker release];
        [ruler setMarkers: [ruler markers]];
        CHECK([[ruler markers] count] == 1);
        NSView *accessory = [[NSView alloc] initWithFrame: NSZeroRect];
        [ruler setAccessoryView: accessory];
        [accessory release];
        [ruler setAccessoryView: [ruler accessoryView]];
        CHECK([ruler accessoryView] != nil);
        [text release];
        [pool drain];
        pool = [NSAutoreleasePool new];
        for (NSView *view in [scroll subviews]) {
            if (NSHeight([view frame]) == 29) {
                for (NSControl *control in [view subviews]) {
                    if ([control font]) CHECK([[[control font] fontName] length]);
                }
            }
        }
        [scroll release];
        CHECK([ruler scrollView] == nil);
        [ruler release];
        [pool drain];
        CHECK(deadScrolls == iteration + 1);
        CHECK(deadRulers == iteration + 1);
        CHECK(deadTextViews == iteration + 1);
    }
}

static void checkUndoOwnership(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    MemoryUndoManager *undo = [MemoryUndoManager new];
    [undo setGroupsByEvent: NO];
    NSTextStorage *storage = [[NSTextStorage alloc] initWithString: @"format"];
    NSLayoutManager *layout = [NSLayoutManager new];
    [storage addLayoutManager: layout];
    [storage addAttribute: NSFontAttributeName value: [NSFont systemFontOfSize: 12]
        range: NSMakeRange(0,6)];
    [undo beginUndoGrouping];
    NSUndoSetAttributes *operation = [[NSUndoSetAttributes alloc]
        initWithAffectedRange: NSMakeRange(0,6) layoutManager: layout undoManager: undo];
    [[undo prepareWithInvocationTarget: operation] undoRedo: storage];
    [operation release];
    [undo endUndoGrouping];
    [storage release];
    [layout release];
    [undo release];
    [pool drain];
    CHECK(deadUndoManagers == 1);
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    [NSApplication sharedApplication];
    checkFontCache();
    checkCells();
    checkRulersAndInspector();
    checkUndoOwnership();
    [pool drain];
    puts("PASS: font cache, copied cells, pool drains, ruler/inspector teardown and undo ownership");
    return 0;
}
