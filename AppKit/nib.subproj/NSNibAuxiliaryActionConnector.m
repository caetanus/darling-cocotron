// OSXER NIB (auxiliary actions): same target/action connection, alternate selector slot.
#import <AppKit/NSNibConnector.h>
#import <AppKit/NSControl.h>
#import <Foundation/Foundation.h>
@interface NSNibAuxiliaryActionConnector : NSNibConnector { NSString *_trigger; }
@end
@implementation NSNibAuxiliaryActionConnector
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) _trigger = [[coder decodeObjectForKey:@"NSTrigger"] copy];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder]; [coder encodeObject:_trigger forKey:@"NSTrigger"];
}
- (void)establishConnection {
    if (![_trigger length]) return;
    SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:",
        [[_trigger substringToIndex:1] uppercaseString], [_trigger substringFromIndex:1]]);
    if ([_trigger length] && [_source respondsToSelector:setter]) {
        [_source setTarget:_destination];
        ((void (*)(id, SEL, SEL))[_source methodForSelector:setter])(_source, setter, NSSelectorFromString(_label));
    }
}
- (void)dealloc { [_trigger release]; [super dealloc]; }
@end
