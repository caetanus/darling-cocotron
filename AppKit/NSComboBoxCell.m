#import "NSInterfacePart/OSXERBigSurGraphicsStyle.h" // OSXER BIGSUR R2 (combo bezel)
/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <AppKit/NSButtonCell.h>
#import <AppKit/NSComboBoxCell.h>
#import <AppKit/NSComboBoxWindow.h>
#import <AppKit/NSGraphicsStyle.h>
#import <AppKit/NSRaise.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Onyx2D/OSXERGalleryDebug.h> // OSXER FIX (combo diagnostics)

@implementation NSComboBoxCell

// OSXER FIX (combo initialization): inherited -init dispatches to initTextCell:;
// previously only nib decoding initialized the mutable items and button state.
- initTextCell: (NSString *) string {
    OSXERGalleryDebug("combo cell init begin\n");
    self = [super initTextCell: string];
    if (self == nil)
        return nil;
    _objectValues = [[NSMutableArray alloc] init];
    _numberOfVisibleItems = 5;
    _itemHeight = 16;
    _intercellSpacing = NSMakeSize(3, 2);
    _hasVerticalScroller = YES;
    _isButtonBordered = YES;
    _buttonEnabled = NO;
    [self setEditable: YES];
    [self setSelectable: YES];
    [self setBezeled: YES];
    OSXERGalleryDebug("combo cell init end\n");
    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    NSUnimplementedMethod();
}

- initWithCoder: (NSCoder *) coder {
    [super initWithCoder: coder];

    if ([coder allowsKeyedCoding]) {
        NSKeyedUnarchiver *keyed = (NSKeyedUnarchiver *) coder;

        _dataSource = [keyed decodeObjectForKey: @"NSDataSource"];
        _objectValues = [[NSMutableArray alloc]
                initWithArray: [keyed decodeObjectForKey: @"NSPopUpListData"]];
        _numberOfVisibleItems = [keyed decodeIntForKey: @"NSVisibleItemCount"];
        _usesDataSource = [keyed decodeBoolForKey: @"NSUsesDataSource"];
        _hasVerticalScroller =
                [keyed decodeBoolForKey: @"NSHasVerticalScroller"];
        _completes = [keyed decodeBoolForKey: @"NSCompletes"];
        _isButtonBordered = YES;
        _buttonEnabled = YES;
        _buttonPressed = NO;
    } else {
        [NSException raise: NSInvalidArgumentException
                    format: @"-[%@ %s] is not implemented for coder %@",
                            [self class], sel_getName(_cmd), coder];
    }

    return self;
}

- (void) dealloc {
    [_dataSource release];
    [_objectValues release];
    [super dealloc];
}

- copyWithZone: (NSZone *) zone {
    NSComboBoxCell *copy = [super copyWithZone: zone];

    // OSXER FIX (combo initialization): copies must still support item mutation.
    copy->_objectValues = [_objectValues mutableCopy];

    return copy;
}

- dataSource {
    return _dataSource;
}

- (BOOL) usesDataSource {
    return _usesDataSource;
}

- (BOOL) isButtonBordered {
    return _isButtonBordered;
}

- (CGFloat) itemHeight {
    return _itemHeight;
}

- (BOOL) hasVerticalScroller {
    return _hasVerticalScroller;
}

- (NSSize) intercellSpacing {
    return _intercellSpacing;
}

- (BOOL) completes {
    return _completes;
}

- (NSInteger) numberOfVisibleItems {
    return _numberOfVisibleItems;
}

- (void) setDataSource: value {
    _dataSource = value;
}

- (void) setUsesDataSource: (BOOL) value {
    _usesDataSource = value;
}

- (void) setButtonBordered: (BOOL) value {
    _isButtonBordered = value;
}

- (void) setItemHeight: (CGFloat) value {
    _itemHeight = value;
}

- (void) setHasVerticalScroller: (BOOL) value {
    _hasVerticalScroller = value;
}

- (void) setIntercellSpacing: (NSSize) value {
    _intercellSpacing = value;
}

- (void) setCompletes: (BOOL) flag {
    _completes = flag;
}

- (void) setNumberOfVisibleItems: (NSInteger) value {
    _numberOfVisibleItems = value;
}

- (NSInteger) numberOfItems {
    return [_objectValues count];
}

- (NSArray *) objectValues {
    return _objectValues;
}

- itemObjectValueAtIndex: (NSInteger) index {
    return [_objectValues objectAtIndex: index];
}

