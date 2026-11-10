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

// OSXER APPKIT (stack layout): arrange by frames; constraint priorities are not solved.
@implementation NSStackView
+ (instancetype)stackViewWithViews:(NSArray *)views {
    NSStackView *stack = [[[self alloc] initWithFrame:NSZeroRect] autorelease];
    for (NSView *view in views) [stack addArrangedSubview:view];
    return stack;
}
- (CGFloat)spacing { return _spacing; }
- (void)setSpacing:(CGFloat)value { _spacing = value; [self setNeedsLayout:YES]; }
- (NSUserInterfaceLayoutOrientation)orientation { return _orientation; }
- (void)setOrientation:(NSUserInterfaceLayoutOrientation)value {
    if (value != _orientation) {
        if (_alignment == NSLayoutAttributeCenterX || _alignment == NSLayoutAttributeCenterY)
            _alignment = value == NSUserInterfaceLayoutOrientationVertical ? NSLayoutAttributeCenterX : NSLayoutAttributeCenterY;
        _orientation = value; [self setNeedsLayout:YES];
    }
}
- (NSLayoutAttribute)alignment { return _alignment; }
- (void)setAlignment:(NSLayoutAttribute)value { _alignment = value; [self setNeedsLayout:YES]; }
- (NSStackViewDistribution)distribution { return _distribution; }
- (void)setDistribution:(NSStackViewDistribution)value { _distribution = value; [self setNeedsLayout:YES]; }
- (NSEdgeInsets)edgeInsets { return _edgeInsets; }
- (void)setEdgeInsets:(NSEdgeInsets)value { _edgeInsets = value; [self setNeedsLayout:YES]; }
- (void)setFrame:(NSRect)frame { [super setFrame:frame]; [self setNeedsLayout:YES]; }
- (void)setBounds:(NSRect)bounds { [super setBounds:bounds]; [self setNeedsLayout:YES]; }
- (void)resizeSubviewsWithOldSize:(NSSize)size { [self setNeedsLayout:YES]; }

