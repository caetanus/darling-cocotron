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

#import <AppKit/AppKitExport.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/NSString.h>

#import <Foundation/NSLayoutConstraint.h>

APPKIT_EXPORT const CGFloat NSViewNoInstrinsicMetric;
APPKIT_EXPORT const CGFloat NSViewNoIntrinsicMetric;

typedef NS_OPTIONS(NSUInteger, NSLayoutFormatOptions) {
    NSLayoutFormatAlignAllLeft = 1 << NSLayoutAttributeLeft,
    NSLayoutFormatAlignAllRight = 1 << NSLayoutAttributeRight,
    NSLayoutFormatAlignAllTop = 1 << NSLayoutAttributeTop,
    NSLayoutFormatAlignAllBottom = 1 << NSLayoutAttributeBottom,
    NSLayoutFormatAlignAllLeading = 1 << NSLayoutAttributeLeading,
    NSLayoutFormatAlignAllTrailing = 1 << NSLayoutAttributeTrailing,
    NSLayoutFormatAlignAllCenterX = 1 << NSLayoutAttributeCenterX,
    NSLayoutFormatAlignAllCenterY = 1 << NSLayoutAttributeCenterY,
    NSLayoutFormatAlignAllLastBaseline = 1 << NSLayoutAttributeLastBaseline,
    NSLayoutFormatAlignAllFirstBaseline = 1 << NSLayoutAttributeFirstBaseline,
    NSLayoutFormatAlignAllBaseline = NSLayoutFormatAlignAllLastBaseline,
    NSLayoutFormatAlignmentMask = 0xFFFF,
    NSLayoutFormatDirectionLeadingToTrailing = 0 << 16,
    NSLayoutFormatDirectionLeftToRight = 1 << 16,
    NSLayoutFormatDirectionRightToLeft = 2 << 16,
    NSLayoutFormatDirectionMask = 0x3 << 16,
};

// OSXER APPKIT (constraint storage): activation installs constraints on views; no solver.
@interface NSLayoutConstraint (OSXERActivation)
+ (NSArray *)constraintsWithVisualFormat:(NSString *)format options:(NSLayoutFormatOptions)options
                                 metrics:(NSDictionary *)metrics views:(NSDictionary *)views;
@property(getter=isActive) BOOL active;
+ (void)activateConstraints:(NSArray *)constraints;
+ (void)deactivateConstraints:(NSArray *)constraints;
@end
