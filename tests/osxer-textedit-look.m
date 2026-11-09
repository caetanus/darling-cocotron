// OSXER TEXTEDIT LOOK (regression). Public contracts:
// https://developer.apple.com/documentation/appkit/nstextview/usesinspectorbar
// https://developer.apple.com/documentation/appkit/nsfont/fontname
// https://developer.apple.com/documentation/appkit/nsparagraphstyle
// Reference geometry: gallery/ref/textedit/macos15-textedit.png, 1x.
// Run only through osxer-textedit-look.sh in a Darling prefix with a display.
#import <AppKit/AppKit.h>
#import <CoreText/CoreText.h>
#include <stdio.h>
#include <stdlib.h>

#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); exit(1); } } while (0)

@interface LookTextView : NSTextView { NSUndoManager *_testUndo; }
@end
@implementation LookTextView
- (NSUndoManager *) undoManager {
    if (!_testUndo) { _testUndo = [NSUndoManager new]; [_testUndo setGroupsByEvent: NO]; }
    return _testUndo;
}
- (void) dealloc { [_testUndo release]; [super dealloc]; }
@end
@interface RejectFormatting : NSObject
@end
@implementation RejectFormatting
- (BOOL) textView: (NSTextView *) view shouldChangeTextInRange: (NSRange) range replacementString: (NSString *) replacement { return NO; }
@end

