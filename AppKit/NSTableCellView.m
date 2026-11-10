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

#import <AppKit/NSTableCellView.h>

// OSXER APPKIT (table cell outlets): the view hierarchy owns the two outlets.
@implementation NSTableCellView
@synthesize textField = _textField, imageView = _imageView, objectValue = _objectValue;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _textField = [coder decodeObjectForKey:@"OSXERTextField"];
        _imageView = [coder decodeObjectForKey:@"OSXERImageView"];
        _objectValue = [[coder decodeObjectForKey:@"OSXERObjectValue"] retain];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeConditionalObject:_textField forKey:@"OSXERTextField"];
    [coder encodeConditionalObject:_imageView forKey:@"OSXERImageView"];
    [coder encodeObject:_objectValue forKey:@"OSXERObjectValue"];
}
- (void)dealloc { [_objectValue release]; [super dealloc]; }
@end