- (NSInteger) indexOfItemWithObjectValue: (id) object {
    return [_objectValues indexOfObjectIdenticalTo: object];
}

- (void) addItemWithObjectValue: (id) object {
    [_objectValues addObject: object];
    _buttonEnabled = ([_objectValues count] > 0) ? YES : NO;
}

- (void) addItemsWithObjectValues: (NSArray *) objects {
    [_objectValues addObjectsFromArray: objects];
    _buttonEnabled = ([_objectValues count] > 0) ? YES : NO;
}

- (void) removeAllItems {
    [_objectValues removeAllObjects];
    _buttonEnabled = ([_objectValues count] > 0) ? YES : NO;
}

- (void) removeItemAtIndex: (NSInteger) index {
    [_objectValues removeObjectAtIndex: index];
    _buttonEnabled = ([_objectValues count] > 0) ? YES : NO;
}

- (void) removeItemWithObjectValue: value {
    [_objectValues removeObject: value];
    _buttonEnabled = ([_objectValues count] > 0) ? YES : NO;
}

- (void) insertItemWithObjectValue: (id) object atIndex: (NSInteger) index {
    [_objectValues insertObject: object atIndex: index];
    _buttonEnabled = ([_objectValues count] > 0) ? YES : NO;
}

- (NSInteger) indexOfSelectedItem {
    NSInteger index = [_objectValues indexOfObject: [self objectValue]];
    return (index != NSNotFound) ? index : -1;
}

- objectValueOfSelectedItem {
    if (!_usesDataSource)
        return [self objectValue];
    else {
        NSLog(@"*** -[%@ %s] should not be called when usesDataSource is set "
              @"to YES",
              [self class], sel_getName(_cmd));
        return NULL;
    }
}

- (void) selectItemAtIndex: (NSInteger) index {
    if (index < 0 || index >= [_objectValues count])
        return;

    [self setObjectValue: [_objectValues objectAtIndex: index]];
}

- (void) selectItemWithObjectValue: value {
    if (!_usesDataSource) {
        NSInteger index = [_objectValues indexOfObject: value];
        [self selectItemAtIndex: (index != NSNotFound) ? index : -1];
    } else
        NSLog(@"*** -[%@ %s] should not be called when usesDataSource is set "
              @"to YES",
              [self class], sel_getName(_cmd));
}

- (void) deselectItemAtIndex: (NSInteger) index {
    NSUnimplementedMethod();
}

- (void) scrollItemAtIndexToTop: (NSInteger) index {
    NSUnimplementedMethod();
}

- (void) scrollItemAtIndexToVisible: (NSInteger) index {
    NSUnimplementedMethod();
}

- (void) noteNumberOfItemsChanged {
    NSUnimplementedMethod();
}

- (void) reloadData {
    NSUnimplementedMethod();
}

- (NSString *) completedString: (NSString *) string {
    NSInteger i, count = [_objectValues count];

    if (_usesDataSource == YES) // not supported yet, well...
        if ([_dataSource respondsToSelector: @selector(comboBoxCell:
                                                     completedString:)] == YES)
            return [_dataSource comboBoxCell: self completedString: string];

    for (i = 0; i < count; ++i) {
        NSString *stringValue;

        //        NSLog(@"checking %@",  [_objectValues objectAtIndex:i]);
        if ([[_objectValues objectAtIndex: i] isKindOfClass: [NSString class]])
            stringValue = [_objectValues objectAtIndex: i];
        else
            stringValue = [[_objectValues objectAtIndex: i] stringValue];

        if ([stringValue hasPrefix: string])
            return stringValue;
    }

    return nil;
}

- (NSSize) cellSize {
    NSSize size = [_controlView frame].size;
    size.width -= 3.0;
    size.height -= 2.0;
    return size;
}

- (NSRect) buttonRectForBounds: (NSRect) rect {
    // OSXER BIGSUR R2 (combo tile): x721..736/y147..162, 16x16 r4;
    // frame x522..741/y142..167, tile inset right=5, top=5.
    if (OSXERBigSurEnabled())
        return NSMakeRect(NSMaxX(rect)-21, NSMidY(rect)-8, 16, 16);
    rect.origin.x = (rect.origin.x + rect.size.width) - rect.size.height;
    rect.size.width = rect.size.height;
    return rect;
}

