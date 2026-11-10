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
#import <AppKit/NSLayoutGuide.h>
// OSXER NIB (guide constraints): ownership is the guide's view, not the guide itself.
static NSView *OSXERNibConstraintView(id item) {
    if ([item isKindOfClass:[NSLayoutGuide class]]) return [item owningView];
    return [item isKindOfClass:[NSView class]] ? item : nil;
}
#import <Foundation/Foundation.h>

// The class and its storage are Foundation's (see Foundation/NSLayoutConstraint.h).
@implementation NSLayoutConstraint (OSXERActivation)

// OSXER APPKIT (visual format): Apple's visual format language, parsed into ordinary
// constraints (not activated, as documented). Grammar:
//   (H:|V:)? (| connection)? [view(predicates)] (connection [view(predicates)])* (connection |)?
//   connection: "" (flush) | "-" (standard spacing) | "-predicates-"
//   predicates: one predicate or "(p, p, ...)"; p: (==|<=|>=)? (number|metric|view) (@priority)?
// Standard spacing is 8 between views and 20 to the superview edge. A syntax error raises
// NSInvalidArgumentException, as on macOS.
#include <math.h>
typedef struct { NSLayoutRelation relation; CGFloat constant; id view; CGFloat priority; } OSXERVFLPredicate;

static void OSXERVFLFail(NSString *format, NSUInteger at, NSString *why) {
    [NSException raise: NSInvalidArgumentException
                format: @"Unable to parse constraint format: %@\n%@\n%*s^", why, format, (int)at, ""];
}

static void OSXERVFLSkipSpaces(NSString *f, NSUInteger *i) {
    while (*i < [f length] && [f characterAtIndex: *i] == ' ') (*i)++;
}

static NSString *OSXERVFLName(NSString *f, NSUInteger *i) {
    NSUInteger start = *i;
    while (*i < [f length]) {
        unichar c = [f characterAtIndex: *i];
        if (!(c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (*i > start && c >= '0' && c <= '9'))) break;
        (*i)++;
    }
    return *i > start ? [f substringWithRange: NSMakeRange(start, *i - start)] : nil;
}

static BOOL OSXERVFLNumber(NSString *f, NSUInteger *i, CGFloat *value) {
    NSUInteger start = *i;
    if (*i < [f length] && [f characterAtIndex: *i] == '-') (*i)++;
    while (*i < [f length] && (([f characterAtIndex: *i] >= '0' && [f characterAtIndex: *i] <= '9') || [f characterAtIndex: *i] == '.')) (*i)++;
    if (*i == start || (*i == start + 1 && [f characterAtIndex: start] == '-')) { *i = start; return NO; }
    *value = [[f substringWithRange: NSMakeRange(start, *i - start)] doubleValue];
    return YES;
}

// A constant: number, metric name; or (in view predicates) a view name.
static BOOL OSXERVFLObject(NSString *f, NSUInteger *i, NSDictionary *metrics, NSDictionary *views,
                           CGFloat *constant, id *view) {
    if (OSXERVFLNumber(f, i, constant)) return YES;
    NSUInteger at = *i;
    NSString *name = OSXERVFLName(f, i);
    if (!name) return NO;
    if ([metrics objectForKey: name]) { *constant = [[metrics objectForKey: name] doubleValue]; return YES; }
    if (view && [views objectForKey: name]) { *view = [views objectForKey: name]; *constant = 0; return YES; }
    OSXERVFLFail(f, at, [NSString stringWithFormat: @"%@ is not a key in the metrics or views dictionaries", name]);
    return NO;
}

static NSArray *OSXERVFLPredicates(NSString *f, NSUInteger *i, NSDictionary *metrics, NSDictionary *views, BOOL allowViews) {
    NSMutableArray *list = [NSMutableArray array];
    BOOL group = *i < [f length] && [f characterAtIndex: *i] == '(';
    if (group) (*i)++;
    for (;;) {
        OSXERVFLSkipSpaces(f, i);
        OSXERVFLPredicate p = {NSLayoutRelationEqual, 0, nil, NSLayoutPriorityRequired};
        if (*i + 1 < [f length]) {
            NSString *op = [f substringWithRange: NSMakeRange(*i, 2)];
            if ([op isEqual: @"=="]) { p.relation = NSLayoutRelationEqual; *i += 2; }
            else if ([op isEqual: @"<="]) { p.relation = NSLayoutRelationLessThanOrEqual; *i += 2; }
            else if ([op isEqual: @">="]) { p.relation = NSLayoutRelationGreaterThanOrEqual; *i += 2; }
        }
        OSXERVFLSkipSpaces(f, i);
        id view = nil;
        if (!OSXERVFLObject(f, i, metrics, views, &p.constant, allowViews ? &view : NULL))
            OSXERVFLFail(f, *i, @"Expected a number, metric or view");
        p.view = view;
        OSXERVFLSkipSpaces(f, i);
        if (*i < [f length] && [f characterAtIndex: *i] == '@') {
            (*i)++;
            CGFloat priority;
            if (!OSXERVFLObject(f, i, metrics, nil, &priority, NULL)) OSXERVFLFail(f, *i, @"Expected a priority");
            p.priority = priority;
        }
        [list addObject: [NSValue valueWithBytes: &p objCType: @encode(OSXERVFLPredicate)]];
        OSXERVFLSkipSpaces(f, i);
        if (!group) break;
        if (*i < [f length] && [f characterAtIndex: *i] == ',') { (*i)++; continue; }
        if (*i < [f length] && [f characterAtIndex: *i] == ')') { (*i)++; break; }
        OSXERVFLFail(f, *i, @"Expected ',' or ')'");
    }
    return list;
}

