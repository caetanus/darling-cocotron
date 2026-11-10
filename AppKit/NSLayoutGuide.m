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
- (NSRect)frame { return _osxerLockedToOwner ? [_owningView bounds] : NSZeroRect; }
- (void)dealloc { [_identifier release]; [_osxerSystemConstraints release]; [super dealloc]; }
@end
