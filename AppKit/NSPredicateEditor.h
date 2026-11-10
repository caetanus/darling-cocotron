#import <AppKit/NSRuleEditor.h>

// OSXER NIB (predicate templates)
@interface NSPredicateEditor : NSRuleEditor {
    NSArray *_rowTemplates;
    id _predicate;
}
@property(copy) NSArray *rowTemplates;
@property(retain) id predicate;

@end
