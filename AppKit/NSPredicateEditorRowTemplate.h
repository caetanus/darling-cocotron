#import <Foundation/NSObject.h>

// OSXER NIB (predicate row metadata)
@interface NSPredicateEditorRowTemplate : NSObject {
    NSArray *_templateViews;
    NSInteger _leftAttributeType, _rightAttributeType, _modifier, _options, _type;
    BOOL _leftIsWildcard, _rightIsWildcard;
}
@property(readonly) NSArray *templateViews;

@end
