/* Copyright (c) 2007 Christopher J. W. Lloyd

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE. */

#import "NSAnimationContext.h"
#import <AppKit/NSRaise.h>

// OSXER APPKIT (animation groups): no interpolation engine; the brief permits
// synchronous changes and completion. Nesting is independent on each thread.
#import <Foundation/Foundation.h>

static NSMutableArray *OSXERAnimationStack(void) {
    NSMutableDictionary *thread = [[NSThread currentThread] threadDictionary];
    NSMutableArray *stack = [thread objectForKey:@"OSXERAnimationContexts"];
    if (!stack) {
        stack = [NSMutableArray arrayWithObject:[[[NSAnimationContext alloc] init] autorelease]];
        [thread setObject:stack forKey:@"OSXERAnimationContexts"];
    }
    return stack;
}

@implementation NSAnimationContext
@synthesize allowsImplicitAnimation = _allowsImplicitAnimation;
@synthesize completionHandler = _completionHandler;
- (id)init { if ((self = [super init])) _duration = 0.25; return self; }
- (void)dealloc { [_completionHandler release]; [super dealloc]; }
- (id)copyWithZone:(NSZone *)zone {
    NSAnimationContext *copy = [[[self class] allocWithZone:zone] init];
    copy->_duration = _duration;
    copy->_allowsImplicitAnimation = _allowsImplicitAnimation;
    copy->_completionHandler = [_completionHandler copy];
    return copy;
}
+ (void)beginGrouping {
    NSAnimationContext *next = [[self currentContext] copy];
    // OSXER APPKIT (animation groups): a nested group has its own completion.
    [next setCompletionHandler:nil];
    [OSXERAnimationStack() addObject:next];
    [next release];
}
+ (void)endGrouping {
    NSMutableArray *stack = OSXERAnimationStack();
    if ([stack count] <= 1) [NSException raise:NSInternalInconsistencyException format:@"No animation group to end"];
    NSAnimationContext *context = [[stack lastObject] retain];
    [stack removeLastObject];
    @try { if (context->_completionHandler) context->_completionHandler(); }
    @finally { [context release]; }
}
+ (NSAnimationContext *)currentContext { return [OSXERAnimationStack() lastObject]; }
- (void)setDuration:(NSTimeInterval)duration { _duration = duration; }
- (NSTimeInterval)duration { return _duration; }
+ (void)runAnimationGroup:(void (^)(NSAnimationContext *))changes completionHandler:(void (^)(void))completion {
    [self beginGrouping];
    [[self currentContext] setCompletionHandler:completion];
    @try { if (changes) changes([self currentContext]); }
    @finally { [self endGrouping]; }
}
+ (void)runAnimationGroup:(void (^)(NSAnimationContext *))changes {
    [self runAnimationGroup:changes completionHandler:nil];
}
@end