// OSXER APPKIT (stack spacing): Apple's documented default is eight points.
- (id)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _spacing = 8; _alignment = NSLayoutAttributeCenterY;
        _distribution = NSStackViewDistributionGravityAreas;
    }
    return self;
}
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _spacing = [coder containsValueForKey:@"OSXERStackSpacing"] ? [coder decodeDoubleForKey:@"OSXERStackSpacing"] : 8;
        _arrangedSubviews = [[coder decodeObjectForKey:@"OSXERArrangedSubviews"] mutableCopy];
        _orientation = [coder decodeIntegerForKey:@"OSXERStackOrientation"];
        _alignment = [coder containsValueForKey:@"OSXERStackAlignment"] ? [coder decodeIntegerForKey:@"OSXERStackAlignment"] : NSLayoutAttributeCenterY;
        _distribution = [coder containsValueForKey:@"OSXERStackDistribution"] ? [coder decodeIntegerForKey:@"OSXERStackDistribution"] : NSStackViewDistributionGravityAreas;
        _edgeInsets.top = [coder decodeDoubleForKey:@"OSXERStackTop"];
        _edgeInsets.left = [coder decodeDoubleForKey:@"OSXERStackLeft"];
        _edgeInsets.bottom = [coder decodeDoubleForKey:@"OSXERStackBottom"];
        _edgeInsets.right = [coder decodeDoubleForKey:@"OSXERStackRight"];
        [self setNeedsLayout:YES];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeDouble:_spacing forKey:@"OSXERStackSpacing"];
    [coder encodeObject:_arrangedSubviews forKey:@"OSXERArrangedSubviews"];
    [coder encodeInteger:_orientation forKey:@"OSXERStackOrientation"];
    [coder encodeInteger:_alignment forKey:@"OSXERStackAlignment"];
    [coder encodeInteger:_distribution forKey:@"OSXERStackDistribution"];
    [coder encodeDouble:_edgeInsets.top forKey:@"OSXERStackTop"];
    [coder encodeDouble:_edgeInsets.left forKey:@"OSXERStackLeft"];
    [coder encodeDouble:_edgeInsets.bottom forKey:@"OSXERStackBottom"];
    [coder encodeDouble:_edgeInsets.right forKey:@"OSXERStackRight"];
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
// OSXER APPKIT (stack frames): vertical order is top to bottom in either
// coordinate system. Fill expands the final view and compresses proportionally
// when needed; equal fill divides the available length after padding/spacing.
- (NSSize)fittingSize {
    BOOL vertical = _orientation == NSUserInterfaceLayoutOrientationVertical;
    CGFloat length = 0, breadth = 0;
    NSUInteger count = 0;
    for (NSView *view in _arrangedSubviews) {
        if ([view isHidden]) continue;
        NSSize size = [view fittingSize];
        length += vertical ? size.height : size.width;
        breadth = MAX(breadth, vertical ? size.width : size.height); ++count;
    }
    if (count) length += (count - 1) * _spacing;
    return NSMakeSize((vertical ? breadth : length) + _edgeInsets.left + _edgeInsets.right,
                      (vertical ? length : breadth) + _edgeInsets.top + _edgeInsets.bottom);
}
- (void)layout {
    [super layout];
    NSMutableArray *views = [NSMutableArray array];
    NSMutableArray *sizes = [NSMutableArray array];
    BOOL vertical = _orientation == NSUserInterfaceLayoutOrientationVertical;
    CGFloat total = 0;
    for (NSView *view in _arrangedSubviews) {
        if ([view isHidden]) continue;
        NSSize size = [view fittingSize];
        [views addObject:view]; [sizes addObject:[NSValue valueWithSize:size]];
        total += MAX(0, vertical ? size.height : size.width);
    }
    NSUInteger count = [views count];
    if (!count) return;
    NSRect area = [self bounds];
    area.origin.x += _edgeInsets.left;
    area.origin.y += [self isFlipped] ? _edgeInsets.top : _edgeInsets.bottom;
    area.size.width = MAX(0, area.size.width - _edgeInsets.left - _edgeInsets.right);
    area.size.height = MAX(0, area.size.height - _edgeInsets.top - _edgeInsets.bottom);
    CGFloat space = _spacing;
    CGFloat available = MAX(0, (vertical ? area.size.height : area.size.width) - space * (count - 1));
    if (_distribution == NSStackViewDistributionEqualSpacing && count > 1)
        space += MAX(0, available - total) / (count - 1);
    CGFloat centerStep = 0;
    NSSize first = [[sizes objectAtIndex:0] sizeValue], last = [[sizes lastObject] sizeValue];
    CGFloat firstLength = vertical ? first.height : first.width;
    if (_distribution == NSStackViewDistributionEqualCentering && count > 1) {
        centerStep = ((vertical ? area.size.height : area.size.width) -
            (firstLength + (vertical ? last.height : last.width)) / 2) / (count - 1);
        for (NSUInteger i = 1; i < count; ++i) {
            NSSize a = [[sizes objectAtIndex:i-1] sizeValue], b = [[sizes objectAtIndex:i] sizeValue];
            centerStep = MAX(centerStep, (vertical ? a.height + b.height : a.width + b.width) / 2 + _spacing);
        }
    }
    CGFloat cursor = 0;
    for (NSUInteger i = 0; i < count; ++i) {
        NSView *view = [views objectAtIndex:i];
        NSSize size = [[sizes objectAtIndex:i] sizeValue];
        CGFloat length = MAX(0, vertical ? size.height : size.width);
        if (_distribution == NSStackViewDistributionFillEqually) length = available / count;
        else if (_distribution == NSStackViewDistributionFillProportionally) length = total ? available * length / total : available / count;
        else if (_distribution == NSStackViewDistributionFill) {
            if (total > available) length *= available / total;
            else if (i == count - 1) length += available - total;
        }
        CGFloat crossAvailable = vertical ? area.size.width : area.size.height;
        CGFloat cross = MIN(crossAvailable, MAX(0, vertical ? size.width : size.height));
        CGFloat offset = (crossAvailable - cross) / 2;
        if (vertical) {
            if (_alignment == NSLayoutAttributeLeft || _alignment == NSLayoutAttributeLeading) offset = 0;
            if (_alignment == NSLayoutAttributeRight || _alignment == NSLayoutAttributeTrailing) offset = crossAvailable - cross;
        } else {
            if (_alignment == NSLayoutAttributeTop) offset = [self isFlipped] ? 0 : crossAvailable - cross;
            if (_alignment == NSLayoutAttributeBottom) offset = [self isFlipped] ? crossAvailable - cross : 0;
        }
        if (_distribution == NSStackViewDistributionEqualCentering && count > 1)
            cursor = firstLength / 2 + i * centerStep - length / 2;
        NSRect frame = vertical ? NSMakeRect(area.origin.x + offset,
            [self isFlipped] ? area.origin.y + cursor : NSMaxY(area) - cursor - length, cross, length) :
            NSMakeRect(area.origin.x + cursor, area.origin.y + offset, length, cross);
        [view setFrame:frame]; cursor += length + space;
    }
}
- (void)dealloc { [_arrangedSubviews release]; _arrangedSubviews = nil; [super dealloc]; }
@end
