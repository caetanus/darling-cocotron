// OSXER TEXTEDIT LOOK (inspector). Geometry measured in the supplied 601x491
// macos15-textedit.png at 1x: strip y28..56 (29 px), controls y33..50 (18 px),
// family x8..105, face x113..209, size x218..259, B/I/U x327..388,
// alignment x397..479, spacing x489..527, list x537..573. Native controls
// inherit the existing Big Sur palette; a narrower window clips trailing items.
#import "NSTextInspectorBar.h"
#import "NSInterfacePart/OSXERSystemPalette.h"
#import <AppKit/AppKit.h>
#import <AppKit/NSStringDrawer.h>

// OSXER TEXTEDIT LOOK R2 (compact cells): the reference controls occupy their
// full 18 px frames. The regular Big Sur bezel's 8 px text insets and 16 px
// blue arrow tiles leave no room for these titles. Keep native cell tracking,
// menus and field editing; only this inspector's presentation is specialized.
static NSColor *InspectorInk(BOOL enabled) {
    return enabled ? (OSXERDarkAppearance() ? [NSColor controlTextColor]
            : [NSColor colorWithCalibratedWhite: 115.0/255 alpha: 1])
            : [NSColor disabledControlTextColor];
}
static void InspectorText(NSString *string, NSFont *font, NSColor *ink,
                          NSRect rect, BOOL centered) {
    if (![string length] || NSIsEmptyRect(rect)) return;
    NSDictionary *attributes = @{NSFontAttributeName: font,
                                 NSForegroundColorAttributeName: ink};
    NSSize size = [string sizeWithAttributes: attributes];
    NSPoint point = NSMakePoint(centered ? floor(NSMidX(rect)-size.width/2) : NSMinX(rect),
                               floor(NSMidY(rect)-size.height/2));
    [NSGraphicsContext saveGraphicsState];
    NSRectClip(rect);
    [string drawAtPoint: point withAttributes: attributes];
    [NSGraphicsContext restoreGraphicsState];
}
static void InspectorBezel(NSRect rect, BOOL pressed) {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(rect, .5, .5)
                                                       xRadius: 3 yRadius: 3];
    [(pressed ? [NSColor selectedControlColor] : [NSColor controlBackgroundColor]) setFill];
    [path fill];
    // Reference rim #F2F2F2, 1 px; no shadow or accent-coloured tile.
    [(OSXERDarkAppearance() ? [NSColor separatorColor]
        : [NSColor colorWithCalibratedWhite: 242.0/255 alpha: 1]) setStroke];
    [path setLineWidth: 1]; [path stroke];
}
static void InspectorChevron(NSPoint center, BOOL up, NSColor *ink) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat direction = up ? -1 : 1;
    [path moveToPoint: NSMakePoint(center.x-2, center.y-direction)];
    [path lineToPoint: NSMakePoint(center.x, center.y+direction)];
    [path lineToPoint: NSMakePoint(center.x+2, center.y-direction)];
    [path setLineWidth: 1]; [path setLineCapStyle: NSRoundLineCapStyle];
    [path setLineJoinStyle: NSRoundLineJoinStyle];
    [ink setStroke]; [path stroke];
}