static NSControl *control(NSView *bar, NSString *title) {
    for (NSControl *c in [bar subviews]) if ([[c toolTip] isEqual: title]) return c;
    CHECK(NO); return nil;
}
static void invoke(NSControl *c) { CHECK([c isEnabled]); [c sendAction: [c action] to: [c target]]; }
static NSFont *fontAt(NSTextView *v, NSUInteger index) {
    return [[v textStorage] attribute: NSFontAttributeName atIndex: index effectiveRange: NULL];
}
static NSParagraphStyle *styleAt(NSTextView *v, NSUInteger index) {
    return [[v textStorage] attribute: NSParagraphStyleAttributeName atIndex: index effectiveRange: NULL];
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    [NSApplication sharedApplication];
    NSFontManager *fm = [NSFontManager sharedFontManager];
    // A legacy fontconfig request must not become an NSFont name or an RTF face.
    NSFont *font = [NSFont fontWithName: @"Noto Sans:style=Regular" size: 12];
    CHECK(font && [[font fontName] length] && [[font familyName] length]);
    CHECK([[font fontName] rangeOfString: @":"].location == NSNotFound);
    CHECK([[font familyName] rangeOfString: @":"].location == NSNotFound);
    NSFont *reopened = [NSFont fontWithName: [font fontName] size: 12];
    CHECK([[font fontName] isEqual: [reopened fontName]]);
    CHECK([[font familyName] isEqual: [reopened familyName]]);
    NSFont *medium = [NSFont fontWithName: @"Noto Sans:style=Medium" size: 12];
    CHECK([[medium fontName] rangeOfString: @":"].location == NSNotFound);
    NSFont *plainMedium = [fm convertFont: medium toNotHaveTrait: NSBoldFontMask | NSItalicFontMask];
    if (!([fm traitsOfFont: medium] & (NSBoldFontMask | NSItalicFontMask)))
        CHECK([[plainMedium fontName] isEqual: [medium fontName]]);
    NSFont *boldFont = [fm convertFont: font toHaveTrait: NSBoldFontMask];
    NSFont *italicFont = [fm convertFont: font toHaveTrait: NSItalicFontMask];
    CHECK([fm traitsOfFont: boldFont] & NSBoldFontMask);
    CHECK([fm traitsOfFont: italicFont] & NSItalicFontMask);
    CHECK(!([fm traitsOfFont: [fm convertFont: boldFont toNotHaveTrait: NSBoldFontMask]] & NSBoldFontMask));

    NSWindow *window = [[NSWindow alloc] initWithContentRect: NSMakeRect(0,0,601,400)
        styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO];
    NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame: NSMakeRect(0,0,601,400)] autorelease];
    [window setContentView: scroll];
    LookTextView *text = [[[LookTextView alloc] initWithFrame: NSMakeRect(0,0,601,350)] autorelease];
    [text setRichText: YES];
    [text setUsesInspectorBar: YES]; // install before enclosure
    [scroll setDocumentView: text];
    [text setAllowsUndo: NO];
    [text setString: @"first\nsecond\n"];
    [text setFont: font];
    [text setSelectedRange: NSMakeRange(0,5)];
    NSView *bar = nil;
    for (NSView *v in [scroll subviews])
        if (NSHeight([v frame]) == 29 && [[v subviews] count] >= 10) bar=v;
    CHECK(bar);
    CHECK(fabs(NSMinY([[scroll contentView] frame])-29) < 0.1);
    [text setUsesRuler: YES]; [text setRulerVisible: YES];
    CHECK(NSMinY([[scroll horizontalRulerView] frame]) == 29);
    CHECK(NSMinY([[scroll contentView] frame]) == 60);
    [text setRulerVisible: NO];
    CHECK([bar superview] == scroll && NSMinY([[scroll contentView] frame]) == 29);
    [text setUsesInspectorBar: NO]; CHECK([bar superview] == nil);
    CHECK(NSMinY([[scroll contentView] frame]) == 0);
    [text setUsesInspectorBar: YES]; CHECK([bar superview] == scroll);
    [scroll setFrameSize: NSMakeSize(760,400)]; CHECK(NSWidth([bar frame]) == 760);

    NSPopUpButton *family = (id)control(bar,@"Font family");
    NSString *otherFamily = nil;
    for (NSString *candidate in [fm availableFontFamilies])
        if (![candidate isEqual: [font familyName]]) { otherFamily = candidate; break; }
    CHECK(otherFamily);
    [family selectItemWithTitle: otherFamily]; invoke(family);
    CHECK([[fontAt(text,0) familyName] isEqual: otherFamily]);
    CHECK([[fontAt(text,6) familyName] isEqual: [font familyName]]);
    [family selectItemWithTitle: [font familyName]]; invoke(family);
    NSPopUpButton *face = (id)control(bar,@"Typeface");
    CHECK([face numberOfItems] > 1);
    [face selectItemAtIndex: 1];
    NSString *selectedFace = [[[face selectedItem] representedObject] copy];
    invoke(face); CHECK([[fontAt(text,0) fontName] isEqual: selectedFace]); [selectedFace release];
    [text setFont: font]; [text setSelectedRange: NSMakeRange(0,5)];
    NSComboBox *size = (id)control(bar,@"Font size");
    [size setStringValue: @"18"]; invoke(size);
    CHECK([fontAt(text,0) pointSize] == 18 && [fontAt(text,6) pointSize] == 12);
    [size setStringValue: @"-2"]; invoke(size); CHECK([fontAt(text,0) pointSize] == 18);
    NSButton *bold = (id)control(bar,@"Bold");
    [bold setState: NSOnState]; invoke(bold); CHECK([fm traitsOfFont: fontAt(text,0)] & NSBoldFontMask);
    [bold setState: NSOffState]; invoke(bold); CHECK(!([fm traitsOfFont: fontAt(text,0)] & NSBoldFontMask));
    NSButton *italic = (id)control(bar,@"Italic");
    [italic setState: NSOnState]; invoke(italic); CHECK([fm traitsOfFont: fontAt(text,0)] & NSItalicFontMask);
    NSButton *underline = (id)control(bar,@"Underline");
    [underline setState: NSOnState]; invoke(underline);
    CHECK([[[text textStorage] attribute: NSUnderlineStyleAttributeName atIndex: 0 effectiveRange: NULL] intValue] == 1);
    [underline setState: NSOffState]; invoke(underline);
    CHECK(![[text textStorage] attribute: NSUnderlineStyleAttributeName atIndex: 0 effectiveRange: NULL]);

    NSSegmentedControl *alignment = (id)control(bar,@"Alignment");
    [alignment setSelectedSegment: 2]; invoke(alignment);
    CHECK([styleAt(text,0) alignment] == NSRightTextAlignment);
    CHECK(!styleAt(text,6) || [styleAt(text,6) alignment] != NSRightTextAlignment);
    [text setSelectedRange: NSMakeRange(0,0)];
    [alignment setSelectedSegment: 0]; invoke(alignment);
    [text setRulerVisible: YES]; [text updateRuler];
    NSRulerView *ruler = [scroll horizontalRulerView];
    CHECK([[ruler markers] count] == 15);
    NSRulerMarker *first = [[ruler markers] objectAtIndex: 2];
    CHECK(![first isRemovable]); CHECK([[first image] size].width == 9);
    NSRulerMarker *head = [[ruler markers] objectAtIndex: 0];
    CHECK(!NSIntersectsRect([first imageRectInRuler], [head imageRectInRuler]));
    [first setMarkerLocation: [ruler originOffset]+20];
    [text rulerView: ruler didMoveMarker: first];
    CHECK([styleAt(text,0) firstLineHeadIndent] == 20);
    NSLayoutManager *layout = [text layoutManager];
    [layout glyphRangeForTextContainer: [text textContainer]];
    NSRect firstLine = [layout lineFragmentRectForGlyphAtIndex: 0 effectiveRange: NULL];
    CHECK(firstLine.origin.x >= 20);
    NSPopUpButton *spacing = (id)control(bar,@"Line spacing");
    [spacing selectItemAtIndex: 2]; invoke(spacing);
    [layout glyphRangeForTextContainer: [text textContainer]];
    NSRect doubleLine = [layout lineFragmentRectForGlyphAtIndex: 0 effectiveRange: NULL];
    CHECK(doubleLine.size.height >= firstLine.size.height*1.9);

    // A rejected edit must leave both text and typing attributes unchanged.
    RejectFormatting *reject = [RejectFormatting new];
    [text setDelegate: reject];
    CGFloat oldSize = [fontAt(text,0) pointSize];
    [size setStringValue: @"32"]; invoke(size); CHECK([fontAt(text,0) pointSize] == oldSize);
    [text setDelegate: nil]; [reject release];
    [text setSelectedRange: NSMakeRange(0,5)];
    [text setAllowsUndo: YES];
    [[text undoManager] beginUndoGrouping];
    [size setStringValue: @"24"]; invoke(size);
    [[text undoManager] endUndoGrouping];
    CHECK([[text undoManager] canUndo]); [[text undoManager] undo];
    CHECK([fontAt(text,0) pointSize] == oldSize);
    CHECK([size doubleValue] == oldSize);
    [text setAllowsUndo: NO];

    [text setSelectedRange: NSMakeRange([[text string] length],0)];
    [size setStringValue: @"15"]; invoke(size); // EOF: no out-of-range read
    CHECK([[[text typingAttributes] objectForKey: NSFontAttributeName] pointSize] == 15);
    [text setString: @""]; [text setSelectedRange: NSMakeRange(0,0)];
    [size setStringValue: @"20"]; invoke(size); // empty: typing only
    CHECK([[[text typingAttributes] objectForKey: NSFontAttributeName] pointSize] == 20);
    CHECK([[text string] length] == 0);
    [underline setState: NSOnState]; invoke(underline);
    CHECK([[[text typingAttributes] objectForKey: NSUnderlineStyleAttributeName] intValue] == 1);
    [underline setState: NSOffState]; invoke(underline);
    CHECK(![[text typingAttributes] objectForKey: NSUnderlineStyleAttributeName]);

    NSAttributedString *sample = [[[NSAttributedString alloc] initWithString: @"Font {roundtrip} é"
        attributes: @{NSFontAttributeName: font}] autorelease];
    NSData *rtf = [sample RTFFromRange: NSMakeRange(0,[sample length]) documentAttributes: @{}];
    NSString *rtfText = [[[NSString alloc] initWithData: rtf encoding: NSASCIIStringEncoding] autorelease];
    CHECK([rtfText rangeOfString: @"{\\fonttbl {\\f0"].location != NSNotFound);
    CHECK([rtfText rangeOfString: @":style="].location == NSNotFound);
    CHECK([rtfText rangeOfString: @":file="].location == NSNotFound);
    NSAttributedString *read = [[[NSAttributedString alloc] initWithRTF: rtf documentAttributes: NULL] autorelease];
    CHECK([[sample string] isEqual: [read string]]);
    CHECK([[[read attribute: NSFontAttributeName atIndex:0 effectiveRange:NULL] familyName] isEqual:[font familyName]]);
    CHECK(NSEqualSizes([text textContainerInset], NSZeroSize));
    CHECK([[text textContainer] lineFragmentPadding] == 5);
    NSRect proposed = NSMakeRect(0,0,100,20);
    NSRect available = [[text textContainer] lineFragmentRectForProposedRect: proposed
        sweepDirection: NSLineSweepRight movementDirection: NSLineMovesDown remainingRect: NULL];
    CHECK(NSEqualRects(proposed, available));
    CHECK([NSRulerMarker defaultMarkerImage].size.width == 6);
    [scroll setDocumentView: [[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
    CHECK([bar superview] == nil);
    [window release];
    puts("PASS: inspector lifecycle/editing/undo, ruler/indents/spacing, font identity and RTF");
    [pool drain]; return 0;
}
