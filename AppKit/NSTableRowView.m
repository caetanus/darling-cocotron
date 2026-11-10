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

#import <AppKit/NSTableRowView.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSGraphics.h>
#import "OSXERAppKitAPI.h"
// OSXER APPKIT (row views): replace untyped forwarding with public state and drawing.
@implementation NSTableRowView
- (BOOL)isSelected { NSNumber *value = objc_getAssociatedObject(self, _cmd); return value ? [value boolValue] : NO; }
- (void)setSelected:(BOOL)value { objc_setAssociatedObject(self, @selector(isSelected), @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsDisplay:YES]; }
- (BOOL)isEmphasized { NSNumber *value = objc_getAssociatedObject(self, _cmd); return value ? [value boolValue] : YES; }
- (void)setEmphasized:(BOOL)value { objc_setAssociatedObject(self, @selector(isEmphasized), @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsDisplay:YES]; }
- (BOOL)isGroupRowStyle { NSNumber *value = objc_getAssociatedObject(self, _cmd); return value ? [value boolValue] : NO; }
- (void)setGroupRowStyle:(BOOL)value { objc_setAssociatedObject(self, @selector(isGroupRowStyle), @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsDisplay:YES]; }
- (BOOL)isFloating { NSNumber *value = objc_getAssociatedObject(self, _cmd); return value ? [value boolValue] : NO; }
- (void)setFloating:(BOOL)value { objc_setAssociatedObject(self, @selector(isFloating), @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsDisplay:YES]; }
- (BOOL)isTargetForDropOperation { NSNumber *value = objc_getAssociatedObject(self, _cmd); return value ? [value boolValue] : NO; }
- (void)setTargetForDropOperation:(BOOL)value { objc_setAssociatedObject(self, @selector(isTargetForDropOperation), @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsDisplay:YES]; }
- (BOOL)isPreviousRowSelected { NSNumber *value = objc_getAssociatedObject(self, _cmd); return value ? [value boolValue] : NO; }
- (void)setPreviousRowSelected:(BOOL)value { objc_setAssociatedObject(self, @selector(isPreviousRowSelected), @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsDisplay:YES]; }
- (BOOL)isNextRowSelected { NSNumber *value = objc_getAssociatedObject(self, _cmd); return value ? [value boolValue] : NO; }
- (void)setNextRowSelected:(BOOL)value { objc_setAssociatedObject(self, @selector(isNextRowSelected), @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsDisplay:YES]; }
OSXER_API_SCALAR(NSTableViewDraggingDestinationFeedbackStyle, draggingDestinationFeedbackStyle, setDraggingDestinationFeedbackStyle, NSTableViewDraggingDestinationFeedbackStyleRegular)
OSXER_API_SCALAR(NSTableViewSelectionHighlightStyle, selectionHighlightStyle, setSelectionHighlightStyle, NSTableViewSelectionHighlightStyleRegular)
OSXER_API_SCALAR(CGFloat, indentationForDropOperation, setIndentationForDropOperation, 0)
- (NSColor *)backgroundColor { return objc_getAssociatedObject(self, _cmd) ?: [NSColor controlBackgroundColor]; }
- (void)setBackgroundColor:(NSColor *)color {
    objc_setAssociatedObject(self, @selector(backgroundColor), color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsDisplay:YES];
}
- (BOOL)isFlipped { return YES; }
- (NSBackgroundStyle)interiorBackgroundStyle {
    return [self isSelected] && [self isEmphasized] ? NSBackgroundStyleDark : NSBackgroundStyleLight;
}
- (void)_osxerSetTable:(NSTableView *)table row:(NSInteger)row { _osxerTable = table; _osxerRow = row; }
- (NSInteger)numberOfColumns { return _osxerTable ? [_osxerTable numberOfColumns] : [[self subviews] count]; }
- (NSView *)viewAtColumn:(NSInteger)column {
    if (column < 0 || column >= [self numberOfColumns]) return nil;
    return _osxerTable ? [_osxerTable viewAtColumn:column row:_osxerRow makeIfNecessary:NO] : [[self subviews] objectAtIndex:column];
}
- (void)drawBackgroundInRect:(NSRect)rect { [[self backgroundColor] setFill]; NSRectFill(rect); }
- (void)drawSelectionInRect:(NSRect)rect {
    if ([self selectionHighlightStyle] == NSTableViewSelectionHighlightStyleNone) return;
    [[self isEmphasized] ? [NSColor alternateSelectedControlColor] : [NSColor secondarySelectedControlColor] setFill];
    NSRectFill(rect);
}
- (void)drawSeparatorInRect:(NSRect)rect { /* Default rows have no separator. */ }
- (void)drawDraggingDestinationFeedbackInRect:(NSRect)rect {
    // Basic outline only; source-list feedback and animation require compositor support.
    if ([self draggingDestinationFeedbackStyle] == NSTableViewDraggingDestinationFeedbackStyleNone) return;
    [[NSColor selectedControlColor] setStroke]; NSFrameRect(rect);
}
- (void)drawRect:(NSRect)rect {
    [self drawBackgroundInRect:rect];
    if ([self isSelected]) [self drawSelectionInRect:rect];
    [self drawSeparatorInRect:rect];
    if ([self isTargetForDropOperation]) [self drawDraggingDestinationFeedbackInRect:rect];
}
@end