@interface NSTextInspectorPopupCell : NSPopUpButtonCell
@end
@implementation NSTextInspectorPopupCell
- (NSRect) titleRectForBounds: (NSRect) rect {
    // x494..517 for spacing: 24 px, enough for both "1.0" and "1.15".
    rect.origin.x += 5; rect.size.width = MAX(0, rect.size.width-15);
    return rect;
}
- (void) drawWithFrame: (NSRect) frame inView: (NSView *) view {
    _controlView = view;
    BOOL list = [self imagePosition] == NSImageOnly;
    NSColor *ink = InspectorInk([self isEnabled]);
    if (!list) InspectorBezel(frame, [self isHighlighted]);
    else if ([self isHighlighted]) {
        [[NSColor selectedControlColor] setFill];
        [[NSBezierPath bezierPathWithRoundedRect: frame xRadius: 3 yRadius: 3] fill];
    }
    if (list) {
        // OSXER TEXTEDIT LOOK R2 (list glyph): reference x542..552/y38..45;
        // 3 rows, 1 px bullets, 7 px rules. No font-dependent Unicode icon.
        [ink setFill];
        for (NSInteger row = 0; row < 3; row++) {
            CGFloat y = NSMinY(frame)+5+row*3;
            NSRectFill(NSMakeRect(NSMinX(frame)+5, y, 1, 1));
            NSRectFill(NSMakeRect(NSMinX(frame)+8, y, 7, 1));
        }
        InspectorChevron(NSMakePoint(NSMaxX(frame)-9, NSMidY(frame)), NO, ink);
    } else {
        InspectorText([self titleOfSelectedItem], [self font], ink,
                      [self titleRectForBounds: frame], NO);
        InspectorChevron(NSMakePoint(NSMaxX(frame)-8, NSMidY(frame)-2.5), YES, ink);
        InspectorChevron(NSMakePoint(NSMaxX(frame)-8, NSMidY(frame)+2.5), NO, ink);
    }
}
@end

@interface NSTextInspectorSizeCell : NSComboBoxCell
@end
@implementation NSTextInspectorSizeCell
- (NSRect) buttonRectForBounds: (NSRect) rect {
    // OSXER TEXTEDIT LOOK R2 (size geometry): 42x18 frame at (218,33),
    // 14x14 tile at (245,35), right inset 1; reference ink "12" x225..239.
    return NSMakeRect(NSMaxX(rect)-15, NSMidY(rect)-7, 14, 14);
}
- (NSRect) titleRectForBounds: (NSRect) rect {
    rect.origin.x += 4; rect.size.width = MAX(0, rect.size.width-19);
    CGFloat height = MIN(NSHeight(rect), [[self attributedStringValue] size].height);
    rect.origin.y = floor(NSMidY(rect)-height/2); rect.size.height = height;
    return rect; // also used by NSTextFieldCell's field editor
}
- (void) drawWithFrame: (NSRect) frame inView: (NSView *) view {
    _controlView = view;
    InspectorBezel(frame, NO);
    NSRect button = [self buttonRectForBounds: frame];
    [(OSXERDarkAppearance() ? [NSColor controlColor]
        : [NSColor colorWithCalibratedWhite: _buttonPressed ? .88 : 242.0/255 alpha: 1]) setFill];
    [[NSBezierPath bezierPathWithRoundedRect: button xRadius: 3 yRadius: 3] fill];
    InspectorChevron(NSMakePoint(NSMidX(button), NSMidY(button)), NO, InspectorInk([self isEnabled]));
    InspectorText([self stringValue], [self font], InspectorInk([self isEnabled]),
                  [self titleRectForBounds: frame], NO);
}
@end

@interface NSTextInspectorTraitCell : NSButtonCell
@end
@implementation NSTextInspectorTraitCell
- (void) drawWithFrame: (NSRect) frame inView: (NSView *) view {
    _controlView = view;
    // OSXER TEXTEDIT LOOK R2 (traits): 21x18 hit areas at x326/347/368;
    // reference ink #737373, no off-state bezel; U has a 7x1 underline.
    if ([self state] != NSControlStateValueOff || [self isHighlighted]) {
        [(OSXERDarkAppearance() ? [NSColor selectedControlColor]
            : [NSColor colorWithCalibratedWhite: 232.0/255 alpha: 1]) setFill];
        [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(frame, 1, 0)
                                         xRadius: 3 yRadius: 3] fill];
    }
    InspectorText([self title], [self font], InspectorInk([self isEnabled]), frame, YES);
    if ([[self title] isEqual: @"U"]) {
        [InspectorInk([self isEnabled]) setFill];
        NSRectFill(NSMakeRect(floor(NSMidX(frame)-3.5), NSMinY(frame)+13, 7, 1));
    }
}
@end

