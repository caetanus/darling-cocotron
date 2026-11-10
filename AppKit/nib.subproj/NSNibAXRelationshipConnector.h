#import <AppKit/NSNibConnector.h>

@interface NSNibAXRelationshipConnector : NSNibConnector {
}

@end

// OSXER NIB (accessibility archive state)
@interface NSNibAXAttributeConnector : NSNibConnector <NSCoding> {
    id _attributeType, _attributeValue;
}
@end
