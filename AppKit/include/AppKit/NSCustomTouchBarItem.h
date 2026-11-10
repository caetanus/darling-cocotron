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
#import <AppKit/NSTouchBarItem.h>
#import <Foundation/Foundation.h>

@class NSView, NSViewController;

@interface NSCustomTouchBarItem : NSTouchBarItem {
    NSView *_view;
    // OSXER APPKIT (Touch Bar content)
    NSViewController *_viewController;
    NSString *_customizationLabel;
}
@property(retain) NSView *view;
// OSXER APPKIT (Touch Bar content)
@property(retain) NSViewController *viewController;
@property(copy) NSString *customizationLabel;
@end

// Undocumented, used by Xcode
@interface NSButtonGroupTouchBarItem : NSCustomTouchBarItem
@end