@interface NSTextInspectorColorWell : NSColorWell
@end
@implementation NSTextInspectorColorWell
- (BOOL) isFlipped { return YES; }
- (BOOL) isOpaque { return NO; }
- (void) drawRect: (NSRect) dirty {
    // OSXER TEXTEDIT LOOK R2 (swatches): outer 16x14 at (272,35)/(299,35),
    // 14x12 interior, r2, #F3 rim. Transparent background: black a + red slash.
    NSRect swatch = NSInsetRect([self bounds], 0, 2);
    [(OSXERDarkAppearance() ? [NSColor separatorColor]
        : [NSColor colorWithCalibratedWhite: 243.0/255 alpha: 1]) setFill];
    [[NSBezierPath bezierPathWithRoundedRect: swatch xRadius: 3 yRadius: 3] fill];
    NSColor *color = [self color];
    BOOL clear = [color alphaComponent] == 0;
    [(clear ? [NSColor textBackgroundColor] : color) setFill];
    [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(swatch, 1, 1)
                                     xRadius: 2 yRadius: 2] fill];
    if (clear) {
        InspectorText(@"a", [NSFont systemFontOfSize: 11], [NSColor textColor], swatch, YES);
        NSBezierPath *slash = [NSBezierPath bezierPath];
        [slash moveToPoint: NSMakePoint(NSMinX(swatch)+2.5, NSMaxY(swatch)-2.5)];
        [slash lineToPoint: NSMakePoint(NSMaxX(swatch)-2.5, NSMinY(swatch)+2.5)];
        [[NSColor redColor] setStroke]; [slash setLineWidth: 1]; [slash stroke];
    }
    if ([self isActive]) {
        [[NSColor keyboardFocusIndicatorColor] setStroke];
        [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(swatch, .5, .5)
                                         xRadius: 3 yRadius: 3] stroke];
    }
}
@end

// OSXER TEXTEDIT LOOK R2 (requested family): NSFont keeps its creation request
// in _name even when CoreText draws a substitute. This private category only
// changes the inspector label, not public fontName/familyName or font caching.
@interface NSFont (NSTextInspectorIdentity)
- (NSString *) _inspectorFamilyName;
@end
@implementation NSFont (NSTextInspectorIdentity)
- (NSString *) _inspectorFamilyName {
    NSFontManager *manager = [NSFontManager sharedFontManager];
    if (![_name length] || [_name isEqual: [self fontName]] ||
        [[manager availableFonts] containsObject: _name] ||
        [[manager availableFontFamilies] containsObject: _name] ||
        [_name rangeOfCharacterFromSet: [NSCharacterSet characterSetWithCharactersInString: @":-."]].location != NSNotFound)
        return [self familyName];
    // Only a plain missing family request is unambiguous (e.g. Helvetica).
    // Do not display fontconfig patterns or guess families from PostScript names.
    return _name;
}
@end

@interface NSTextView (NSTextInspectorEditing)
- (void) _changeInspectorAttribute: (NSString *) key value: (id) value paragraph: (BOOL) paragraph;
- (void) _changeInspectorParagraph: (NSString *) property value: (NSNumber *) value;
@end

@implementation NSTextInspectorBar
- (BOOL) isFlipped { return YES; }
- (void) detachTextView { _textView = nil; }

