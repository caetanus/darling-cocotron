#import <AppKit/NSGraphicsStyle.h>
#import "OSXERSystemPalette.h"

@class NSLevelIndicatorCell, NSButtonCell, NSTextFieldCell, NSSegmentedCell, NSTabView, NSTableView;

BOOL OSXERBigSurDrawsButton(NSButtonCell *cell);
NSSize OSXERBigSurButtonSize(NSButtonCell *cell);

@interface OSXERBigSurGraphicsStyle : NSGraphicsStyle
// OSXER BIGSUR R2 (focus): parent overlay, 4 px stroke centered on field edge.
- (BOOL) cellHasFocus: (NSCell *) cell;
- (void) drawTextFieldFocusRingInRect: (NSRect) rect radius: (CGFloat) radius;
- (void) drawLevelCell: (NSLevelIndicatorCell *) cell inRect: (NSRect) rect; // OSXER BIGSUR R2
- (void) drawComboBoxBezelInRect: (NSRect) rect; // OSXER BIGSUR R2 (combo)
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