- (BOOL) trackMouse: (NSEvent *) event
              inRect: (NSRect) cellFrame
              ofView: (NSView *) controlView
        untilMouseUp: (BOOL) flag
{
    NSComboBoxWindow *window;
    NSPoint origin = [controlView bounds].origin;
    NSSize size = [self cellSize];
    NSPoint check = [controlView convertPoint: [event locationInWindow]
                                     fromView: nil];
    NSUInteger selectedIndex =
            [_objectValues indexOfObject: [self objectValue]];

    if ([_objectValues count] == 0)
        return NO;

    if (!NSMouseInRect(check, [self buttonRectForBounds: cellFrame],
                       [controlView isFlipped]))
        return NO;

    origin.y += size.height;
    origin = [controlView convertPoint: origin toView: nil];
    origin = [[controlView window] convertBaseToScreen: origin];
    size.width += 1.0;

    window = [[NSComboBoxWindow alloc] initWithFrame: (NSRect){origin, size}];

    [window setObjectArray: _objectValues];
    [window setSelectedIndex: selectedIndex];
    if ([self font] != nil)
        [window setFont: [self font]];

    _buttonPressed = YES;
    [window makeKeyAndOrderFront: self];
    selectedIndex = [window runTrackingWithEvent: event];
    [window close]; // release when closed=YES
    _buttonPressed = NO;

    if (selectedIndex != NSNotFound) {
        NSTextView *editor = nil;
        if ([[controlView currentEditor] isKindOfClass:[NSTextView class]]) {
            editor = (NSTextView*)[controlView currentEditor];
        }
        
        NSObject *object = [_objectValues objectAtIndex: selectedIndex];
        if (editor && object) {
            NSString *string = nil;
            NSAttributedString *attstr = nil;

            if (_formatter)
                string = [_formatter stringForObjectValue: object];

            if (!string)
                if ([object isKindOfClass: [NSString class]])
                    string = (NSString*)object;
                else if ([object isKindOfClass: [NSAttributedString class]])
                    if ([editor isRichText])
                        attstr = (NSAttributedString*)object;
                    else
                        string = [object string];
                else if ([object respondsToSelector: @selector
                                 (descriptionWithLocale:)])
                    string = [object
                            descriptionWithLocale: [NSLocale currentLocale]];
                else if ([object respondsToSelector: @selector(description)])
                    string = [object description];
                else
                    string = @"";

            if (attstr)
                [[(NSTextView *) editor textStorage]
                        setAttributedString: attstr];
            else
                [editor setString: string];

            [editor setSelectedRange: NSMakeRange(0, [[editor string] length])];
            [self endEditing: editor];
            if (_sendsActionOnEndEditing)
                [(NSControl *) controlView
                        sendAction: [(NSControl *) controlView action]
                                to: [(NSControl *) controlView target]];
        }
    }

    return YES;
}

- (NSRect) titleRectForBounds: (NSRect) rect {
    // Keep some room for the button
    if (OSXERBigSurEnabled()) {
        // OSXER BIGSUR R2 (combo text): x534 ink; 11 px inset plus bearing.
        // OSXER BIGSUR R2 (combo baseline): ink y150, frame top142, bearing4.
        rect = NSInsetRect(rect, 0, 4);
        rect.origin.x += 11;
        rect.size.width = MAX(0, rect.size.width - 36);
        return rect;
    }
    NSRect buttonFrame = [self buttonRectForBounds: rect];
    rect.size.width = NSMinX(buttonFrame) - rect.origin.x;
    rect = [super titleRectForBounds: rect];

    return rect;
}

- (void) drawInteriorWithFrame: (NSRect) frame inView: (NSView *) controlView {
    if (!OSXERBigSurEnabled()) frame.size = [self cellSize];
    [super drawInteriorWithFrame: frame inView: controlView];
}

- (void) drawWithFrame: (NSRect) frame inView: (NSView *) controlView {
    if (OSXERBigSurEnabled()) {
        _controlView = controlView;
        // OSXER BIGSUR R2 (combo): field x522..739/y144..165 = 218x22,
        // fit r6; keep the original frame for title/editing and arrow hit test.
        NSRect bezel = NSInsetRect(frame, 0, 2); bezel.size.width -= 2;
        [(OSXERBigSurGraphicsStyle *)[controlView graphicsStyle]
                drawComboBoxBezelInRect: bezel];
        [self drawInteriorWithFrame: frame inView: controlView];
    } else {
        frame.size = [self cellSize];
        [super drawWithFrame: frame inView: controlView];
    }

    [[controlView graphicsStyle]
            drawComboBoxButtonInRect: [self buttonRectForBounds: frame]
                             enabled: _buttonEnabled
                            bordered: _isButtonBordered
                             pressed: _buttonPressed];
}

@end
