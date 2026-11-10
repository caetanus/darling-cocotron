// OSXER NIB (help metadata): retain the help locator; Help Viewer remains separate.
#import <AppKit/NSNibConnector.h>
#import <Foundation/Foundation.h>
@interface NSIBHelpConnector : NSNibConnector { NSString *_file, *_marker; }
@end
@implementation NSIBHelpConnector
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _file = [[coder decodeObjectForKey:@"NSFile"] copy];
        _marker = [[coder decodeObjectForKey:@"NSMarker"] copy];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeObject:_file forKey:@"NSFile"]; [coder encodeObject:_marker forKey:@"NSMarker"];
}
- (void)establishConnection { /* Help Viewer integration is not available. */ }
- (void)dealloc { [_file release]; [_marker release]; [super dealloc]; }
@end
