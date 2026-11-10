#import <AppKit/NSRuleEditor.h>
#import <Foundation/Foundation.h>
NSString *const NSRuleEditorRowsDidChangeNotification = @"NSRuleEditorRowsDidChangeNotification";
// OSXER NIB (rule editor configuration): row editing/predicate synthesis remain separate.
@implementation NSRuleEditor
@synthesize delegate = _delegate, rowHeight = _rowHeight, nestingMode = _nestingMode;
@synthesize editable = _editable, canRemoveAllRows = _canRemoveAllRows;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _delegate = [coder decodeObjectForKey:@"NSRuleEditorDelegate"];
        _rowHeight = [coder containsValueForKey:@"NSRuleEditorSliceHeight"] ? [coder decodeDoubleForKey:@"NSRuleEditorSliceHeight"] : 25;
        _nestingMode = [coder decodeIntegerForKey:@"NSRuleEditorNestingMode"];
        _editable = ![coder containsValueForKey:@"NSRuleEditorEditable"] || [coder decodeBoolForKey:@"NSRuleEditorEditable"];
        _canRemoveAllRows = ![coder decodeBoolForKey:@"NSRuleEditorDisallowEmpty"];
        _osxerRuleSlices = [[coder decodeObjectForKey:@"NSRuleEditorSlices"] retain];
        _osxerRuleHolder = [[coder decodeObjectForKey:@"NSRuleEditorSlicesHolder"] retain];
        if (_osxerRuleHolder && [_osxerRuleHolder superview] != self) [self addSubview:_osxerRuleHolder];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeConditionalObject:_delegate forKey:@"NSRuleEditorDelegate"];
    [coder encodeDouble:_rowHeight forKey:@"NSRuleEditorSliceHeight"];
    [coder encodeInteger:_nestingMode forKey:@"NSRuleEditorNestingMode"];
    [coder encodeBool:_editable forKey:@"NSRuleEditorEditable"];
    [coder encodeBool:!_canRemoveAllRows forKey:@"NSRuleEditorDisallowEmpty"];
    [coder encodeObject:_osxerRuleSlices forKey:@"NSRuleEditorSlices"];
    [coder encodeObject:_osxerRuleHolder forKey:@"NSRuleEditorSlicesHolder"];
}
- (void)dealloc { [_osxerRuleSlices release]; [_osxerRuleHolder release]; [super dealloc]; }
@end
