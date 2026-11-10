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

#import <AppKit/NSLayoutConstraint.h>

// OSXER APPKIT (layout): Apple documents -1; 0xbff0000000000000 is the bit pattern of -1.0,
// which as an integer literal became 1.38e19.
const CGFloat NSViewNoInstrinsicMetric = -1;
const CGFloat NSViewNoIntrinsicMetric = -1;

// OSXER APPKIT (constraint storage): activation uses the documented common
// ancestor and public add/remove hooks. Stored constraints never alter frames.
#import <AppKit/NSView.h>
#import <Foundation/Foundation.h>

// The class and its storage are Foundation's (see Foundation/NSLayoutConstraint.h).
@implementation NSLayoutConstraint (OSXERActivation)
- (BOOL)isActive { return _osxerOwner != nil; }
- (void)setActive:(BOOL)active {
    if (active == [self isActive]) return;
    if (!active) { [[self retain] autorelease]; [_osxerOwner removeConstraint:self]; return; }
    if (![_firstItem isKindOfClass:[NSView class]] ||
        (_secondItem && ![_secondItem isKindOfClass:[NSView class]]))
        [NSException raise:NSInvalidArgumentException format:@"Layout guides are not supported yet"];
    NSView *owner = _firstItem;
    if (_secondItem) {
        while (owner && ![_secondItem isDescendantOf:owner]) owner = [owner superview];
        if (!owner) [NSException raise:NSInvalidArgumentException format:@"Constraint items have no common ancestor"];
    }
    [owner addConstraint:self];
}
+ (void)activateConstraints:(NSArray *)constraints {
    for (NSLayoutConstraint *constraint in constraints) [constraint setActive:YES];
}
+ (void)deactivateConstraints:(NSArray *)constraints {
    // The caller may supply a view's live list: keep iteration independent.
    for (NSLayoutConstraint *constraint in [[constraints copy] autorelease]) [constraint setActive:NO];
}
@end

@implementation NSView (OSXERConstraints)
- (NSArray *)constraints { return _osxerConstraints ? [[_osxerConstraints copy] autorelease] : [NSArray array]; }
- (void)addConstraint:(NSLayoutConstraint *)constraint {
    if (!constraint) [NSException raise:NSInvalidArgumentException format:@"Missing constraint"];
    for (id item in @[[constraint firstItem], [constraint secondItem] ?: [constraint firstItem]]) {
        if (![item isKindOfClass:[NSView class]] || ![item isDescendantOf:self])
            [NSException raise:NSInvalidArgumentException format:@"Constraint item is outside this view"];
    }
    if ([constraint _osxerOwner] == self) return;
    if ([constraint _osxerOwner]) [NSException raise:NSInvalidArgumentException format:@"Constraint already belongs to a view"];
    if (!_osxerConstraints) _osxerConstraints = [[NSMutableArray alloc] init];
    [_osxerConstraints addObject:constraint];
    [constraint _osxerSetOwner:self];
    [self setNeedsLayout:YES];
}
- (void)addConstraints:(NSArray *)constraints {
    for (NSLayoutConstraint *constraint in constraints) [self addConstraint:constraint];
}
- (void)removeConstraint:(NSLayoutConstraint *)constraint {
    if ([constraint _osxerOwner] != self) return;
    [constraint _osxerSetOwner:nil];
    [_osxerConstraints removeObjectIdenticalTo:constraint];
    [self setNeedsLayout:YES];
}
- (void)removeConstraints:(NSArray *)constraints {
    for (NSLayoutConstraint *constraint in [[constraints copy] autorelease]) [self removeConstraint:constraint];
}
- (BOOL)needsLayout { return _osxerNeedsLayout; }
- (void)setNeedsLayout:(BOOL)flag { _osxerNeedsLayout = flag; }
- (void)layout { _osxerNeedsLayout = NO; }
- (void)layoutSubtreeIfNeeded {
    if ([self needsLayout]) [self layout];
    for (NSView *child in [self subviews]) [child layoutSubtreeIfNeeded];
}
@end
