// OSXER NIB (external objects): storyboard and split view nib references are
// supplied by the loading context, not allocated as independent objects.
#import <Foundation/Foundation.h>

@interface NSObject (NSNibExternalObjectContext)
- (id) delegate;
- (NSDictionary *) externalNameTable;
@end

@interface NSNibExternalObjectPlaceholder : NSObject
@end

@implementation NSNibExternalObjectPlaceholder
- (id) initWithCoder: (NSCoder *) coder {
    NSString *identifier = [coder decodeObjectForKey: @"NSExternalObjectPlaceholderIdentifier"];
    id context = [(id)coder delegate];
    id result = [[context externalNameTable] objectForKey: identifier];
    if (!result) {
        [self release];
        [NSException raise: NSInvalidUnarchiveOperationException
                    format: @"Unresolved nib external object %@", identifier];
        return nil;
    }
    [result retain];
    [self release];
    return result;
}
@end
