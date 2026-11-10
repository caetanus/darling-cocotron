#import <AppKit/NSPredicateEditorRowTemplate.h>
#import <Foundation/Foundation.h>
// OSXER NIB (predicate row metadata)
@implementation NSPredicateEditorRowTemplate
@synthesize templateViews = _templateViews;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _templateViews = [[coder decodeObjectForKey:@"NSPredicateTemplateViews"] copy];
        _leftAttributeType = [coder decodeIntegerForKey:@"NSPredicateTemplateLeftAttributeType"];
        _rightAttributeType = [coder decodeIntegerForKey:@"NSPredicateTemplateRightAttributeType"];
        _modifier = [coder decodeIntegerForKey:@"NSPredicateTemplateModifier"];
        _options = [coder decodeIntegerForKey:@"NSPredicateTemplateOptions"];
        _type = [coder decodeIntegerForKey:@"NSPredicateTemplateType"];
        _leftIsWildcard = [coder decodeBoolForKey:@"NSPredicateTemplateLeftIsWildcard"];
        _rightIsWildcard = [coder decodeBoolForKey:@"NSPredicateTemplateRightIsWildcard"];
    }
    return self;
}
- (void)dealloc { [_templateViews release]; [super dealloc]; }
@end