// first.a1 relation second.a2 + constant; a NAN constant is the standard spacing (8 between
// views, 20 to the superview), resolved here.
static NSLayoutConstraint *OSXERVFLMake(id first, NSLayoutAttribute a1, OSXERVFLPredicate p,
                                        id second, NSLayoutAttribute a2, BOOL edge) {
    CGFloat constant = isnan(p.constant) ? (edge ? 20 : 8) : p.constant;
    NSLayoutConstraint *c = [NSLayoutConstraint constraintWithItem: first attribute: a1 relatedBy: p.relation
                                                            toItem: second attribute: a2 multiplier: 1 constant: constant];
    [c setPriority: p.priority];
    return c;
}

+ (NSArray *)constraintsWithVisualFormat:(NSString *)format options:(NSLayoutFormatOptions)options
                                 metrics:(NSDictionary *)metrics views:(NSDictionary *)views {
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger i = 0, n = [format length];
    BOOL vertical = NO;
    if ([format hasPrefix: @"V:"]) { vertical = YES; i = 2; }
    else if ([format hasPrefix: @"H:"]) i = 2;
    NSLayoutAttribute lead = vertical ? NSLayoutAttributeTop : NSLayoutAttributeLeading;
    NSLayoutAttribute trail = vertical ? NSLayoutAttributeBottom : NSLayoutAttributeTrailing;
    NSLayoutAttribute size = vertical ? NSLayoutAttributeHeight : NSLayoutAttributeWidth;
    if ((options & NSLayoutFormatDirectionMask) == NSLayoutFormatDirectionLeftToRight && !vertical) {
        lead = NSLayoutAttributeLeft; trail = NSLayoutAttributeRight;
    }

    id previous = nil;          // last view, or the superview marker
    BOOL previousIsEdge = NO;
    NSArray *pending = nil;     // spacing predicates waiting for the next item; nil = flush
    BOOL havePending = NO;
    NSMutableArray *chain = [NSMutableArray array];

    OSXERVFLSkipSpaces(format, &i);
    if (i < n && [format characterAtIndex: i] == '|') { previousIsEdge = YES; i++; }
    while (i < n) {
        OSXERVFLSkipSpaces(format, &i);
        if (i >= n) break;
        unichar c = [format characterAtIndex: i];
        if (c == '-') {
            i++;
            OSXERVFLSkipSpaces(format, &i);
            if (i < n && ([format characterAtIndex: i] == '[' || [format characterAtIndex: i] == '|')) {
                OSXERVFLPredicate p = {NSLayoutRelationEqual, NAN, nil, NSLayoutPriorityRequired};
                pending = @[[NSValue valueWithBytes: &p objCType: @encode(OSXERVFLPredicate)]];
            } else {
                pending = OSXERVFLPredicates(format, &i, metrics, views, NO);
                OSXERVFLSkipSpaces(format, &i);
                if (i >= n || [format characterAtIndex: i] != '-') OSXERVFLFail(format, i, @"Expected '-'");
                i++;
            }
            havePending = YES;
            continue;
        }
        if (c == '[') {
            i++;
            NSUInteger at = i;
            NSString *name = OSXERVFLName(format, &i);
            id view = name ? [views objectForKey: name] : nil;
            if (!view) OSXERVFLFail(format, at, [NSString stringWithFormat: @"%@ is not a key in the views dictionary", name ?: @"(empty)"]);
            if (i < n && [format characterAtIndex: i] == '(') {
                for (NSValue *v in OSXERVFLPredicates(format, &i, metrics, views, YES)) {
                    OSXERVFLPredicate p; [v getValue: &p];
                    [result addObject: OSXERVFLMake(view, size, p, p.view, p.view ? size : NSLayoutAttributeNotAnAttribute, NO)];
                }
            }
            if (i >= n || [format characterAtIndex: i] != ']') OSXERVFLFail(format, i, @"Expected ']'");
            i++;
            if (previous || previousIsEdge) {
                NSArray *spacing = havePending ? pending : nil;
                id from = previousIsEdge && !previous ? [view superview] : previous;
                NSLayoutAttribute fromAttr = previousIsEdge && !previous ? lead : trail;
                if (!from) OSXERVFLFail(format, at, @"A view has no superview for '|'");
                if (!spacing) {
                    OSXERVFLPredicate p = {NSLayoutRelationEqual, 0, nil, NSLayoutPriorityRequired};
                    spacing = @[[NSValue valueWithBytes: &p objCType: @encode(OSXERVFLPredicate)]];
                }
                for (NSValue *v in spacing) {
                    OSXERVFLPredicate p; [v getValue: &p];
                    [result addObject: OSXERVFLMake(view, lead, p, from, fromAttr, from != previous)];
                }
            }
            previous = view; previousIsEdge = NO; havePending = NO; pending = nil;
            [chain addObject: view];
            continue;
        }
        if (c == '|') {
            i++;
            if (!previous) OSXERVFLFail(format, i - 1, @"'|' must follow a view");
            id superview = [previous superview];
            if (!superview) OSXERVFLFail(format, i - 1, @"A view has no superview for '|'");
            NSArray *spacing = havePending ? pending : nil;
            if (!spacing) {
                OSXERVFLPredicate p = {NSLayoutRelationEqual, 0, nil, NSLayoutPriorityRequired};
                spacing = @[[NSValue valueWithBytes: &p objCType: @encode(OSXERVFLPredicate)]];
            }
            for (NSValue *v in spacing) {
                OSXERVFLPredicate p; [v getValue: &p];
                [result addObject: OSXERVFLMake(superview, trail, p, previous, trail, YES)];
            }
            havePending = NO;
            break;
        }
        OSXERVFLFail(format, i, @"Unexpected character");
    }

    NSUInteger align = options & NSLayoutFormatAlignmentMask;
    for (NSUInteger k = 1; k < [chain count] && align; k++)
        for (NSUInteger bit = 1; bit <= NSLayoutAttributeFirstBaseline; bit++)
            if (align & (1u << bit))
                [result addObject: [NSLayoutConstraint constraintWithItem: [chain objectAtIndex: k] attribute: bit
                    relatedBy: NSLayoutRelationEqual toItem: [chain objectAtIndex: 0] attribute: bit multiplier: 1 constant: 0]];
    return result;
}

