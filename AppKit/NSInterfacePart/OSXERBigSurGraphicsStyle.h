#import <AppKit/NSGraphicsStyle.h>
#import "OSXERSystemPalette.h"

@class NSButtonCell, NSTextFieldCell, NSSegmentedCell, NSTabView, NSTableView;

BOOL OSXERBigSurDrawsButton(NSButtonCell *cell);
NSSize OSXERBigSurButtonSize(NSButtonCell *cell);

@interface OSXERBigSurGraphicsStyle : NSGraphicsStyle
- (BOOL) drawButtonCell: (NSButtonCell *) cell inRect: (NSRect) rect;
- (void) drawTextFieldCell: (NSTextFieldCell *) cell inRect: (NSRect) rect;
- (void) drawSearchGlyphsInRect: (NSRect) rect cancelRect: (NSRect) cancel
                      enabled: (BOOL) enabled showsCancel: (BOOL) showsCancel;
- (void) drawSegmentedTrackInRect: (NSRect) rect;
- (void) drawSegment: (NSInteger) index cell: (NSSegmentedCell *) cell
             inRect: (NSRect) rect;
- (void) drawTableBackground: (NSTableView *) table clipRect: (NSRect) rect;
- (void) drawTableSelection: (NSTableView *) table clipRect: (NSRect) rect;
- (NSColor *) tableSelectionTextColor: (NSTableView *) table;
- (void) drawHeaderText: (NSAttributedString *) text inRect: (NSRect) rect;
- (NSRect) tabRectAtIndex: (NSUInteger) index inTabView: (NSTabView *) tabView;
- (void) drawTopTabView: (NSTabView *) tabView;
- (void) drawFocusRingInRect: (NSRect) rect radius: (CGFloat) radius;
- (void) drawMenuKeyEquivalent: (NSString *) text inRect: (NSRect) rect
                      enabled: (BOOL) enabled selected: (BOOL) selected;
@end
