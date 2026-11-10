#import <AppKit/AppKitExport.h>
#import <AppKit/NSControl.h>
#import <Foundation/NSString.h>

APPKIT_EXPORT NSString *const NSRuleEditorRowsDidChangeNotification;

// OSXER NIB (rule editor configuration)
@interface NSRuleEditor : NSControl <NSCoding> {
    id _delegate;
    CGFloat _rowHeight;
    NSInteger _nestingMode;
    BOOL _editable, _canRemoveAllRows;
    NSArray *_osxerRuleSlices;
    NSView *_osxerRuleHolder;
}
@property(assign) id delegate;
@property CGFloat rowHeight;
@property NSInteger nestingMode;
@property(getter=isEditable) BOOL editable;
@property BOOL canRemoveAllRows;

@end

@protocol NSRuleEditorDelegate <NSObject>

// TODO

@end
