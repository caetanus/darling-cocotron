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

#import <AppKit/NSPanGestureRecognizer.h>

// OSXER NIB (pan configuration)
@implementation NSPanGestureRecognizer
@synthesize buttonMask = _buttonMask, numberOfTouchesRequired = _numberOfTouchesRequired;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _buttonMask = [coder containsValueForKey:@"NSPanGestureRecognizer.buttonMask"] ? [coder decodeIntegerForKey:@"NSPanGestureRecognizer.buttonMask"] : 1;
        _numberOfTouchesRequired = [coder containsValueForKey:@"NSPanGestureRecognizer.numberOfTouchesRequired"] ? [coder decodeIntegerForKey:@"NSPanGestureRecognizer.numberOfTouchesRequired"] : 1;
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeInteger:_buttonMask forKey:@"NSPanGestureRecognizer.buttonMask"];
    [coder encodeInteger:_numberOfTouchesRequired forKey:@"NSPanGestureRecognizer.numberOfTouchesRequired"];
}
@end
