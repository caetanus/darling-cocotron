#import <AppKit/NSControl.h>
#import <AppKit/NSButtonCell.h>
#import <Foundation/Foundation.h>
// OSXER NIB (switch state): use the existing switch-button cell renderer/tracking.
@interface NSSwitch : NSControl
@property NSInteger state;
@end
@implementation NSSwitch
+ (Class)cellClass { return [NSButtonCell class]; }
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        if (![self cell]) {
            NSButtonCell *cell = [[[NSButtonCell alloc] initTextCell:@""] autorelease];
            [cell setButtonType:NSSwitchButton];
            [self setCell:cell];
        }
        [self setState:[[coder decodeObjectForKey:@"NSControlContents"] integerValue]];
        if ([coder containsValueForKey:@"NSEnabled"]) [self setEnabled:[coder decodeBoolForKey:@"NSEnabled"]];
        if ([coder containsValueForKey:@"NSControlSize"]) [[self cell] setControlSize:[coder decodeIntegerForKey:@"NSControlSize"]];
    }
    return self;
}
- (NSInteger)state { return [[self cell] state]; }
- (void)setState:(NSInteger)state { [[self cell] setState:state]; [self setNeedsDisplay:YES]; }
@end
