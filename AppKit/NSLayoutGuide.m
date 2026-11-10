/*
 This file is part of Darling.

 Copyright (C) 2021 Lubos Dolezel

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

#import <AppKit/NSLayoutGuide.h>

#import <AppKit/NSView.h>

// OSXER NIB (layout guides): archive state, with ownership managed by NSView.
@implementation NSLayoutGuide
@synthesize identifier = _identifier, owningView = _owningView;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _identifier = [[coder decodeObjectForKey:@"NSLayoutGuideIdentifier"] copy];
        _osxerLockedToOwner = [coder decodeBoolForKey:@"NSLayoutGuideLockedToOwningView"];
        _osxerSystemConstraints = [[coder decodeObjectForKey:@"NSLayoutGuideSystemConstraints"] copy];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_identifier forKey:@"NSLayoutGuideIdentifier"];
    [coder encodeBool:_osxerLockedToOwner forKey:@"NSLayoutGuideLockedToOwningView"];
    [coder encodeObject:_osxerSystemConstraints forKey:@"NSLayoutGuideSystemConstraints"];
}
// OSXER APPKIT (safe area): the guide and view report the same geometry.
- (void)_osxerSetSafeArea:(BOOL)value { _osxerSafeArea = value; }
- (NSRect)frame { return _osxerSafeArea ? [_owningView safeAreaRect] : (_osxerLockedToOwner ? [_owningView bounds] : NSZeroRect); }
- (void)dealloc { [_identifier release]; [_osxerSystemConstraints release]; [super dealloc]; }
@end

// OSXER APPKIT (anchors): no upward dependency from Foundation to AppKit.
#import "OSXERAppKitAPI.h"
@implementation NSLayoutGuide (OSXERAnchors)
- (NSLayoutXAxisAnchor *)leadingAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeLeading); }
- (NSLayoutXAxisAnchor *)trailingAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeTrailing); }
- (NSLayoutXAxisAnchor *)leftAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeLeft); }
- (NSLayoutXAxisAnchor *)rightAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeRight); }
- (NSLayoutYAxisAnchor *)topAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeTop); }
- (NSLayoutYAxisAnchor *)bottomAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeBottom); }
- (NSLayoutDimension *)widthAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutDimension class], NSLayoutAttributeWidth); }
- (NSLayoutDimension *)heightAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutDimension class], NSLayoutAttributeHeight); }
- (NSLayoutXAxisAnchor *)centerXAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutXAxisAnchor class], NSLayoutAttributeCenterX); }
- (NSLayoutYAxisAnchor *)centerYAnchor { return OSXERAppKitAnchor(self, _cmd, [NSLayoutYAxisAnchor class], NSLayoutAttributeCenterY); }
@end
