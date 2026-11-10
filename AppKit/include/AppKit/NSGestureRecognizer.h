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
#import <Foundation/Foundation.h>

// OSXER NIB (gesture configuration): nonretained target/delegate.
@interface NSGestureRecognizer : NSObject <NSCoding> {
    id _target, _delegate;
    SEL _action;
    NSUInteger _allowedTouchTypes;
    BOOL _enabled;
}
@property(assign) id target, delegate;
@property SEL action;
@property NSUInteger allowedTouchTypes;
@property(getter=isEnabled) BOOL enabled;
- (id)initWithTarget:(id)target action:(SEL)action;
@end
