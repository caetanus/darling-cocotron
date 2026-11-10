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

#import <AppKit/NSView.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSCell.h>
// OSXER APPKIT (row views): typed state and basic drawing; source-list effects are partial.
@interface NSTableRowView : NSView {
    NSTableView *_osxerTable; // table owns visible row views
    NSInteger _osxerRow;
}
@property(getter=isSelected) BOOL selected;
@property(getter=isEmphasized) BOOL emphasized;
@property(getter=isGroupRowStyle) BOOL groupRowStyle;
@property(getter=isFloating) BOOL floating;
@property(getter=isTargetForDropOperation) BOOL targetForDropOperation;
@property(getter=isPreviousRowSelected) BOOL previousRowSelected;
@property(getter=isNextRowSelected) BOOL nextRowSelected;
@property NSTableViewDraggingDestinationFeedbackStyle draggingDestinationFeedbackStyle;
@property NSTableViewSelectionHighlightStyle selectionHighlightStyle;
@property CGFloat indentationForDropOperation;
@property(retain) NSColor *backgroundColor;
@property(readonly) NSBackgroundStyle interiorBackgroundStyle;
@property(readonly) NSInteger numberOfColumns;
- (NSView *)viewAtColumn:(NSInteger)column;
- (void)drawBackgroundInRect:(NSRect)rect;
- (void)drawSelectionInRect:(NSRect)rect;
- (void)drawSeparatorInRect:(NSRect)rect;
- (void)drawDraggingDestinationFeedbackInRect:(NSRect)rect;
@end
