#import <AppKit/NSPredicateEditor.h>
#import <Foundation/Foundation.h>
// OSXER NIB (predicate templates)
@implementation NSPredicateEditor
@synthesize rowTemplates = _rowTemplates, predicate = _predicate;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _rowTemplates = [[coder decodeObjectForKey:@"NSPredicateTemplates"] copy];
        _predicate = [[coder decodeObjectForKey:@"NSPredicateEditorPredicate"] retain];
    }
    return self;
}
- (void)dealloc { [_rowTemplates release]; [_predicate release]; [super dealloc]; }
@end
