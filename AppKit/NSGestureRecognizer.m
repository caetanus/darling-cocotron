/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <AppKit/NSGestureRecognizer.h>

@interface NSMagnificationGestureRecognizer : NSGestureRecognizer
@end

@interface NSRotationGestureRecognizer : NSGestureRecognizer
@end

// OSXER NIB (gesture configuration): decoding does not install event recognition.
@implementation NSGestureRecognizer
@synthesize target = _target, delegate = _delegate, action = _action;
@synthesize allowedTouchTypes = _allowedTouchTypes, enabled = _enabled;
- (id)initWithTarget:(id)target action:(SEL)action {
    if ((self = [super init])) { _target = target; _action = action; _enabled = YES; }
    return self;
}
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [self initWithTarget:[coder decodeObjectForKey:@"NSGestureRecognizer.target"]
        action:NSSelectorFromString([coder decodeObjectForKey:@"NSGestureRecognizer.action"])])) {
        _delegate = [coder decodeObjectForKey:@"NSGestureRecognizer.delegate"];
        _allowedTouchTypes = [coder decodeIntegerForKey:@"NSGestureRecognizer.allowedTouchTypes"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeConditionalObject:_target forKey:@"NSGestureRecognizer.target"];
    [coder encodeConditionalObject:_delegate forKey:@"NSGestureRecognizer.delegate"];
    [coder encodeObject:NSStringFromSelector(_action) forKey:@"NSGestureRecognizer.action"];
    [coder encodeInteger:_allowedTouchTypes forKey:@"NSGestureRecognizer.allowedTouchTypes"];
}
@end

@implementation NSRotationGestureRecognizer

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end

@implementation NSMagnificationGestureRecognizer

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
