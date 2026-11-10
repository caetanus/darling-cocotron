#import "NSNibAXRelationshipConnector.h"

@implementation NSNibAXRelationshipConnector
// OSXER NIB (accessibility connections): state is inherited from NSNibConnector.
- (void)establishConnection { /* Accessibility relationship backend is pending. */ }

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end

// OSXER NIB (accessibility archive state)
@implementation NSNibAXAttributeConnector
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        [self setDestination:[coder decodeObjectForKey:@"AXDestinationArchiveKey"]];
        _attributeType = [[coder decodeObjectForKey:@"AXAttributeTypeArchiveKey"] retain];
        _attributeValue = [[coder decodeObjectForKey:@"AXAttributeValueArchiveKey"] retain];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_destination forKey:@"AXDestinationArchiveKey"];
    [coder encodeObject:_attributeType forKey:@"AXAttributeTypeArchiveKey"];
    [coder encodeObject:_attributeValue forKey:@"AXAttributeValueArchiveKey"];
}
- (void)establishConnection { /* The accessibility backend does not expose overrides yet. */ }
- (void)dealloc { [_attributeType release]; [_attributeValue release]; [super dealloc]; }
@end
