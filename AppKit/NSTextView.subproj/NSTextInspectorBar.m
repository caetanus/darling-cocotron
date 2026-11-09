// OSXER TEXTEDIT LOOK (inspector). Geometry measured in the supplied 601x491
// macos15-textedit.png at 1x: strip y28..56 (29 px), controls y33..50 (18 px),
// family x8..105, face x113..209, size x218..259, B/I/U x327..388,
// alignment x397..479, spacing x489..527, list x537..573. Native controls
// inherit the existing Big Sur palette; a narrower window clips trailing items.
#import "NSTextInspectorBar.h"
#import "NSInterfacePart/OSXERSystemPalette.h"
#import <AppKit/AppKit.h>

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
    [self configure: button title: title action: action];
    return button;
}
- (NSButton *) toggle: (CGFloat) x title: (NSString *) title tooltip: (NSString *) tooltip {
    NSButton *button = [[NSButton alloc] initWithFrame: NSMakeRect(x, 5, 21, 18)];
    [button setTitle: title];
    [button setButtonType: NSPushOnPushOffButton];
    [button setBezelStyle: NSRecessedBezelStyle];
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
    [_size addItemsWithObjectValues: @[@"9", @"10", @"11", @"12", @"14", @"18", @"24", @"36", @"48", @"72"]];
    [self configure: _size title: @"Font size" action: @selector(changeSize:)];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(sizeSelected:)
        name: NSComboBoxSelectionDidChangeNotification object: _size];
    _foreground = [[NSColorWell alloc] initWithFrame: NSMakeRect(272, 7, 14, 14)];
    [_foreground setBordered: NO];
    [self configure: _foreground title: @"Text colour" action: @selector(changeColour:)];
    _background = [[NSColorWell alloc] initWithFrame: NSMakeRect(299, 7, 14, 14)];
    [_background setBordered: YES];
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
    [_spacing addItemsWithTitles: @[@"1.0", @"1.5", @"2.0"]];
    _list = [self popup: NSMakeRect(537, 5, 37, 18) title: @"List" action: NULL];
    [_list addItemsWithTitles: @[@"☷", @"•", @"1."]];
    [_list setEnabled: NO]; // NSTextList layout is not implemented yet.
    [self syncSelection];
    return self;
}
- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [super dealloc];
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
    [_list setEnabled: NO];
    NSString *family = [font familyName];
    if (family && ![[_family titleOfSelectedItem] isEqual: family]) {
        if ([_family indexOfItemWithTitle: family] < 0) [_family addItemWithTitle: family];
        [_family selectItemWithTitle: family];
    }
    [_typeface removeAllItems];
    NSArray *members = [[NSFontManager sharedFontManager] availableMembersOfFontFamily: family];
    for (NSArray *member in members) {
        [_typeface addItemWithTitle: [member objectAtIndex: 1]];
        [[_typeface lastItem] setRepresentedObject: [member objectAtIndex: 0]];
        if ([[member objectAtIndex: 0] isEqual: [font fontName]])
            [_typeface selectItem: [_typeface lastItem]];
    }
    [_size setStringValue: [NSString stringWithFormat: @"%g", [font pointSize]]];
    NSFontTraitMask traits = [[NSFontManager sharedFontManager] traitsOfFont: font];
    [_bold setState: (traits & NSBoldFontMask) != 0];
    [_italic setState: (traits & NSItalicFontMask) != 0];
    [_underline setState: [[attributes objectForKey: NSUnderlineStyleAttributeName] integerValue] != 0];
    [_foreground setColor: [attributes objectForKey: NSForegroundColorAttributeName] ?: [NSColor textColor]];
    [_background setColor: [attributes objectForKey: NSBackgroundColorAttributeName] ?: [NSColor textBackgroundColor]];
    NSParagraphStyle *style = [attributes objectForKey: NSParagraphStyleAttributeName] ?: [NSParagraphStyle defaultParagraphStyle];
    NSTextAlignment alignment = [style alignment];
    NSInteger segment = alignment == NSCenterTextAlignment ? 1 : alignment == NSRightTextAlignment ? 2 : alignment == NSJustifiedTextAlignment ? 3 : 0;
    [_alignment setSelectedSegment: segment];
    CGFloat multiple = [style lineHeightMultiple];
    [_spacing selectItemAtIndex: multiple >= 1.75 ? 2 : multiple >= 1.25 ? 1 : 0];
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
    case 3: return [manager convertFont: font toSize: [_size doubleValue]];
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
    CGFloat size = [_size doubleValue];
    if (isfinite(size) && size > 0 && size <= 10000) {
        _fontOperation = 3; [_textView changeFont: self];
    }
    [self finishEditing];
}
- (void) sizeSelected: (NSNotification *) note {
    [_size setObjectValue: [_size objectValueOfSelectedItem]];
    [self changeSize: _size];
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
    [_textView _changeInspectorParagraph: @"lineHeightMultiple" value: [NSNumber numberWithDouble: [[_spacing titleOfSelectedItem] doubleValue]]];
    [self finishEditing];
}
- (void) changeColour: (NSColorWell *) sender {
    [_textView _changeInspectorAttribute: sender == _foreground ? NSForegroundColorAttributeName : NSBackgroundColorAttributeName
        value: [sender color] paragraph: NO];
    [self finishEditing];
}
@end
