/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free softwareyou can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http//www.gnu.org/licenses/>.
*/

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>
@class NSString, NSURL, NSArray;

@protocol NSAccessibility <NSObject>

// OSXER APPKIT (accessibility): stored metadata; no assistive-service transport yet.
@property(copy) NSString * accessibilityLabel;
@property(copy) NSString * accessibilityIdentifier;
@property(copy) NSString * accessibilityHelp;
@property(copy) NSString * accessibilityTitle;
@property(copy) NSString * accessibilityRole;
@property(copy) NSString * accessibilitySubrole;
@property(copy) NSString * accessibilityRoleDescription;
@property(copy) NSString * accessibilityValueDescription;
@property(copy) NSString * accessibilityPlaceholderValue;
@property(copy) NSString * accessibilityFilename;
@property(copy) NSString * accessibilityDocument;
@property(copy) NSURL * accessibilityURL;
@property(copy) NSString * accessibilitySelectedText;
@property(retain) id accessibilityValue;
@property(retain) id accessibilityMinValue;
@property(retain) id accessibilityMaxValue;
@property(assign) id accessibilityParent;
@property(assign) id accessibilityWindow;
@property(assign) id accessibilityTopLevelUIElement;
@property(retain) id accessibilityTitleUIElement;
@property(copy) NSArray *accessibilityLinkedUIElements;
@property(copy) NSArray * accessibilityChildren;
@property(copy) NSArray * accessibilitySelectedChildren;
@property(copy) NSArray * accessibilityVisibleChildren;
@property(copy) NSArray * accessibilityContents;
@property(copy) NSArray * accessibilitySelectedRows;
@property(copy) NSArray * accessibilitySelectedColumns;
@property(copy) NSArray * accessibilityRows;
@property(copy) NSArray * accessibilityColumns;
@property(copy) NSArray * accessibilityVisibleRows;
@property(copy) NSArray * accessibilityVisibleColumns;
@property(copy) NSArray * accessibilityTabs;
@property(copy) NSArray * accessibilitySelectedCells;
@property(copy) NSArray * accessibilityVisibleCells;
@property(getter=isAccessibilityElement) BOOL accessibilityElement;
@property(getter=isAccessibilityEnabled) BOOL accessibilityEnabled;
@property(getter=isAccessibilityFocused) BOOL accessibilityFocused;
@property(getter=isAccessibilitySelected) BOOL accessibilitySelected;
@property(getter=isAccessibilityExpanded) BOOL accessibilityExpanded;
@property(getter=isAccessibilityEdited) BOOL accessibilityEdited;
@property(getter=isAccessibilityRequired) BOOL accessibilityRequired;
@property(getter=isAccessibilityProtectedContent) BOOL accessibilityProtectedContent;
@property(getter=accessibilityIndex) NSInteger accessibilityIndex;
@property(getter=accessibilityNumberOfCharacters) NSInteger accessibilityNumberOfCharacters;
@property(getter=accessibilityInsertionPointLineNumber) NSInteger accessibilityInsertionPointLineNumber;
@property(getter=accessibilityFrame) NSRect accessibilityFrame;
@property(getter=accessibilityActivationPoint) NSPoint accessibilityActivationPoint;
@property(getter=accessibilitySelectedTextRange) NSRange accessibilitySelectedTextRange;
@property(getter=accessibilityVisibleCharacterRange) NSRange accessibilityVisibleCharacterRange;
@end

// OSXER APPKIT (accessibility): legacy and modern access share NSObject receivers.
@interface NSObject (OSXERAccessibilityProperties) <NSAccessibility>
@property(copy) NSString * accessibilityLabel;
@property(copy) NSString * accessibilityIdentifier;
@property(copy) NSString * accessibilityHelp;
@property(copy) NSString * accessibilityTitle;
@property(copy) NSString * accessibilityRole;
@property(copy) NSString * accessibilitySubrole;
@property(copy) NSString * accessibilityRoleDescription;
@property(copy) NSString * accessibilityValueDescription;
@property(copy) NSString * accessibilityPlaceholderValue;
@property(copy) NSString * accessibilityFilename;
@property(copy) NSString * accessibilityDocument;
@property(copy) NSURL * accessibilityURL;
@property(copy) NSString * accessibilitySelectedText;
@property(retain) id accessibilityValue;
@property(retain) id accessibilityMinValue;
@property(retain) id accessibilityMaxValue;
@property(assign) id accessibilityParent;
@property(assign) id accessibilityWindow;
@property(assign) id accessibilityTopLevelUIElement;
@property(retain) id accessibilityTitleUIElement;
@property(copy) NSArray *accessibilityLinkedUIElements;
@property(copy) NSArray * accessibilityChildren;
@property(copy) NSArray * accessibilitySelectedChildren;
@property(copy) NSArray * accessibilityVisibleChildren;
@property(copy) NSArray * accessibilityContents;
@property(copy) NSArray * accessibilitySelectedRows;
@property(copy) NSArray * accessibilitySelectedColumns;
@property(copy) NSArray * accessibilityRows;
@property(copy) NSArray * accessibilityColumns;
@property(copy) NSArray * accessibilityVisibleRows;
@property(copy) NSArray * accessibilityVisibleColumns;
@property(copy) NSArray * accessibilityTabs;
@property(copy) NSArray * accessibilitySelectedCells;
@property(copy) NSArray * accessibilityVisibleCells;
@property(getter=isAccessibilityElement) BOOL accessibilityElement;
@property(getter=isAccessibilityEnabled) BOOL accessibilityEnabled;
@property(getter=isAccessibilityFocused) BOOL accessibilityFocused;
@property(getter=isAccessibilitySelected) BOOL accessibilitySelected;
@property(getter=isAccessibilityExpanded) BOOL accessibilityExpanded;
@property(getter=isAccessibilityEdited) BOOL accessibilityEdited;
@property(getter=isAccessibilityRequired) BOOL accessibilityRequired;
@property(getter=isAccessibilityProtectedContent) BOOL accessibilityProtectedContent;
@property(getter=accessibilityIndex) NSInteger accessibilityIndex;
@property(getter=accessibilityNumberOfCharacters) NSInteger accessibilityNumberOfCharacters;
@property(getter=accessibilityInsertionPointLineNumber) NSInteger accessibilityInsertionPointLineNumber;
@property(getter=accessibilityFrame) NSRect accessibilityFrame;
@property(getter=accessibilityActivationPoint) NSPoint accessibilityActivationPoint;
@property(getter=accessibilitySelectedTextRange) NSRange accessibilitySelectedTextRange;
@property(getter=accessibilityVisibleCharacterRange) NSRange accessibilityVisibleCharacterRange;
@end