- (BOOL)isActive { return _osxerOwner != nil; }
- (void)setActive:(BOOL)active {
    if (active == [self isActive]) return;
    if (!active) { [[self retain] autorelease]; [_osxerOwner removeConstraint:self]; return; }
    NSView *owner = OSXERNibConstraintView(_firstItem);
    NSView *secondView = OSXERNibConstraintView(_secondItem);
    if (!owner || (_secondItem && !secondView))
        [NSException raise:NSInvalidArgumentException format:@"Constraint item has no owning view"];
    if (_secondItem) {
        while (owner && ![secondView isDescendantOf:owner]) owner = [owner superview];
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
        NSView *view = OSXERNibConstraintView(item);
        if (!view || ![view isDescendantOf:self])
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
// OSXER APPKIT (fitting geometry): no constraint solver; subclasses can supply
// intrinsic metrics, and plain containers derive extents from their subviews.
- (NSSize)intrinsicContentSize { return NSMakeSize(NSViewNoIntrinsicMetric, NSViewNoIntrinsicMetric); }
- (NSSize)fittingSize {
    NSSize intrinsic = [self intrinsicContentSize];
    NSSize size = [self frame].size;
    if ([[self subviews] count]) {
        size = NSZeroSize;
        for (NSView *view in [self subviews]) {
            if ([view isHidden]) continue;
            NSRect frame = [view frame];
            size.width = MAX(size.width, NSMaxX(frame)); size.height = MAX(size.height, NSMaxY(frame));
        }
    }
    if (intrinsic.width >= 0) size.width = intrinsic.width;
    if (intrinsic.height >= 0) size.height = intrinsic.height;
    return size;
}
- (void)invalidateIntrinsicContentSize { [[self superview] setNeedsLayout:YES]; }
- (BOOL)needsLayout { return _osxerNeedsLayout; }
- (void)setNeedsLayout:(BOOL)flag { _osxerNeedsLayout = flag; if (flag) [self setNeedsDisplay:YES]; }
- (void)layout { _osxerNeedsLayout = NO; }
- (void)layoutSubtreeIfNeeded {
    // OSXER APPKIT (constraint lifecycle): subclass updates precede frame layout.
    [self updateConstraintsForSubtreeIfNeeded];
    if ([self needsLayout]) [self layout];
    for (NSView *child in [self subviews]) [child layoutSubtreeIfNeeded];
}
@end
