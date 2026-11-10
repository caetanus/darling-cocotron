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

#import <AppKit/NSCustomTouchBarItem.h>

#import <AppKit/NSViewController.h>
// OSXER APPKIT (Touch Bar content): controller owns its loaded view.
@implementation NSCustomTouchBarItem

// OSXER APPKIT (Touch Bar content): retaining a controller supplies its view.
- (NSViewController *)viewController { return _viewController; }
- (void)setViewController:(NSViewController *)controller {
    [controller retain]; [_viewController release]; _viewController = controller;
    [self setView:[controller view]];
}

@synthesize view = _view;
@synthesize customizationLabel = _customizationLabel;

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

- (void) dealloc {
    // OSXER APPKIT (Touch Bar content)
    [_viewController release];
    [_view release];
    [_customizationLabel release];
    [super dealloc];
}

@end

@implementation NSButtonGroupTouchBarItem

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
