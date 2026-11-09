// OSXER TEXTEDIT LOOK (inspector): private AppKit view; no public API additions.
#import <AppKit/NSView.h>
@class NSTextView, NSPopUpButton, NSComboBox, NSButton, NSColorWell, NSSegmentedControl;
@interface NSTextInspectorBar : NSView {
    NSTextView *_textView; // owner; deliberately not retained
    NSPopUpButton *_family, *_typeface, *_spacing, *_list;
    NSComboBox *_size;
    NSButton *_bold, *_italic, *_underline;
    NSColorWell *_foreground, *_background;
    NSSegmentedControl *_alignment;
    NSInteger _fontOperation;
    BOOL _removeTrait;
}
- (id) initWithTextView: (NSTextView *) view;
- (void) syncSelection;
- (void) detachTextView;
@end