- (void) configure: (NSControl *) control title: (NSString *) title action: (SEL) action {
    [control setFont: [NSFont systemFontOfSize: 11]];
    [[control cell] setControlSize: NSSmallControlSize];
    [control setToolTip: title];
    [control setTarget: self];
    [control setAction: action];
    [self addSubview: control];
    [control release]; // subview owns it
}
- (NSPopUpButton *) popup: (NSRect) frame title: (NSString *) title action: (SEL) action {
    NSPopUpButton *button = [[NSPopUpButton alloc] initWithFrame: frame pullsDown: NO];
    NSTextInspectorPopupCell *cell = [[NSTextInspectorPopupCell alloc] init];
    [button setCell: cell]; [cell release]; // setCell: retains, under MRC
    [self configure: button title: title action: action];
    return button;
}
- (NSButton *) toggle: (CGFloat) x title: (NSString *) title tooltip: (NSString *) tooltip {
    NSButton *button = [[NSButton alloc] initWithFrame: NSMakeRect(x, 5, 21, 18)];
    NSTextInspectorTraitCell *cell = [[NSTextInspectorTraitCell alloc] initTextCell: title];
    [button setCell: cell]; [cell release];
    [button setTitle: title];
    [button setButtonType: NSPushOnPushOffButton];
    [button setBordered: NO];
    [self configure: button title: tooltip action: @selector(changeTrait:)];
    return button;
}
- (id) initWithTextView: (NSTextView *) view {
    if (!(self = [super initWithFrame: NSMakeRect(0, 0, 601, 29)])) return nil;
    _textView = view;
    _family = [self popup: NSMakeRect(8, 5, 98, 18) title: @"Font family" action: @selector(changeFamily:)];
    [_family addItemsWithTitles: [[NSFontManager sharedFontManager] availableFontFamilies]];
    _typeface = [self popup: NSMakeRect(113, 5, 97, 18) title: @"Typeface" action: @selector(changeTypeface:)];
    _size = [[NSComboBox alloc] initWithFrame: NSMakeRect(218, 5, 42, 18)];
    NSTextInspectorSizeCell *sizeCell = [[NSTextInspectorSizeCell alloc] initTextCell: @""];
    [sizeCell setSendsActionOnEndEditing: YES];
    [sizeCell setScrollable: YES];
    [sizeCell setWraps: NO];
    [_size setCell: sizeCell]; [sizeCell release];
    [_size addItemsWithObjectValues: @[@"9", @"10", @"11", @"12", @"14", @"18", @"24", @"36", @"48", @"72"]];
    [self configure: _size title: @"Font size" action: @selector(changeSize:)];
    _foreground = [[NSTextInspectorColorWell alloc] initWithFrame: NSMakeRect(272, 5, 16, 18)];
    [_foreground setBordered: NO];
    [self configure: _foreground title: @"Text colour" action: @selector(changeColour:)];
    _background = [[NSTextInspectorColorWell alloc] initWithFrame: NSMakeRect(299, 5, 16, 18)];
    [_background setBordered: NO];
    [self configure: _background title: @"Text background colour" action: @selector(changeColour:)];
    _bold = [self toggle: 326 title: @"B" tooltip: @"Bold"];
    [_bold setFont: [NSFont boldSystemFontOfSize: 11]];
    _italic = [self toggle: 347 title: @"I" tooltip: @"Italic"];
    [_italic setFont: [[NSFontManager sharedFontManager] convertFont: [NSFont systemFontOfSize: 11] toHaveTrait: NSItalicFontMask]];
    _underline = [self toggle: 368 title: @"U" tooltip: @"Underline"];
    _alignment = [[NSSegmentedControl alloc] initWithFrame: NSMakeRect(397, 5, 82, 18)];
    [_alignment setSegmentCount: 4];
    [_alignment setSegmentStyle: NSSegmentStyleSmallSquare];
    NSArray *titles = @[@"Align left", @"Centre", @"Align right", @"Justify"];
    for (NSInteger segment = 0; segment < 4; segment++) {
        NSImage *icon = [[[NSImage alloc] initWithSize: NSMakeSize(12, 12)] autorelease];
        [icon lockFocus];
        [[NSColor secondaryLabelColor] setFill];
        for (NSInteger row = 0; row < 4; row++) {
            CGFloat width = segment == 3 || row % 2 == 0 ? 11 : 7;
            CGFloat x = segment == 1 ? (11-width)/2 : (segment == 2 ? 11-width : 0);
            NSRectFill(NSMakeRect(x, row * 3, width, 1));
        }
        [icon unlockFocus];
        [_alignment setImage: icon forSegment: segment];
        [_alignment setWidth: 20.5 forSegment: segment];
        [_alignment setToolTip: [titles objectAtIndex: segment] forSegment: segment];
    }
    [self configure: _alignment title: @"Alignment" action: @selector(changeAlignment:)];
    _spacing = [self popup: NSMakeRect(489, 5, 39, 18) title: @"Line spacing" action: @selector(changeSpacing:)];
    // OSXER TEXTEDIT LOOK R2 (spacing): exact multiples, no threshold rounding.
    [_spacing addItemsWithTitles: @[@"1.0", @"1.15", @"1.5", @"2.0", @"Other…"]];
    [_spacing setAutoenablesItems: NO];
    NSArray *multiples = @[@1.0, @1.15, @1.5, @2.0];
    for (NSInteger i = 0; i < [multiples count]; i++)
        [[_spacing itemAtIndex: i] setRepresentedObject: [multiples objectAtIndex: i]];
    [[_spacing lastItem] setEnabled: NO]; // custom-entry UI remains unimplemented
    _list = [self popup: NSMakeRect(537, 5, 37, 18) title: @"List" action: NULL];
    [[_list cell] setImagePosition: NSImageOnly];
    [_list addItemsWithTitles: @[@"None", @"• Bullet", @"◦ Circle", @"▪ Square",
                                @"1. Decimal", @"a. Lowercase letters", @"A. Uppercase letters",
                                @"i. Lowercase Roman", @"I. Uppercase Roman"]];
    [_list setAutoenablesItems: NO];
    // The popup opens, but cannot promise list edits that NSTextList lacks.
    for (NSMenuItem *item in [_list itemArray]) [item setEnabled: NO];
    [self syncSelection];
    return self;
}
- (void) drawRect: (NSRect) rect {
    [(OSXERDarkAppearance() ? [NSColor controlBackgroundColor] : [NSColor whiteColor]) setFill];
    NSRectFill(rect);
    [(OSXERDarkAppearance() ? [NSColor separatorColor] : [NSColor colorWithCalibratedWhite: 217.0/255 alpha: 1]) setFill];
    NSRectFill(NSMakeRect(0, NSHeight([self bounds])-1, NSWidth([self bounds]), 1));
}
- (void) syncSelection {
    if (!_textView) return;
    NSDictionary *attributes = [_textView typingAttributes];
    NSFont *font = [attributes objectForKey: NSFontAttributeName] ?: [_textView font];
    BOOL enabled = [_textView isEditable] && [_textView isRichText];
    for (NSControl *control in [self subviews]) [control setEnabled: enabled];
    NSString *family = [font _inspectorFamilyName];
    if (family && ![[_family titleOfSelectedItem] isEqual: family]) {
        if ([_family indexOfItemWithTitle: family] < 0) [_family addItemWithTitle: family];
        [_family selectItemWithTitle: family];
    }
    [_typeface removeAllItems];
    NSArray *members = [[NSFontManager sharedFontManager] availableMembersOfFontFamily: [font familyName]];
    for (NSArray *member in members) {
        [_typeface addItemWithTitle: [member objectAtIndex: 1]];
        [[_typeface lastItem] setRepresentedObject: [member objectAtIndex: 0]];
        if ([[member objectAtIndex: 0] isEqual: [font fontName]])
            [_typeface selectItem: [_typeface lastItem]];
    }
    // Do not overwrite a partially typed size during an inspector refresh.
    if (![_size currentEditor])
        [_size setStringValue: [NSString stringWithFormat: @"%g", [font pointSize]]];
    NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont: font];
    [_bold setState: (traits & NSBoldFontMask) != 0];
    [_italic setState: (traits & NSItalicFontMask) != 0];
    [_underline setState: [[attributes objectForKey: NSUnderlineStyleAttributeName] integerValue] != 0];
    [_foreground setColor: [attributes objectForKey: NSForegroundColorAttributeName] ?: [NSColor blackColor]];
    [_background setColor: [attributes objectForKey: NSBackgroundColorAttributeName] ?: [NSColor clearColor]];
    NSParagraphStyle *style = [attributes objectForKey: NSParagraphStyleAttributeName] ?: [NSParagraphStyle defaultParagraphStyle];
    NSTextAlignment alignment = [style alignment];
    NSInteger segment = alignment == NSCenterTextAlignment ? 1 : alignment == NSRightTextAlignment ? 2 : alignment == NSJustifiedTextAlignment ? 3 : 0;
    [_alignment setSelectedSegment: segment];
    CGFloat multiple = [style lineHeightMultiple];
    if (multiple <= 0) multiple = 1.0; // public default 0 means natural line height
    [_spacing selectItemAtIndex: 4];
    for (NSInteger i = 0; i < 4; i++)
        if (fabs(multiple-[[[_spacing itemAtIndex: i] representedObject] doubleValue]) < .0001)
            [_spacing selectItemAtIndex: i];
}
- (void) finishEditing {
    [[_textView window] makeFirstResponder: _textView];
    [self syncSelection];
}
- (NSFont *) convertFont: (NSFont *) font {
    NSFontManager *manager = [NSFontManager sharedFontManager];
    if (!font) font = [NSFont userFontOfSize: 12];
    switch (_fontOperation) {
    case 1: return [manager convertFont: font toFamily: [_family titleOfSelectedItem]];
    case 2: return [NSFont fontWithName: [[_typeface selectedItem] representedObject] size: [font pointSize]] ?: font;
    case 3: return [manager convertFont: font toSize: _fontSize];
    case 4: case 5: {
        NSFontTraitMask trait = _fontOperation == 4 ? NSBoldFontMask : NSItalicFontMask;
        return _removeTrait ? [manager convertFont: font toNotHaveTrait: trait] : [manager convertFont: font toHaveTrait: trait];
    }
    }
    return font;
}
- (void) changeFamily: (id) sender { _fontOperation = 1; [_textView changeFont: self]; [self finishEditing]; }
- (void) changeTypeface: (id) sender { _fontOperation = 2; [_textView changeFont: self]; [self finishEditing]; }
- (void) changeSize: (id) sender {
    if (_changingSize) return;
    _changingSize = YES;
    @try {
        // OSXER TEXTEDIT LOOK R2 (typed size): validate the entire field, including
        // decimals; reject zero, negatives, infinities and trailing garbage.
        NSScanner *scanner = [NSScanner scannerWithString: [[_size stringValue]
            stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        double size = 0;
        if ([scanner scanDouble: &size] && [scanner isAtEnd] && isfinite(size) && size > 0 && size <= 10000) {
            _fontSize = size;
            _fontOperation = 3; [_textView changeFont: self];
        }
        [self finishEditing];
    } @finally {
        _changingSize = NO;
    }
}
- (void) changeTrait: (NSButton *) sender {
    if (sender == _underline) {
        [_textView _changeInspectorAttribute: NSUnderlineStyleAttributeName
            value: [sender state] ? @1 : nil paragraph: NO];
    } else {
        _fontOperation = sender == _bold ? 4 : 5;
        _removeTrait = ![sender state];
        [_textView changeFont: self];
    }
    [self finishEditing];
}
- (void) changeAlignment: (id) sender {
    NSTextAlignment values[] = {NSLeftTextAlignment, NSCenterTextAlignment, NSRightTextAlignment, NSJustifiedTextAlignment};
    NSInteger index = [_alignment selectedSegment];
    if (index >= 0 && index < 4)
        [_textView _changeInspectorParagraph: @"alignment" value: [NSNumber numberWithInteger: values[index]]];
    [self finishEditing];
}
- (void) changeSpacing: (id) sender {
    NSNumber *multiple = [[_spacing selectedItem] representedObject];
    if (multiple)
        [_textView _changeInspectorParagraph: @"lineHeightMultiple" value: multiple];
    [self finishEditing];
}
- (void) changeColour: (NSColorWell *) sender {
    NSColor *color = [sender color];
    [_textView _changeInspectorAttribute: sender == _foreground ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName
        value: sender == _background && [color alphaComponent] == 0 ? nil : color paragraph: NO];
    [self finishEditing];
}
@end
