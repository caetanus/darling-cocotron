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

#import <AppKit/AppKitExport.h>
#import <Foundation/Foundation.h>

// OSXER NIB (layout guides): the owner is nonretained, as with NSView's superview.
@class NSView;
@interface NSLayoutGuide : NSObject <NSCoding> {
    NSString *_identifier;
    NSView *_owningView;
    NSArray *_osxerSystemConstraints;
    BOOL _osxerLockedToOwner;
}
@property(copy) NSString *identifier;
@property(assign) NSView *owningView;
@property(readonly) NSRect frame;

@end
