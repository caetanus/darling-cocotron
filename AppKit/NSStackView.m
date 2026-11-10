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

#import <AppKit/NSStackView.h>

// OSXER APPKIT (stack storage): preserve frames while recording arranged views.
@implementation NSStackView
@synthesize spacing = _spacing;
// OSXER APPKIT (stack spacing): Apple's documented default is eight points.
- (id)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) _spacing = 8;
    return self;
}
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _spacing = [coder containsValueForKey:@"OSXERStackSpacing"] ? [coder decodeDoubleForKey:@"OSXERStackSpacing"] : 8;
        _arrangedSubviews = [[coder decodeObjectForKey:@"OSXERArrangedSubviews"] mutableCopy];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeDouble:_spacing forKey:@"OSXERStackSpacing"];
    [coder encodeObject:_arrangedSubviews forKey:@"OSXERArrangedSubviews"];
}
- (NSArray *)arrangedSubviews { return _arrangedSubviews ? [[_arrangedSubviews copy] autorelease] : [NSArray array]; }
- (void)addArrangedSubview:(NSView *)view {
    if ([_arrangedSubviews indexOfObjectIdenticalTo:view] != NSNotFound && _arrangedSubviews) return;
    [self insertArrangedSubview:view atIndex:[_arrangedSubviews count]];
}
- (void)insertArrangedSubview:(NSView *)view atIndex:(NSUInteger)index {
    if (!view || index > [_arrangedSubviews count])
        [NSException raise:NSInvalidArgumentException format:@"Invalid arranged subview or index"];
    if (!_arrangedSubviews) _arrangedSubviews = [[NSMutableArray alloc] init];
    [view retain];
    NSUInteger previous = [_arrangedSubviews indexOfObjectIdenticalTo:view];
    if (previous != NSNotFound) {
        [_arrangedSubviews removeObjectAtIndex:previous];
        if (previous < index) --index;
    }
    [_arrangedSubviews insertObject:view atIndex:index];
    if ([view superview] != self) [self addSubview:view];
    [view release];
    [self setNeedsLayout:YES];
}
- (void)removeArrangedSubview:(NSView *)view {
    [_arrangedSubviews removeObjectIdenticalTo:view];
    [self setNeedsLayout:YES];
}
- (void)willRemoveSubview:(NSView *)view {
    [self removeArrangedSubview:view];
    [super willRemoveSubview:view];
}
- (void)dealloc { [_arrangedSubviews release]; _arrangedSubviews = nil; [super dealloc]; }
@end
