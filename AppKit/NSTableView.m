/* Copyright (c) 2006-2007 Christopher J. W. Lloyd
                 2009 Markus Hitter <mah@jump-ing.de>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

// OSXER: private Big Sur style hooks.
#import "NSInterfacePart/OSXERBigSurGraphicsStyle.h"
#import "NSKeyValueBinding/NSKVOBinder.h"
#import "NSKeyValueBinding/NSMultipleValueBinder.h"
#import <AppKit/AppKit.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSTableCornerView.h>
#import <Foundation/NSKeyedArchiver.h>
#import "OSXERTableDebug.h"

NSString *const NSTableViewSelectionIsChangingNotification =
        @"NSTableViewSelectionIsChangingNotification";
NSString *const NSTableViewSelectionDidChangeNotification =
        @"NSTableViewSelectionDidChangeNotification";
NSString *const NSTableViewColumnDidMoveNotification =
        @"NSTableViewColumnDidMoveNotification";
NSString *const NSTableViewColumnDidResizeNotification =
        @"NSTableViewColumnDidResizeNotification";

NSString *const NSTableViewRowViewKey = @"NSTableViewRowViewKey";

const CGFloat NSTableViewDefaultRowHeight = 16.0f;

@interface NSTableView (NSTableView_notifications)

- (BOOL) delegateShouldSelectTableColumn: (NSTableColumn *) tableColumn;
- (BOOL) delegateShouldSelectRow: (NSInteger) row;
- (BOOL) delegateShouldEditTableColumn: (NSTableColumn *) tableColumn
                                   row: (NSInteger) row;
- (BOOL) delegateSelectionShouldChange;
- (void) noteSelectionIsChanging;
- (void) noteSelectionDidChange;
- (void) noteColumnDidResizeWithOldWidth: (CGFloat) oldWidth;
- (BOOL) dataSourceCanSetObjectValue;
- (void) dataSourceSetObjectValue: object
                   forTableColumn: (NSTableColumn *) tableColumn
                              row: (NSInteger) row;

@end

#import <AppKit/NSNib.h>
#import <AppKit/NSTableCellView.h>

// OSXER NIB (column visibility): hidden columns consume neither width nor spacing.
static CGFloat OSXERNibColumnExtent(NSTableColumn *column, NSSize spacing) {
    return [column isHidden] ? 0 : [column width] + spacing.width;
}
@implementation NSTableView

- (id) _replacementKeyPathForBinding: (id) binding {
    if ([binding isEqual: @"selectionIndexes"])
        return @"selectedRowIndexes";
    return [super _replacementKeyPathForBinding: binding];
}

+ (Class) _binderClassForBinding: (id) binding {
    if ([binding isEqual: @"content"])
        return [_NSTableViewContentBinder class];
    return [_NSKVOBinder class];
}

- (void) _boundValuesChanged {
    [_tableColumns makeObjectsPerformSelector: @selector(_boundValuesChanged)];
    [self reloadData];
}

- (void) _establishBindingsWithDestinationIfUnbound: (id) destination {
    // this method is called after table column bindings have been established.
    // if the table view doesn't have any bindings at this point, it needs to
    // have its content, sortDescriptors and selectedIndexes bindings
    // established
    if ([[self _allUsedBinders] count] == 0) {
        [self bind: @"content"
                   toObject: destination
                withKeyPath: @"arrangedObjects"
                    options: nil];
        [self bind: @"sortDescriptors"
                   toObject: destination
                withKeyPath: @"sortDescriptors"
                    options: nil];
        [self bind: @"selectionIndexes"
                   toObject: destination
                withKeyPath: @"selectionIndexes"
                    options: nil];
    }
}

- (void) encodeWithCoder: (NSCoder *) coder {
    // OSXER APPKIT (table dragging): encode the fields consumed by our decoder,
    // including independent masks. Private keys only describe our own archives.
    [super encodeWithCoder: coder];
    unsigned flags = (_allowsColumnReordering ? 0x80000000 : 0) |
        (_allowsColumnResizing ? 0x40000000 : 0) |
        (_autoresizesAllColumnsToFit ? 0x00008000 : 0) |
        (_allowsMultipleSelection ? 0x08000000 : 0) |
        (_allowsEmptySelection ? 0x10000000 : 0) |
        (_allowsColumnSelection ? 0x04000000 : 0) |
        (_alternatingRowBackground ? 0x00800000 : 0);
    [coder encodeInt: flags forKey: @"NSTvFlags"];
    [coder encodeObject: _headerView forKey: @"NSHeaderView"];
    [coder encodeObject: _cornerView forKey: @"NSCornerView"];
    [coder encodeObject: _tableColumns forKey: @"NSTableColumns"];
    [coder encodeObject: _backgroundColor forKey: @"NSBackgroundColor"];
    [coder encodeObject: _gridColor forKey: @"NSGridColor"];
    [coder encodeFloat: _standardRowHeight forKey: @"NSRowHeight"];
    [coder encodeInt: _gridStyleMask forKey: @"NSGridStyleMask"];
    [coder encodeInteger: _localDraggingMask forKey: @"OSXERLocalDraggingMask"];
    [coder encodeInteger: _externalDraggingMask forKey: @"OSXERExternalDraggingMask"];
}

- initWithCoder: (NSCoder *) coder {
    [super initWithCoder: coder];
    // OSXER APPKIT (table dragging): documented defaults for older archives.
    _localDraggingMask = NSDragOperationEvery;
    _externalDraggingMask = NSDragOperationNone;

    if ([coder allowsKeyedCoding]) {
        NSKeyedUnarchiver *keyed = (NSKeyedUnarchiver *) coder;
        if ([coder containsValueForKey: @"OSXERLocalDraggingMask"])
            _localDraggingMask = [coder decodeIntegerForKey: @"OSXERLocalDraggingMask"];
        if ([coder containsValueForKey: @"OSXERExternalDraggingMask"])
            _externalDraggingMask = [coder decodeIntegerForKey: @"OSXERExternalDraggingMask"];
        // OSXER APPKIT (table prototypes): embedded NSNibs from the table's
        // archive. Resource keys verified against the supplied NIB fixtures.
        _osxerPrototypeNibs = [[coder decodeObjectForKey:@"NSTableViewArchivedReusableViewsKey"] copy];
        NSDictionary *external = [coder decodeObjectForKey:@"NSTableViewCellPrototypeNibExternalObjects"];
        NSMutableDictionary *others = [NSMutableDictionary dictionary];
        NSMutableArray *selfIdentifiers = [NSMutableArray array];
        for (NSString *key in external) {
            id value = [external objectForKey:key];
            if (value == self) [selfIdentifiers addObject:key];
            else [others setObject:value forKey:key];
        }
        _osxerPrototypeExternalObjects = [others copy];
        _osxerPrototypeSelfIdentifiers = [selfIdentifiers copy];
        unsigned flags = [keyed decodeIntForKey: @"NSTvFlags"];

        _headerView = [[keyed decodeObjectForKey: @"NSHeaderView"] retain];
        [_headerView setTableView: self];
        _cornerView = [[keyed decodeObjectForKey: @"NSCornerView"] retain];
        _tableColumns = [[NSMutableArray alloc]
                initWithArray: [keyed decodeObjectForKey: @"NSTableColumns"]];
        [_tableColumns makeObjectsPerformSelector: @selector(setTableView:)
                                       withObject: self];
        _backgroundColor =
                [[keyed decodeObjectForKey: @"NSBackgroundColor"] retain];
        _gridColor = [[keyed decodeObjectForKey: @"NSGridColor"] retain];
        _rowHeightsCount = 0;
        _rowHeights = NULL;
        _standardRowHeight = [keyed decodeFloatForKey: @"NSRowHeight"];
        _allowsColumnReordering = (flags & 0x80000000) ? YES : NO;
        _allowsColumnResizing = (flags & 0x40000000) ? YES : NO;
        _autoresizesAllColumnsToFit = (flags & 0x00008000) ? YES : NO;
        _allowsMultipleSelection = (flags & 0x08000000) ? YES : NO;
        _allowsEmptySelection = (flags & 0x10000000) ? YES : NO;
        _allowsColumnSelection = (flags & 0x04000000) ? YES : NO;
        _intercellSpacing = NSMakeSize(3.0, 2.0);
        // OSXER NIB (table geometry and style)
        if ([coder containsValueForKey:@"NSIntercellSpacingWidth"]) _intercellSpacing.width = [coder decodeDoubleForKey:@"NSIntercellSpacingWidth"];
        if ([coder containsValueForKey:@"NSIntercellSpacingHeight"]) _intercellSpacing.height = [coder decodeDoubleForKey:@"NSIntercellSpacingHeight"];
        if ([coder containsValueForKey:@"NSTableViewSelectionHighlightStyle"]) [self setSelectionHighlightStyle:[coder decodeIntegerForKey:@"NSTableViewSelectionHighlightStyle"]];
        if ([coder containsValueForKey:@"NSTableViewStyle"]) [self setStyle:[coder decodeIntegerForKey:@"NSTableViewStyle"]];
        if ([coder containsValueForKey:@"NSDraggingSourceMaskForLocal"]) _localDraggingMask = [coder decodeIntegerForKey:@"NSDraggingSourceMaskForLocal"];
        if ([coder containsValueForKey:@"NSDraggingSourceMaskForNonLocal"]) _externalDraggingMask = [coder decodeIntegerForKey:@"NSDraggingSourceMaskForNonLocal"];
        _selectedRowIndexes = [[NSIndexSet alloc] init];
        _selectedColumns = [[NSMutableArray alloc] init];
        _editedColumn = -1;
        _editedRow = -1;
        _numberOfRows = -1;
        _draggingRow = -1;

        // row background and grid attributes for OS X >= 10.3
        _alternatingRowBackground = (flags & 0x00800000) ? YES : NO;
        if ([keyed containsValueForKey: @"NSGridStyleMask"])
            _gridStyleMask = [keyed decodeIntForKey: @"NSGridStyleMask"];
        else
            _gridStyleMask = NSTableViewGridNone;
    } else {
        [NSException raise: NSInvalidArgumentException
                    format: @"-[%@ %s] is not implemented for coder %@",
                            [self class], sel_getName(_cmd), coder];
    }
    return self;
}

- initWithFrame: (NSRect) frame {
    [super initWithFrame: frame];
    // OSXER APPKIT (table dragging): documented initial drag policy.
    _localDraggingMask = NSDragOperationEvery;
    _externalDraggingMask = NSDragOperationNone;
    _rowHeightsCount = 0;
    _rowHeights = NULL;
    // OSXER: only defaults change; explicit/nib row heights remain respected.
    _standardRowHeight = OSXERBigSurEnabled() ? 17 : NSTableViewDefaultRowHeight;
    // OSXER BIGSUR R2 (table pitch): reference row starts 369,391,413,...;
    // explicit rowHeight=22 must not acquire the old extra 2 px gap.
    _intercellSpacing = OSXERBigSurEnabled() ? NSMakeSize(3, 0) : NSMakeSize(3, 2);
    _selectedRowIndexes = [[NSIndexSet alloc] init];
    _selectedColumns = [[NSMutableArray alloc] init];
    _editedColumn = -1;
    _editedRow = -1;
    _numberOfRows = -1;
    _draggingRow = -1;

    _allowsColumnReordering = YES;
    _allowsColumnResizing = YES;
    _autoresizesAllColumnsToFit =
            NO; // the default isn't actually given in the spec, but this seems
                // more like default behavior
    _allowsMultipleSelection = NO;
    _allowsEmptySelection = YES;
    _allowsColumnSelection = YES;

    _headerView = [[NSTableHeaderView alloc]
            initWithFrame: NSMakeRect(0, 0, [self bounds].size.width,
                                      _standardRowHeight +
                                              _intercellSpacing.height)];
    [_headerView setTableView: self];

    _cornerView = [[NSTableCornerView alloc]
            initWithFrame: NSMakeRect(0, 0, _standardRowHeight,
                                      _standardRowHeight)];

    if (OSXERBigSurEnabled()) {
        // OSXER BIGSUR R2 (header): y341..368 = 28 px incl. bottom rule.
        [_headerView setFrameSize: NSMakeSize(NSWidth(frame), 28)];
        [_cornerView setFrameSize: NSMakeSize(_standardRowHeight, 28)];
    }

    _tableColumns = [[NSMutableArray alloc] init];
    _backgroundColor = [[NSColor controlBackgroundColor] retain];
    _gridColor = [[NSColor gridColor] retain];

    // row background and grid attributes for OS X >= 10.3
    _alternatingRowBackground = NO;
    _gridStyleMask = NSTableViewGridNone;

    return self;
}

- (void) dealloc {
    // OSXER APPKIT (view tables)
    [_osxerRegisteredNibs release]; [_osxerPrototypeNibs release];
    [_osxerPrototypeExternalObjects release]; [_osxerPrototypeSelfIdentifiers release];
    [_osxerCellViews release]; [_osxerReuse release];
    NSZoneFree(NULL, _rowHeights);
    [_headerView release];
    [_cornerView release];
    [_tableColumns release];
    [_backgroundColor release];
    [_gridColor release];
    [_selectedRowIndexes release];
    [_selectedColumns release];
    [_sortDescriptors release];
    [super dealloc];
}

- target {
    return _target;
}

- (SEL) action {
    return _action;
}

- (SEL) doubleAction {
    return _doubleAction;
}

- dataSource {
    return _dataSource;
}

- delegate {
    return _delegate;
}

- (NSView *) headerView {
    return _headerView;
}

- (NSView *) cornerView {
    return [[_cornerView retain] autorelease];
}

- (CGFloat) rowHeight {
    return _standardRowHeight;
}

- (NSSize) intercellSpacing {
    return _intercellSpacing;
}

- (NSColor *) backgroundColor {
    return _backgroundColor;
}

- (NSColor *) gridColor {
    return _gridColor;
}

- (NSString *) autosaveName {
    NSUnimplementedMethod();
    return nil;
}

// deprecated in OS X >= 10.3
// use gridStyleMask instead
- (BOOL) drawsGrid {
    return _gridStyleMask != NSTableViewGridNone;
}

- (NSTableViewSelectionHighlightStyle) selectionHighlightStyle {
    return _selectionHighlightStyle;
}

- (BOOL) allowsColumnReordering {
    return _allowsColumnReordering;
}

- (BOOL) allowsColumnResizing {
    return _allowsColumnResizing;
}

- (BOOL) autoresizesAllColumnsToFit {
    return _autoresizesAllColumnsToFit;
}

- (BOOL) allowsMultipleSelection {
    return _allowsMultipleSelection;
}

- (BOOL) allowsEmptySelection {
    return _allowsEmptySelection;
}

- (BOOL) allowsColumnSelection {
    return _allowsColumnSelection;
}

- (BOOL) autosaveTableColumns {
    NSUnimplementedMethod();
    return NO;
}

// row background and grid attributes for OS X >= 10.3
- (BOOL) usesAlternatingRowBackgroundColors {
    return _alternatingRowBackground;
}

- (unsigned int) gridStyleMask {
    return _gridStyleMask;
}

- (NSInteger) numberOfRows {

    if (_numberOfRows < 0) {
        id binding = [self _binderForBinding: @"content"];

        if (binding)
            _numberOfRows = [binding numberOfRows];

        if (_numberOfRows < 0) {
            if (_dataSource == nil)
                _numberOfRows = 0;
            else {
                if ([_dataSource respondsToSelector: @selector
                                 (numberOfRowsInTableView:)] == YES)
                    _numberOfRows = [_dataSource numberOfRowsInTableView: self];
                else {
                    // Apple AppKit only logs here, so we do the same.
                    NSLog(@"data source %@ does not respond to "
                          @"numberOfRowsInTableView:",
                          _dataSource);
                    _numberOfRows = 0;
                }
            }
        }
    }

    return _numberOfRows;
}

- (NSUInteger) numberOfColumns {
    return [_tableColumns count];
}

- (NSArray *) tableColumns {
    return _tableColumns;
}

- (NSInteger) columnWithIdentifier: (id) identifier {
    NSEnumerator *tableColumnEnumerator = [_tableColumns objectEnumerator];
    NSTableColumn *column;

    NSInteger idx = 0;
    while ((column = [tableColumnEnumerator nextObject]) != nil) {
        if ([[column identifier] isEqual: identifier])
            return idx;

        idx++;
    }

    return -1;
}

- (NSTableColumn *) tableColumnWithIdentifier: identifier {
    NSEnumerator *tableColumnEnumerator = [_tableColumns objectEnumerator];
    NSTableColumn *column;

    while ((column = [tableColumnEnumerator nextObject]) != nil)
        if ([[column identifier] isEqual: identifier])
            return column;

    return nil;
}

static CGFloat rowHeightAtIndex(NSTableView *self, NSInteger index) {
    if (index < self->_rowHeightsCount)
        return self->_rowHeights[index];

    return self->_standardRowHeight;
}

- (NSRect) rectOfRow: (NSInteger) row {
    NSRect rect = _bounds;
    NSInteger i, count;

    if (row < 0 || row >= [self numberOfRows]) {
        return NSZeroRect;
    }

    rect.origin.x = 0.;
    rect.origin.y = 0.;
    for (i = 0; i < row; i++)
        rect.origin.y += rowHeightAtIndex(self, i) + _intercellSpacing.height;

    rect.size.width = 0.;
    count = [_tableColumns count];
    for (i = 0; i < count; i++)
        rect.size.width += OSXERNibColumnExtent([_tableColumns objectAtIndex: i], _intercellSpacing);
    rect.size.height = rowHeightAtIndex(self, row) + _intercellSpacing.height;

    return rect;
}

- (NSRect) rectOfColumn: (NSInteger) column {
    NSInteger numberOfRows = [self numberOfRows];
    NSRect rect = _bounds;
    NSInteger i;

    if (column < 0 || column >= [_tableColumns count]) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"rectOfColumn: invalid index %ld (valid {%d, %lu})",
                            (long) column, 0, (unsigned long) [_tableColumns count]];
    }

    if ([[_tableColumns objectAtIndex:column] isHidden]) return NSZeroRect;
    rect.origin.x = 0.;
    for (i = 0; i < column; i++)
        rect.origin.x += OSXERNibColumnExtent([_tableColumns objectAtIndex: i], _intercellSpacing);
    rect.origin.y = 0.;

    rect.size.width = OSXERNibColumnExtent([_tableColumns objectAtIndex: column], _intercellSpacing);
    rect.size.height = 0.;
    for (i = 0; i < numberOfRows; i++)
        rect.size.height +=
                rowHeightAtIndex(self, i) + _intercellSpacing.height;
    rect.size.height =
            MAX(rect.size.height, [[self superview] bounds].size.height);

    return rect;
}

- (NSRange) rowsInRect: (NSRect) rect {
    NSRange range = NSMakeRange(0, 0);
    NSInteger numberOfRows = [self numberOfRows];
    NSInteger i;
    CGFloat height = 0.;

    for (i = 0; i < numberOfRows; i++) {
        if (height + rowHeightAtIndex(self, i) + _intercellSpacing.height >
            rect.origin.y)
            break;
        else
            height += rowHeightAtIndex(self, i) + _intercellSpacing.height;
    }
    if (i < numberOfRows) {
        range.location = i;

        for (; i < numberOfRows; i++) {
            if (height > rect.origin.y + rect.size.height)
                break;
            else
                height += rowHeightAtIndex(self, i) + _intercellSpacing.height;
        }
        if (i < numberOfRows)
            range.length = i - range.location + 1;
        else
            range.length = numberOfRows - range.location;
    }

    return range; // returns 0,0 if not found, not NSNotFound
}

// OSXER NIB (column visibility): preserve public indexes when columns are hidden.
- (NSRange) columnsInRect: (NSRect) rect {
    NSUInteger first = NSNotFound, last = 0;
    CGFloat x = 0;
    for (NSUInteger i = 0; i < [_tableColumns count]; ++i) {
        CGFloat width = OSXERNibColumnExtent([_tableColumns objectAtIndex:i], _intercellSpacing);
        if (width > 0 && x + width > NSMinX(rect) && x <= NSMaxX(rect)) {
            if (first == NSNotFound) first = i;
            last = i;
        }
        x += width;
    }
    return first == NSNotFound ? NSMakeRange(0, 0) : NSMakeRange(first, last - first + 1);
}

- (NSInteger) rowAtPoint: (NSPoint) point {
    NSInteger row = -1;
    NSRange range;

    range = [self rowsInRect: NSMakeRect(point.x, point.y, 0., 0.)];
    if (range.length != 0)
        row = range.location;

    return row;
}

- (NSInteger) columnAtPoint: (NSPoint) point {
    NSInteger column = -1;
    NSRange range;

    range = [self columnsInRect: NSMakeRect(point.x, point.y, 0., 0.)];
    if (range.length != 0)
        column = range.location;

    return column;
}

- (NSRect) frameOfCellAtColumn: (NSInteger) column row: (NSInteger) row {
    NSRect frame;
    NSInteger i;

    if (column < 0 || column >= [self numberOfColumns] || row < 0 ||
        row >= [self numberOfRows])
        return NSZeroRect;

    if ([[_tableColumns objectAtIndex:column] isHidden]) return NSZeroRect;
    frame.origin.x = 0.;
    for (i = 0; i < column; i++)
        frame.origin.x += OSXERNibColumnExtent([_tableColumns objectAtIndex: i], _intercellSpacing);

    frame.origin.y = 0.;
    for (i = 0; i < row; i++)
        frame.origin.y += rowHeightAtIndex(self, i) + _intercellSpacing.height;

    frame.size.width = OSXERNibColumnExtent([_tableColumns objectAtIndex: column], _intercellSpacing);
    frame.size.height = rowHeightAtIndex(self, row) + _intercellSpacing.height;

    return frame;
}

- (void) setTarget: target {
    _target = target;
}

- (void) setAction: (SEL) action {
    _action = action;
}

- (void) setDoubleAction: (SEL) action {
    _doubleAction = action;
}

- (void) setDataSource: dataSource {
    _dataSource = dataSource;
    [self tile]; // documented
}

- (void) setDelegate: delegate {
    struct {
        NSString *name;
        SEL selector;
    } notes[] = {{NSTableViewSelectionDidChangeNotification,
                  @selector(tableViewSelectionDidChange:)},
                 {NSTableViewColumnDidMoveNotification,
                  @selector(tableViewColumnDidMove:)},
                 {NSTableViewColumnDidResizeNotification,
                  @selector(tableViewColumnDidResize:)},
                 {NSTableViewSelectionIsChangingNotification,
                  @selector(tableViewSelectionIsChanging:)},
                 {nil, NULL}};
    NSInteger i;

    if (_delegate != nil)
        for (i = 0; notes[i].name != nil; ++i)
            [[NSNotificationCenter defaultCenter] removeObserver: _delegate
                                                            name: notes[i].name
                                                          object: self];

    // OSXER APPKIT (view owners): a new delegate needs fresh nib connections.
    if (_delegate != delegate) {
        for (id view in [_osxerCellViews allValues])
            if (view != [NSNull null]) [view removeFromSuperview];
        [_osxerCellViews removeAllObjects]; [_osxerReuse removeAllObjects];
        [self setNeedsDisplay:YES];
    }
    _delegate = delegate;

    for (i = 0; notes[i].name != nil; ++i)
        if ([_delegate respondsToSelector: notes[i].selector])
            [[NSNotificationCenter defaultCenter] addObserver: _delegate
                                                     selector: notes[i].selector
                                                         name: notes[i].name
                                                       object: self];
}

- (void) setHeaderView: (NSTableHeaderView *) headerView {
    [headerView retain];
    [_headerView release];
    _headerView = headerView;
    [_headerView setTableView: self];
    [[self enclosingScrollView] tile];
}

- (void) setCornerView: (NSView *) view {
    [view retain];
    [_cornerView release];
    _cornerView = view;
    [[self enclosingScrollView] tile];
}

- (void) setRowHeight: (CGFloat) height {
    NSInteger numberOfRows = [self numberOfRows];
    NSInteger i;

    if (height > 0.)
        _standardRowHeight = height;
    else
        // Cocoa doesn't even NSLog() here, instead the table isn't drawn.
        _standardRowHeight = 0.;

    for (i = 0; i < _rowHeightsCount; i++)
        _rowHeights[i] = _standardRowHeight;

    [self tile];
}

- (void) setIntercellSpacing: (NSSize) size {
    _intercellSpacing = size;
    [self setNeedsDisplay: YES];
}

- (void) setBackgroundColor: (NSColor *) color {
    color = [color retain];
    [_backgroundColor release];
    _backgroundColor = color;
}

- (void) setGridColor: (NSColor *) color {
    color = [color retain];
    [_gridColor release];
    _gridColor = color;
}

- (void) setAutosaveName: (NSString *) name {
    NSUnimplementedMethod();
}

// deprecated in OS X >= 10.3
// use setGridStyleMask instead
- (void) setDrawsGrid: (BOOL) flag {
    if (flag)
        _gridStyleMask = NSTableViewSolidVerticalGridLineMask |
                         NSTableViewSolidHorizontalGridLineMask;
    else
        _gridStyleMask = NSTableViewGridNone;
}

- (void) setAllowsColumnReordering: (BOOL) flag {
    _allowsColumnReordering = flag;
}

- (void) setAllowsColumnResizing: (BOOL) flag {
    _allowsColumnResizing = flag;
}

- (void) setAutoresizesAllColumnsToFit: (BOOL) flag {
    _autoresizesAllColumnsToFit = flag;
}

- (void) setAllowsMultipleSelection: (BOOL) flag {
    _allowsMultipleSelection = flag;
}

- (void) setAllowsEmptySelection: (BOOL) flag {
    _allowsEmptySelection = flag;
}

- (void) setAllowsColumnSelection: (BOOL) flag {
    _allowsColumnSelection = flag;
}

- (void) setAutosaveTableColumns: (BOOL) flag {
    NSUnimplementedMethod();
}

// row background and grid attributes for OS X >= 10.3
- (void) setUsesAlternatingRowBackgroundColors: (BOOL) flag {
    _alternatingRowBackground = flag;
}

- (void) setGridStyleMask: (unsigned int) gridStyle {
    _gridStyleMask = gridStyle;
    [self setNeedsDisplay: YES];
}

- (void) setSelectionHighlightStyle: (NSTableViewSelectionHighlightStyle) value
{
    _selectionHighlightStyle = value;
    [self setNeedsDisplay: YES];
}

// the appkit dox are pretty vague on these two. should they trigger a redraw or
// reloadData? also.. i wonder if remove should use an isEqual method in
// NSTableColumn, or removeObjectIdenticalTo...
- (void) addTableColumn: (NSTableColumn *) column {
    [_tableColumns addObject: column];
    [column setTableView: self];
    [self reloadData];
    [_headerView setNeedsDisplay: YES];
}

- (void) removeTableColumn: (NSTableColumn *) column {
    [column setTableView: nil];
    [_tableColumns removeObject: column];
    [self reloadData];
    [_headerView setNeedsDisplay: YES];
}

- (void) moveColumn: (NSInteger) columnIndex toColumn: (NSInteger) newIndex {
    NSUnimplementedMethod();
}

- (NSInteger) editedRow {
    return _editedRow;
}

- (NSInteger) editedColumn {
    return _editedColumn;
}

- (id) dataSourceObjectValueForTableColumn: (NSTableColumn *) tableColumn
                                       row: (NSInteger) row
{

    if (_dataSource != nil &&
        [_dataSource respondsToSelector: @selector
                     (tableView:objectValueForTableColumn:row:)] == YES)
        return [_dataSource tableView: self
                objectValueForTableColumn: tableColumn
                                      row: row];

    id binder = [tableColumn _binderForBinding: @"value"];
    id vals = [[binder destination]
            valueForKeyPath: [binder valueForKey: @"keyPath"]];
    if (vals != nil) {
        return [vals objectAtIndex: row];
    }
    // Apple AppKit only logs here, so we do the same.
    NSLog(@"data source %@ does not respond to "
          @"tableView:objectValueForTableColumn:row:",
          _dataSource);
    return nil;
}

- (NSRect) _adjustedFrame: (NSRect) frame forCell: (NSCell *) dataCell {
    // OSXER BIGSUR R2 (table text): ref ink starts x25 vs viewport x17,
    // 8 px total (5 cell offset + 2 text inset + 1 font bearing).
    frame.origin.x += _intercellSpacing.width + (OSXERBigSurEnabled() ? 2 : -1);
    frame.origin.y += _intercellSpacing.height;
    frame.size.width -= _intercellSpacing.width;
    frame.size.height -= _intercellSpacing.height;
    if ([dataCell isKindOfClass: [NSTextFieldCell class]])
        frame.size.height--;
    else {
        frame.origin.x--;
        frame.origin.y--;
    }
    if (frame.origin.x < 0.)
        frame.origin.x = 0.;
    if (frame.origin.y < 0.)
        frame.origin.y = 0.;
    if (frame.size.width < 0.)
        frame.size.width = 0.;
    if (frame.size.height < 0.)
        frame.size.height = 0.;

    return frame;
}

- (void) editColumn: (NSInteger) column
                row: (NSInteger) row
          withEvent: (NSEvent *) event
             select: (BOOL) select
{
    if (_editingCell)
        [self textDidEndEditing: nil];

    NSCell *editingCell;
    NSTableColumn *editingColumn = [_tableColumns objectAtIndex: column];
    NSInteger numberOfRows = [self numberOfRows];

    // light sanity check; invalid columns caught above in objectAtIndex:
    if (row < 0 || row >= numberOfRows)
        [NSException raise: NSInvalidArgumentException
                    format: @"invalid row in %@", NSStringFromSelector(_cmd)];

    if (![editingColumn isEditable])
        return;

    if ([self delegateShouldEditTableColumn: editingColumn row: row] == NO)
        return;

    if ([self dataSourceCanSetObjectValue] == NO &&
        [[editingColumn _binderForBinding: @"value"
                                   create: NO] allowsEditingForRow: row] == NO)
        [NSException raise: NSInternalInconsistencyException
                    format: @"data source does not respond to "
                            @"tableView:setObjectValue:forTableColumn:row: and "
                            @"binding is read-only"];

    editingCell = [[self preparedCellAtColumn: column row: row] copy];

    [_editingCell release];
    _editingCell = nil;
    _editedColumn = column;
    _editedRow = row;
    _editingFrame = _editingBorder = [self frameOfCellAtColumn: column
                                                           row: row];
    _editingFrame = [self _adjustedFrame: _editingFrame forCell: editingCell];
    _editingBorder.origin.x--;
    _editingBorder.origin.y--;
    _editingBorder.size.width++;
    _editingBorder.size.height++;
    if ([editingCell isKindOfClass: [NSTextFieldCell class]]) {
        _editingCell = editingCell;

        [_editingCell setDrawsBackground: YES];
        [_editingCell setBackgroundColor: _backgroundColor];

        NSText *oldEditor = _currentEditor;
        [_currentEditor setDelegate: nil];
        NSText *editor = [[self window] fieldEditor: YES forObject: self];
        _currentEditor =
                [[_editingCell setUpFieldEditorAttributes: editor] retain];
        [_currentEditor setDelegate: self];
        [oldEditor release];

        if (select == YES)
            [_editingCell selectWithFrame: _editingFrame
                                   inView: self
                                   editor: _currentEditor
                                 delegate: self
                                    start: 0
                                   length: [[_editingCell stringValue] length]];
        else
            [_editingCell editWithFrame: _editingFrame
                                 inView: self
                                 editor: _currentEditor
                               delegate: self
                                  event: event];

        [self setNeedsDisplay: YES];
    } else
        [editingCell release];
}

- (NSInteger) clickedRow {
    return _clickedRow;
}

- (NSInteger) clickedColumn {
    return _clickedColumn;
}

- (NSArray *) sortDescriptors {
    if (!_sortDescriptors)
        _sortDescriptors = [NSArray new];
    return [[_sortDescriptors retain] autorelease];
}

- (void) setSortDescriptors: (NSArray *) value {
    if (_sortDescriptors != value) {
        [_sortDescriptors release];
        _sortDescriptors = [value copy];
    }
}

- (NSIndexSet *) selectedRowIndexes {
    return _selectedRowIndexes;
}

// Use this so that KVO/Bindings notifications work automatically
- (void) _setSelectedRowIndexes: (NSIndexSet *) value {
    value = [value copy];
    [_selectedRowIndexes release];
    _selectedRowIndexes = value;

    if ([_selectedRowIndexes count] == 0 && !_allowsEmptySelection) {
        [_selectedRowIndexes release];
        _selectedRowIndexes = [[NSIndexSet alloc] initWithIndex: 0];
    }

    if ([_selectedRowIndexes count] > 0 && [_selectedColumns count] > 0) {
        // selecting a row deselects the previously selected column
        [_selectedColumns removeAllObjects];
        [self setNeedsDisplay: YES];
        [_headerView setNeedsDisplay: YES];
    }

    [self noteSelectionDidChange];
}

// That's the setter for _selectedRowIndexes.
- (void) selectRowIndexes: (NSIndexSet *) indexes
        byExtendingSelection: (BOOL) extend
{
    unsigned index;
    NSIndexSet *newIndexes;
    NSInteger i, last,
    try
        ;
    BOOL changed = NO;

    // Mac OS X doesn't raise an exception if one of the indices
    // is out of range. Instead, the selection is left untouched.
    if ([indexes firstIndex] != NSNotFound &&
        ([indexes firstIndex] < 0 ||
         [indexes lastIndex] >= [self numberOfRows]))
        return;

    // Selecting a row deselects all columns.
    if ([_selectedColumns count]) {
        [_selectedColumns removeAllObjects];
        [self setNeedsDisplay: YES];
        [_headerView setNeedsDisplay: YES];
        changed = YES;
    }

    if (extend) {
        NSMutableIndexSet *mutableIndexes = [[NSMutableIndexSet alloc]
                initWithIndexSet: _selectedRowIndexes];
        [mutableIndexes addIndexes: indexes];
        newIndexes = [[[NSIndexSet alloc] initWithIndexSet: mutableIndexes]
                autorelease];
        [mutableIndexes release];
    } else
        newIndexes = indexes;

    // Find the changed rows and mark them for redraw.
    i = [_selectedRowIndexes firstIndex];
    if (i == NSNotFound)
        i = [newIndexes firstIndex];
    else {
        try
            = [newIndexes firstIndex];
        if (try != NSNotFound && try < i)
            i =
            try
                ;
    }
    last = [_selectedRowIndexes lastIndex];
    if (last == NSNotFound)
        last = [newIndexes lastIndex];
    else {
        try
            = [newIndexes lastIndex];
        if (try != NSNotFound && try > last)
            last =
            try
                ;
    }
    if (i != NSNotFound) // If i is valid, last is valid as well.
        for (; i <= last; i++)
            if ([_selectedRowIndexes containsIndex: i] !=
                [newIndexes containsIndex: i]) {
                if (_editedRow == i && _editingCell != nil)
                    [self textDidEndEditing: nil];

                [self setNeedsDisplay: YES];
                changed = YES;
                // NSLog(@"NSTableView row %d for redraw.", i);
            }

    if (changed)
        [self _setSelectedRowIndexes: newIndexes];
}

- (NSInteger) selectedRow {
    NSInteger row = [_selectedRowIndexes firstIndex];

    if (row == NSNotFound)
        return -1;

    return row;
}

- (NSInteger) selectedColumn {
    if ([_selectedColumns count] == 0)
        return -1;

    return [_tableColumns indexOfObject: [_selectedColumns objectAtIndex: 0]];
}

- (NSInteger) numberOfSelectedRows {
    return [_selectedRowIndexes count];
}

- (NSInteger) numberOfSelectedColumns {
    return [_selectedColumns count];
}

- (BOOL) isRowSelected: (NSInteger) row {
    return [_selectedRowIndexes containsIndex: row];
}

- (BOOL) isColumnSelected: (NSInteger) col {
    return [_selectedColumns
            containsObject: [_tableColumns objectAtIndex: col]];
}

- (NSEnumerator *) selectedColumnEnumerator {
    return [_selectedColumns objectEnumerator];
}

- (NSIndexSet *) selectedColumnIndexes {
    NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
    NSInteger i, count = [_selectedColumns count];

    for (i = 0; i < count; i++) {
        NSInteger index = [_tableColumns
                indexOfObjectIdenticalTo: [_selectedColumns objectAtIndex: i]];
        [result addIndex: index];
    }

    return result;
}

// Deprecated in Mac OS X 10.3.
- (NSEnumerator *) selectedRowEnumerator {
    NSMutableArray *rows = [NSMutableArray array];
    NSUInteger i, count = [_selectedRowIndexes count];
    NSUInteger buffer[count];

    [_selectedRowIndexes getIndexes: buffer maxCount: count inIndexRange: NULL];
    for (i = 0; i < count; i++)
        [rows addObject: [NSNumber numberWithInteger: buffer[i]]];

    return [rows objectEnumerator];
}

// Deprecated in Mac OS X 10.3.
- (void) selectRow: (NSInteger) row byExtendingSelection: (BOOL) extend {

    if (extend) {
        NSUInteger startRow = [self selectedRow], endRow = row;
        if (startRow > endRow) {
            endRow = startRow;
            startRow = row;
        }
        [self selectRowIndexes: [NSIndexSet
                                        indexSetWithIndexesInRange:
                                                NSMakeRange(startRow,
                                                            endRow - startRow +
                                                                    1)]
                byExtendingSelection: NO];
    } else
        [self selectRowIndexes: [NSIndexSet indexSetWithIndex: row]
                byExtendingSelection: NO];
}

- (void) selectColumn: (NSInteger) column byExtendingSelection: (BOOL) extend {
    NSTableColumn *tableColumn = [_tableColumns objectAtIndex: column];

    // selecting a column deselects all rows
    [self selectRowIndexes: [NSIndexSet indexSet] byExtendingSelection: NO];

    if (extend == NO)
        [_selectedColumns removeAllObjects];

    if ([_selectedColumns containsObject: tableColumn] == NO) {
        if ([self delegateShouldSelectTableColumn: tableColumn] == YES)
            [_selectedColumns addObject: tableColumn];
    }

    [self noteSelectionDidChange];
    [self setNeedsDisplay: YES];
    [_headerView setNeedsDisplay: YES];
}

- (void) deselectRow: (NSInteger) row {
    NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];

    if ([selectedRowIndexes containsIndex: row]) {
        NSMutableIndexSet *newSelection =
                [[selectedRowIndexes mutableCopy] autorelease];

        [newSelection removeIndex: row];
        [self selectRowIndexes: newSelection byExtendingSelection: NO];
    }
}

- (void) deselectColumn: (NSInteger) column {
    if ([_selectedColumns
                containsObject: [_tableColumns objectAtIndex: column]]) {
        [_selectedColumns removeObject: [_tableColumns objectAtIndex: column]];
        [self setNeedsDisplayInRect: [self rectOfColumn: column]];
        [_headerView setNeedsDisplay: YES];
    }
}

- (void) selectAll: sender {
    [self selectRowIndexes: [NSIndexSet
                                    indexSetWithIndexesInRange:
                                            NSMakeRange(0, [self numberOfRows])]
            byExtendingSelection: NO];
}

- (void) deselectAll: sender {
    [self selectRowIndexes: [NSIndexSet indexSet] byExtendingSelection: NO];
    [_selectedColumns removeAllObjects];
}

- (void) scrollRowToVisible: (NSInteger) index {
    [self scrollRectToVisible: [self rectOfRow: index]];
}

- (void) scrollColumnToVisible: (NSInteger) index {
    [self scrollRectToVisible: [self rectOfColumn: index]];
}

// This also resizes the row heights cache size as appropriate.
- (void) noteHeightOfRowsWithIndexesChanged: (NSIndexSet *) indexSet {
    NSInteger numberOfRows = [self numberOfRows];
    NSInteger row;

    if ([indexSet firstIndex] != NSNotFound &&
        ([indexSet firstIndex] < 0 || [indexSet lastIndex] >= numberOfRows))
        [NSException raise: NSInternalInconsistencyException
                    format: @"Index set %@ out of range (valid are 0 to %ld).",
                            indexSet, (long) numberOfRows];

    _rowHeights = realloc(_rowHeights, sizeof(CGFloat) * numberOfRows);

    row = [indexSet firstIndex];
    if (_delegate != nil && [_delegate respondsToSelector: @selector
                                       (tableView:heightOfRow:)] == YES) {
        while (row != NSNotFound) {
            _rowHeights[row] = [_delegate tableView: self heightOfRow: row];
            row = [indexSet indexGreaterThanIndex: row];
        }
    } else {
        while (row != NSNotFound) {
            _rowHeights[row] = _standardRowHeight;
            row = [indexSet indexGreaterThanIndex: row];
        }
    }
}

- (void) noteNumberOfRowsChanged {
    NSSize size = [self frame].size;
    NSSize headerSize = [_headerView frame].size;

    _numberOfRows = -1;
    NSInteger numberOfRows = [self numberOfRows];

    // There isn't much point in trying to validate the heights of
    // visible rows only, as the often used -rectOfColumn: needs them all.
    [self noteHeightOfRowsWithIndexesChanged:
                    [NSIndexSet
                            indexSetWithIndexesInRange: NSMakeRange(
                                                                0,
                                                                numberOfRows)]];

    // if there's any editing going on, we'd better stop it.
    if (_editingCell != nil)
        [self textDidEndEditing: nil];

    if (numberOfRows > 0) {
        size.width = [self rectOfRow: 0].size.width;
    }
    if ([_tableColumns count] > 0)
        size.height = [self rectOfColumn: 0].size.height;

    // OSXER BIGSUR R2 (table coverage): reference stripes/selection reach
    // x351, immediately before the scroller. Do not shrink below the viewport
    // when reloadData recomputes the sum of explicit column widths.
    if (OSXERBigSurEnabled()) size.width = MAX(size.width, [[self superview] bounds].size.width);
    headerSize.width = size.width;

    [self setFrameSize: size];
    [_headerView setFrameSize: headerSize];

    NSMutableIndexSet *selection =
            [[_selectedRowIndexes mutableCopy] autorelease];
    NSInteger count = [selection count];
    NSUInteger indexes[count];
    [selection getIndexes: indexes maxCount: count inIndexRange: NULL];

    while (--count >= 0) {
        if (indexes[count] >= numberOfRows)
            [selection removeIndex: indexes[count]];
    }

    /* Do not change the selection if it didnt change. _setSelectedRowIndexes
       posts a notification and doing it unnecessarily can cause performance and
       behavior problems. For example, if there is no selection in a newly
       created tableview and you post the notification indirectly with
       setDataSource:, an application which expects a non-empty selection will
       have problems.

       FIXME: investigate whether _setSelectedRowIndexes: should do this check
       or not.
      */
    if (![selection isEqualToIndexSet: _selectedRowIndexes])
        [self _setSelectedRowIndexes: selection];
}

// OSXER APPKIT (view tables): keep the delegate/binding substitution points.
- (BOOL)_osxerUsesCellViews {
    return [_delegate respondsToSelector:@selector(tableView:viewForTableColumn:row:)] ||
        [_osxerPrototypeNibs count] || [_osxerRegisteredNibs count];
}
- (NSDictionary *)registeredNibsByIdentifier {
    return _osxerRegisteredNibs ? [[_osxerRegisteredNibs copy] autorelease] : [NSDictionary dictionary];
}
- (void)registerNib:(NSNib *)nib forIdentifier:(NSUserInterfaceItemIdentifier)identifier {
    if (!identifier) [NSException raise:NSInvalidArgumentException format:@"Missing view identifier"];
    if (!_osxerRegisteredNibs) _osxerRegisteredNibs = [NSMutableDictionary new];
    if (nib) [_osxerRegisteredNibs setObject:nib forKey:identifier];
    else [_osxerRegisteredNibs removeObjectForKey:identifier];
    [_osxerReuse removeObjectForKey:identifier];
}
- (NSView *)makeViewWithIdentifier:(NSUserInterfaceItemIdentifier)identifier owner:(id)owner {
    if (!identifier) [NSException raise:NSInvalidArgumentException format:@"Missing view identifier"];
    NSMutableArray *pool = [_osxerReuse objectForKey:identifier];
    NSView *view = [[[pool lastObject] retain] autorelease];
    if (view) { [pool removeLastObject]; return view; }
    NSNib *nib = [_osxerRegisteredNibs objectForKey:identifier];
    BOOL prototype = nib == nil;
    if (!nib) nib = [_osxerPrototypeNibs objectForKey:identifier];
    if (!nib) return nil;
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableDictionary *names = [NSMutableDictionary dictionary];
    if (prototype && [_osxerPrototypeExternalObjects isKindOfClass:[NSDictionary class]])
        [names addEntriesFromDictionary:_osxerPrototypeExternalObjects];
    if (prototype) for (NSString *key in _osxerPrototypeSelfIdentifiers) [names setObject:self forKey:key];
    if (owner) [names setObject:owner forKey:NSNibOwner];
    [names setObject:objects forKey:NSNibTopLevelObjects];
    if (![nib instantiateNibWithExternalNameTable:names]) return nil;
    for (id object in objects) {
        if ([object isKindOfClass:[NSView class]] && [[object identifier] isEqual:identifier]) view = object;
    }
    // A registered nib can contain a single cell without a preassigned identifier.
    if (!view) for (id object in objects) {
        if ([object isKindOfClass:[NSView class]] && ![object identifier]) { view = object; break; }
    }
    [[view retain] autorelease];
    [view setIdentifier:identifier];
    // The legacy NSNib entry point gives the caller ownership of each root.
    for (id object in objects) [object autorelease];
    return view;
}
- (void)_osxerRecycleCellAtKey:(NSArray *)key {
    NSView *view = [_osxerCellViews objectForKey:key];
    if (view != (id)[NSNull null]) {
        NSString *identifier = [view identifier];
        if (identifier) {
            if (!_osxerReuse) _osxerReuse = [NSMutableDictionary new];
            NSMutableArray *pool = [_osxerReuse objectForKey:identifier];
            if (!pool) { pool = [NSMutableArray array]; [_osxerReuse setObject:pool forKey:identifier]; }
            [pool addObject:view];
        }
        [view removeFromSuperview];
    }
    [_osxerCellViews removeObjectForKey:key];
}
- (NSView *)viewAtColumn:(NSInteger)column row:(NSInteger)row makeIfNecessary:(BOOL)make {
    if (row < 0 || row >= [self numberOfRows] || column < 0 || column >= [_tableColumns count]) return nil;
    if ([[_tableColumns objectAtIndex:column] isHidden]) return nil; // OSXER NIB (column visibility)
    NSArray *key = @[@(row), @(column)];
    id view = [_osxerCellViews objectForKey:key];
    if (view) return view == [NSNull null] ? nil : view;
    if (!make || ![self _osxerUsesCellViews]) return nil;
    NSTableColumn *tableColumn = [_tableColumns objectAtIndex:column];
    if ([_delegate respondsToSelector:@selector(tableView:viewForTableColumn:row:)])
        view = [_delegate tableView:self viewForTableColumn:tableColumn row:row];
    else view = [self makeViewWithIdentifier:[tableColumn identifier] owner:_delegate];
    if (!_osxerCellViews) _osxerCellViews = [NSMutableDictionary new];
    [_osxerCellViews setObject:view ?: (id)[NSNull null] forKey:key];
    if (view) {
        if ([view respondsToSelector:@selector(setObjectValue:)]) {
            id binder = [self _binderForBinding:@"content"];
            NSArray *content = [[binder destination] valueForKeyPath:[binder valueForKey:@"keyPath"]];
            if (content && row < [content count]) [view setObjectValue:[content objectAtIndex:row]];
            else if ([_dataSource respondsToSelector:@selector(tableView:objectValueForTableColumn:row:)] ||
                     [tableColumn _binderForBinding:@"value"])
                [view setObjectValue:[self dataSourceObjectValueForTableColumn:tableColumn row:row]];
        }
        [view setFrame:[self frameOfCellAtColumn:column row:row]];
        [self addSubview:view];
    }
    return view;
}
- (NSInteger)rowForView:(NSView *)view {
    for (NSArray *key in _osxerCellViews) {
        id cell = [_osxerCellViews objectForKey:key];
        if (cell != [NSNull null] && [view isDescendantOf:cell]) return [[key objectAtIndex:0] integerValue];
    }
    return -1;
}
- (NSInteger)columnForView:(NSView *)view {
    for (NSArray *key in _osxerCellViews) {
        id cell = [_osxerCellViews objectForKey:key];
        if (cell != [NSNull null] && [view isDescendantOf:cell]) return [[key objectAtIndex:1] integerValue];
    }
    return -1;
}
- (void)_osxerTileCellViews {
    if (_osxerTilingViews || _osxerUpdateDepth || ![self _osxerUsesCellViews]) return;
    _osxerTilingViews = YES;
    @try {
        NSRect visible = [self visibleRect];
        NSRange rows = [self rowsInRect:visible], columns = [self columnsInRect:visible];
        for (NSArray *key in [_osxerCellViews allKeys]) {
            NSInteger row = [[key objectAtIndex:0] integerValue], col = [[key objectAtIndex:1] integerValue];
            if (!NSLocationInRange(row, rows) || !NSLocationInRange(col, columns) || row >= [self numberOfRows] ||
                col < 0 || col >= [_tableColumns count] || [[_tableColumns objectAtIndex:col] isHidden])
                [self _osxerRecycleCellAtKey:key];
        }
        for (NSUInteger row = rows.location; row < NSMaxRange(rows) && row < [self numberOfRows]; ++row)
            for (NSUInteger col = columns.location; col < NSMaxRange(columns) && col < [_tableColumns count]; ++col)
                [[self viewAtColumn:col row:row makeIfNecessary:YES] setFrame:[self frameOfCellAtColumn:col row:row]];
    } @finally { _osxerTilingViews = NO; }
}
- (void)beginUpdates { ++_osxerUpdateDepth; }
- (void)endUpdates {
    if (!_osxerUpdateDepth) [NSException raise:NSInternalInconsistencyException format:@"Unbalanced table updates"];
    if (!--_osxerUpdateDepth) [self tile];
}
- (void)reloadDataForRowIndexes:(NSIndexSet *)rows columnIndexes:(NSIndexSet *)columns {
    for (NSArray *key in [_osxerCellViews allKeys])
        if ([rows containsIndex:[[key objectAtIndex:0] unsignedIntegerValue]] &&
            [columns containsIndex:[[key objectAtIndex:1] unsignedIntegerValue]]) [self _osxerRecycleCellAtKey:key];
    [self _osxerTileCellViews];
    [self setNeedsDisplay:YES];
}

- (void) reloadData {
    // OSXER APPKIT (view tables): invalidation makes old views available for reuse.
    for (NSArray *key in [_osxerCellViews allKeys]) [self _osxerRecycleCellAtKey:key];
    [self noteNumberOfRowsChanged];
    [self setNeedsDisplay: YES];
    [_headerView setNeedsDisplay: YES];
}

- (void) tile {
    NSRect rect;

    [self sizeLastColumnToFit];
    [self noteNumberOfRowsChanged];
    rect = [_headerView frame];
    rect.size.width = [self frame].size.width;
    [_headerView setFrameSize: rect.size];

    [self _osxerTileCellViews];
    [[self enclosingScrollView]
            setVerticalLineScroll: _standardRowHeight +
                                   _intercellSpacing.height];

    [self setNeedsDisplay: YES];
    [_headerView setNeedsDisplay: YES];
}

- (void) sizeLastColumnToFit {
    NSClipView *clipView = (NSClipView *) [self superview];

    if ([clipView isKindOfClass: [NSClipView class]]) {
        NSSize size = [clipView bounds].size;
        // OSXER NIB (column visibility): size only visible columns.
        NSMutableArray *visible = [NSMutableArray array];
        for (NSTableColumn *column in _tableColumns) if (![column isHidden]) [visible addObject:column];
        NSInteger i, count = [visible count];
        CGFloat lastWidth = size.width - (count * _intercellSpacing.width);
        NSTableColumn *lastColumn = [visible lastObject];
        for (i = 0; i < count - 1; ++i) lastWidth -= [[visible objectAtIndex:i] width];

        if (lastWidth > 0)
            [lastColumn setWidth: lastWidth];
        else if (lastWidth < 0)
            [lastColumn setWidth: [lastColumn width] + lastWidth];

        [self setNeedsDisplay: YES];
    }
}

- (void) drawHighlightedSelectionForColumn: (NSInteger) column
                                       row: (NSInteger) row
                                    inRect: (NSRect) rect
{
    [[NSColor selectedControlColor] setFill];
    NSRectFill(rect);
}

- (void) highlightSelectionInClipRect: (NSRect) rect {
    // OSXER: row selection covers spacing and the full visible width.
    if (OSXERBigSurEnabled()) {
        [(OSXERBigSurGraphicsStyle *) [self graphicsStyle]
                drawTableSelection: self clipRect: rect];
        return;
    }
    NSInteger row, column;
    NSInteger numberOfRows = [self numberOfRows];

    for (column = 0; column < [_tableColumns count]; ++column)
        for (row = 0; row < numberOfRows; ++row)
            if ([self isColumnSelected: column] || [self isRowSelected: row])
                if (!(row == _editedRow && column == _editedColumn))
                    [self drawHighlightedSelectionForColumn: column
                                                        row: row
                                                     inRect: [self frameOfCellAtColumn:
                                                                             column
                                                                                   row: row]];
}

- (NSCell *) preparedCellAtColumn: (NSInteger) columnNumber
                              row: (NSInteger) row
{
    NSTableColumn *column = [_tableColumns objectAtIndex: columnNumber];
    if ([column isHidden]) return nil; // OSXER NIB (column visibility)
    NSCell *dataCell = [column dataCellForRow: row];

    [dataCell setControlView: self];
    id value = [self dataSourceObjectValueForTableColumn: column row: row];
    if ([dataCell isKindOfClass: [NSPopUpButtonCell class]]) {
        [(NSPopUpButtonCell *) dataCell selectItemAtIndex: [value intValue]];
    } else {
        [dataCell setObjectValue: value];
    }

    if ([dataCell respondsToSelector: @selector(setTextColor:)]) {
        if ([self isRowSelected: row] ||
            [self isColumnSelected: columnNumber]) {
            [(NSTextFieldCell *) dataCell
                    setDrawsBackground: NO]; // so the selection shows properly,
                                             // dont just set the color so
                                             // custom background works
            [(NSTextFieldCell *) dataCell
                    setTextColor: OSXERBigSurEnabled()
                            ? [(OSXERBigSurGraphicsStyle *) [self graphicsStyle]
                                    tableSelectionTextColor: self]
                            : [NSColor selectedTextColor]];
        } else
            // OSXER BIGSUR DARK (table ink): resolve against the row surface.
            [(NSTextFieldCell *) dataCell setTextColor: OSXERBigSurEnabled()
                    ? [(OSXERBigSurGraphicsStyle *)[self graphicsStyle] tableTextColor: self row: row]
                    : [NSColor textColor]];
    }

    [column prepareCell: dataCell inRow: row];

    if ([_delegate respondsToSelector: @selector
                   (tableView:willDisplayCell:forTableColumn:row:)])
        [_delegate tableView: self
                willDisplayCell: dataCell
                 forTableColumn: column
                            row: row];

    // Temporary diagnostics: do not log application text contents.
    if (OSXERTableDebugEnabled()) {
        NSFont *font = [dataCell font];
        NSColor *textColor = [dataCell respondsToSelector: @selector(textColor)]
                ? [(NSTextFieldCell *) dataCell textColor] : nil;
        int drawsBackground = [dataCell respondsToSelector: @selector(drawsBackground)]
                ? [(NSTextFieldCell *) dataCell drawsBackground] : -1;
        int hidden = [dataCell respondsToSelector: @selector(isHidden)]
                ? [(NSView *) dataCell isHidden] : -1;
        fprintf(stderr, "[OSXER_TABLE_DEBUG] preparedCell column=%ld row=%ld "
                        "class=%s stringValue.length=%lu textColor=%s "
                        "font=%s size=%.2f lineHeight=%.2f "
                        "drawsBackground=%d isHidden=%d enabled=%d\n",
                (long) columnNumber, (long) row,
                [NSStringFromClass([dataCell class]) UTF8String] ?: "(nil)",
                (unsigned long) [[dataCell stringValue] length],
                [[textColor description] UTF8String] ?: "(nil)",
                [[font fontName] UTF8String] ?: "(nil)",
                (double) [font pointSize], (double) [font defaultLineHeightForFont],
                drawsBackground, hidden, [dataCell isEnabled]);
        fflush(stderr);
    }

    return dataCell;
}

- (void) drawRow: (NSInteger) row clipRect: (NSRect) clipRect {
    // OSXER APPKIT (view tables): subviews draw after the table's background.
    if ([self _osxerUsesCellViews]) { [self _osxerTileCellViews]; return; }
    // draw only visible columns.
    NSRange visibleColumns = [self columnsInRect: clipRect];
    NSInteger drawThisColumn = visibleColumns.location;
    NSInteger numberOfRows = [self numberOfRows];

    if (row < 0 || row >= numberOfRows)
        [NSException raise: NSInvalidArgumentException
                    format: @"invalid row in drawRow:clipRect:"];

    if (OSXERTableDebugEnabled()) {
        fprintf(stderr, "[OSXER_TABLE_DEBUG] drawRow row=%ld rect=%s clip=%s columns=%s\n",
                (long) row, [NSStringFromRect([self rectOfRow: row]) UTF8String],
                [NSStringFromRect(clipRect) UTF8String],
                [NSStringFromRange(visibleColumns) UTF8String]);
        fflush(stderr);
    }

    for (; drawThisColumn < NSMaxRange(visibleColumns); drawThisColumn++) {

        if (row == _editedRow && drawThisColumn == _editedColumn &&
            _editingCell != nil) {
            [_backgroundColor setFill];
            NSRectFill(_editingBorder);
            [_editingCell setControlView: self];
            [_editingCell drawWithFrame: _editingFrame inView: self];
            if ([_editingCell focusRingType] != NSFocusRingTypeNone) {
                [[NSColor keyboardFocusIndicatorColor] setStroke];
                NSFrameRectWithWidth(_editingBorder, 2.0);
            }
        } else {
            NSCell *dataCell = [self preparedCellAtColumn: drawThisColumn
                                                      row: row];
            NSRect cellRect = [self
                    _adjustedFrame: [self frameOfCellAtColumn: drawThisColumn
                                                          row: row]
                           forCell: dataCell];

            if (OSXERTableDebugEnabled()) {
                fprintf(stderr, "[OSXER_TABLE_DEBUG] drawCell column=%ld row=%ld frame=%s\n",
                        (long) drawThisColumn, (long) row,
                        [NSStringFromRect(cellRect) UTF8String]);
                fflush(stderr);
            }

            [dataCell drawWithFrame: cellRect inView: self];
        }
    }
}

- (void) drawBackgroundInClipRect: (NSRect) clipRect {
    // OSXER: palette stripes, including the exposed area after the last row.
    if (OSXERBigSurEnabled()) {
        [(OSXERBigSurGraphicsStyle *) [self graphicsStyle]
                drawTableBackground: self clipRect: clipRect];
        return;
    }
    NSArray *rowColors = [NSColor controlAlternatingRowBackgroundColors];
    NSInteger colorCount = [rowColors count];

    if (colorCount == 0 || !_alternatingRowBackground) {
        [_backgroundColor setFill];
        NSRectFill(clipRect);
    } else if (colorCount == 1) {
        [(NSColor *) [rowColors objectAtIndex: 0] setFill];
        NSRectFill(clipRect);
    } else {
        NSRange rangeOfRows = [self rowsInRect: clipRect];
        NSInteger i;
        NSRect rectToFill = clipRect;
        CGFloat heightFilled = 0.;

        for (i = rangeOfRows.location;
             i < rangeOfRows.location + rangeOfRows.length; i++) {
            rectToFill = [self rectOfRow: i];

            [(NSColor *) [rowColors objectAtIndex: i % colorCount] setFill];
            NSRectFill(rectToFill);
            rectToFill.origin.y +=
                    rectToFill.size.height; // This is for beyond the loop.
            heightFilled = rectToFill.origin.y;
        }
        if (_standardRowHeight > 0.) {
            rectToFill.size.height =
                    _standardRowHeight + _intercellSpacing.height;
            while (heightFilled < clipRect.size.height) {
                [(NSColor *) [rowColors objectAtIndex: i % colorCount] setFill];
                NSRectFill(rectToFill);
                heightFilled += rectToFill.size.height;
                rectToFill.origin.y += rectToFill.size.height;
                i++;
            }
        }
    }
}

// That is, draw a line one pixel wide in color gridColor at the
// bottom/right of each row/column, including the last row/column.
// Verified by comparing screen shots on Mac OS X 10.4.10.
- (void) drawGridInClipRect: (NSRect) clipRect {
    NSBezierPath *line = [NSBezierPath bezierPath];
    NSInteger i, n;
    CGFloat x, y;

    [_gridColor setStroke];

    if ((_gridStyleMask & NSTableViewSolidVerticalGridLineMask) ==
        NSTableViewSolidVerticalGridLineMask) {
        NSRange rangeOfColumns = [self columnsInRect: clipRect];
        n = rangeOfColumns.location + rangeOfColumns.length;
        for (i = rangeOfColumns.location; i < n; i++) {
            NSRect columnRect = [self rectOfColumn: i];
            x = columnRect.origin.x + columnRect.size.width +
                ((i < n - 1) ? -0.5 : 0.5);
            y = clipRect.origin.y;
            [line moveToPoint: NSMakePoint(x, y)];
            [line lineToPoint: NSMakePoint(x, y + clipRect.size.height)];
        }
    }

    if ((_gridStyleMask & NSTableViewSolidHorizontalGridLineMask) ==
        NSTableViewSolidHorizontalGridLineMask) {
        NSRange rangeOfRows = [self rowsInRect: clipRect];
        n = rangeOfRows.location + rangeOfRows.length;
        y = -0.5;
        for (i = rangeOfRows.location; i < n; i++) {
            NSRect rowRect = [self rectOfRow: i];
            x = clipRect.origin.x;
            y = rowRect.origin.y + rowRect.size.height - 0.5;
            [line moveToPoint: NSMakePoint(x, y)];
            [line lineToPoint: NSMakePoint(x + clipRect.size.width, y)];
        }

        if (_standardRowHeight > 0.0) {
            while (y < clipRect.size.height) {
                y += _standardRowHeight + _intercellSpacing.height;
                [line moveToPoint: NSMakePoint(clipRect.origin.x, y)];
                [line lineToPoint: NSMakePoint(clipRect.origin.x +
                                                       clipRect.size.width,
                                               y)];
            }
        }
    }

    [line stroke];
}

// can't use rectOfRow because empty tableviews will explode!
- (CGFloat) _displayWidthOfColumns {
    NSInteger i, count = [_tableColumns count];
    CGFloat result = 0;

    for (i = 0; i < count; ++i)
        result += OSXERNibColumnExtent([_tableColumns objectAtIndex: i], _intercellSpacing);

    return result;
}

- (void) resizeWithOldSuperviewSize: (NSSize) oldSize {
    NSSize size = [self frame].size;

    if (size.width < [[self superview] bounds].size.width) {
        size.width = [[self superview] bounds].size.width;
        [self setFrameSize: size];
    }

    if (_autoresizesAllColumnsToFit) {
        CGFloat delta = [[self enclosingScrollView] contentSize].width -
                        [self _displayWidthOfColumns];
        // OSXER NIB (column visibility)
        NSUInteger count = 0;
        for (NSTableColumn *column in _tableColumns) if (![column isHidden]) ++count;
        for (NSTableColumn *column in _tableColumns)
            if (![column isHidden]) [column setWidth:[column width] + floor(delta / count)];

    } else
        [self sizeLastColumnToFit];

    [self tile];
}

- (BOOL) isFlipped {
    return YES;
}

- (BOOL) delegateShouldSelectTableColumn: (NSTableColumn *) tableColumn {
    if ([_delegate respondsToSelector: @selector(tableView:
                                               shouldSelectTableColumn:)])
        return [_delegate tableView: self shouldSelectTableColumn: tableColumn];

    return YES;
}

- (BOOL) delegateShouldSelectRow: (NSInteger) row {
    if ([_delegate respondsToSelector: @selector(tableView:shouldSelectRow:)])
        return [_delegate tableView: self shouldSelectRow: row];

    return YES;
}

- (void) dataSourceSetObjectValue: object
                   forTableColumn: (NSTableColumn *) tableColumn
                              row: (NSInteger) row
{
    if ([_dataSource respondsToSelector: @selector
                     (tableView:setObjectValue:forTableColumn:row:)])
        [_dataSource tableView: self
                setObjectValue: object
                forTableColumn: tableColumn
                           row: row];
}

- (BOOL) abortEditing {
    [super abortEditing];
    [_editingCell release];
    _editingCell = nil;
    [self setNeedsDisplayInRect: NSInsetRect(_editingBorder, -1, -1)];
    _editingFrame = NSMakeRect(-1, -1, -1, -1);
    _editedRow = -1;
    _editedColumn = -1;
    return NO;
}

- (void) textDidEndEditing: (NSNotification *) note {
    NSTableColumn *editedColumn = [_tableColumns objectAtIndex: _editedColumn];
    NSInteger textMovement =
            [[[note userInfo] objectForKey: @"NSTextMovement"] intValue];
    NSInteger numberOfRows = [self numberOfRows];

    [_editingCell endEditing: _currentEditor];

    if (_editedRow >= 0 && _editedRow < numberOfRows) {
        if ([self dataSourceCanSetObjectValue]) {
            [self dataSourceSetObjectValue: [_editingCell objectValue]
                            forTableColumn: editedColumn
                                       row: _editedRow];
        } else {
            [[editedColumn _binderForBinding: @"value"
                                      create: NO] applyFromCell: _editingCell
                                                          inRow: _editedRow];
        }
    }

    [self abortEditing];
    [_window makeFirstResponder: nil];

    // NSReturnTextMovement has lousy behaviour , fix.
    // don't really need any of the text movement stuff, so we ignore it for now
    textMovement = NSIllegalTextMovement;

    if (textMovement == NSReturnTextMovement) {
        NSInteger nextRow = _editedRow + 1;

        if (nextRow >= numberOfRows)
            nextRow = 0;

        [self selectRow: nextRow byExtendingSelection: NO];
        [self editColumn: _editedColumn
                      row: nextRow
                withEvent: [[self window] currentEvent]
                   select: YES];
    } else if (textMovement == NSTabTextMovement) {
        NSInteger nextColumn = _editedColumn;
        NSInteger nextRow = _editedRow;

        do {
            nextColumn++;
            if (nextColumn >= [_tableColumns count]) {
                nextColumn = 0;
                nextRow++;
                if (nextRow >= numberOfRows)
                    nextRow = 0;
            }

            if ([[_tableColumns objectAtIndex: nextColumn] isEditable])
                break;
        } while (YES);

        [self selectRow: nextRow byExtendingSelection: NO];
        [self editColumn: nextColumn
                      row: nextRow
                withEvent: [[self window] currentEvent]
                   select: YES];
    } else if (textMovement == NSBacktabTextMovement) {
        NSInteger prevColumn = _editedColumn - 1;
        NSInteger prevRow = _editedRow;

        if (prevColumn < 0) {
            prevColumn = [_tableColumns count] - 1;
            prevRow -= 1;
            if (prevRow < 0)
                prevRow = numberOfRows - 1;
        }

        [self selectRow: prevRow byExtendingSelection: NO];
        [self editColumn: prevColumn
                      row: prevRow
                withEvent: [[self window] currentEvent]
                   select: YES];
    } else {
        _editedColumn = -1;
        _editedRow = -1;
    }
}

- (BOOL) delegateShouldEditTableColumn: (NSTableColumn *) tableColumn
                                   row: (NSInteger) row
{
    if ([_delegate respondsToSelector: @selector(tableView:
                                               shouldEditTableColumn:row:)])
        return [_delegate tableView: self
                shouldEditTableColumn: tableColumn
                                  row: row];

    return YES;
}

- (void) updateCell: (NSCell *) sender {
    // blank
}

- (void) updateCellInside: (NSCell *) cell {
    // blank
}

- (void) drawRect: (NSRect) clipRect {
    NSRange visibleRows;
    NSInteger drawThisRow, numberOfRows = [self numberOfRows];

    if (OSXERTableDebugEnabled()) {
        fprintf(stderr, "[OSXER_TABLE_DEBUG] NSTableView drawRect dirty=%s "
                        "bounds=%s visible=%s rowsInRect=%s columnsInRect=%s "
                        "rows=%ld hidden=%d alternating=%d grid=%lu\n",
                [NSStringFromRect(clipRect) UTF8String],
                [NSStringFromRect([self bounds]) UTF8String],
                [NSStringFromRect([self visibleRect]) UTF8String],
                [NSStringFromRange([self rowsInRect: clipRect]) UTF8String],
                [NSStringFromRange([self columnsInRect: clipRect]) UTF8String],
                (long) numberOfRows, [self isHiddenOrHasHiddenAncestor],
                _alternatingRowBackground, (unsigned long) _gridStyleMask);
        fflush(stderr);
    }

    [self drawBackgroundInClipRect: clipRect];

    if (numberOfRows > 0) {
        [self highlightSelectionInClipRect: clipRect];

        visibleRows = [self rowsInRect: clipRect];
        if (visibleRows.length > 0) {
            drawThisRow = visibleRows.location;

            // FIX: Always drawing entire rows is inefficient.
            //      Should draw visible cells, only.
            while (drawThisRow < NSMaxRange(visibleRows) &&
                   drawThisRow < numberOfRows)
                [self drawRow: drawThisRow++ clipRect: clipRect];
        }
    }

    if ([self drawsGrid])
        [self drawGridInClipRect: clipRect];

    if (_draggingRow >= 0) {
        NSRect rowRect;
        [[NSColor blackColor] setStroke];
        if ([self numberOfRows] == 0)
            [NSBezierPath
                    strokeLineFromPoint: NSMakePoint(0, 0)
                                toPoint: NSMakePoint([self bounds].size.width,
                                                     0)];
        else {
            if (_draggingRow == [self numberOfRows]) {
                rowRect = NSIntersectionRect([self rectOfRow: _draggingRow - 1],
                                             [self visibleRect]);
                [NSBezierPath
                        strokeLineFromPoint: NSMakePoint(
                                                     0, rowRect.origin.y +
                                                                rowRect.size
                                                                        .height)
                                    toPoint: NSMakePoint(
                                                     rowRect.size.width,
                                                     rowRect.origin.y +
                                                             rowRect.size
                                                                     .height)];
            } else {
                rowRect = NSIntersectionRect([self rectOfRow: _draggingRow],
                                             [self visibleRect]);
                [NSBezierPath
                        strokeLineFromPoint: NSMakePoint(0, rowRect.origin.y)
                                    toPoint: NSMakePoint(rowRect.size.width,
                                                         rowRect.origin.y)];
            }
        }
    }
}

- (BOOL) delegateSelectionShouldChange {
    if ([_delegate respondsToSelector: @selector
                   (selectionShouldChangeInTableView:)])
        return [_delegate selectionShouldChangeInTableView: self];

    return YES;
}

- (void) noteSelectionIsChanging {
    [[NSNotificationCenter defaultCenter]
            postNotificationName: NSTableViewSelectionIsChangingNotification
                          object: self];
}

- (void) noteSelectionDidChange {
    [[NSNotificationCenter defaultCenter]
            postNotificationName: NSTableViewSelectionDidChangeNotification
                          object: self];
}

- (void) noteColumnDidResizeWithOldWidth: (CGFloat) oldWidth {
    [[NSNotificationCenter defaultCenter]
            postNotificationName: NSTableViewColumnDidResizeNotification
                          object: self
                        userInfo: [NSDictionary
                                          dictionaryWithObjectsAndKeys:
                                                  [NSNumber numberWithFloat:
                                                                    oldWidth],
                                                  @"NSOldWidth", nil]];
}

- (BOOL) dataSourceCanSetObjectValue {
    return [_dataSource respondsToSelector: @selector
                        (tableView:setObjectValue:forTableColumn:row:)];
}

- (void) mouseDown: (NSEvent *) event {
    NSPoint location = [self convertPoint: [event locationInWindow]
                                 fromView: nil];
    NSInteger numberOfRows = [self numberOfRows];

    _clickedColumn = [self columnAtPoint: location];
    _clickedRow = [self rowAtPoint: location];

    if (_clickedRow < 0) { // click beyond the end of the table
        if (_editingCell != nil)
            [self textDidEndEditing: nil];
        [self selectRowIndexes: [NSIndexSet indexSet] byExtendingSelection: NO];
        [_selectedColumns removeAllObjects];
        return;
    }

    NSTableColumn *clickedColumnObject =
            [_tableColumns objectAtIndex: _clickedColumn];

    if (![self delegateShouldSelectTableColumn: clickedColumnObject])
        return;
    if (![self delegateShouldSelectRow: _clickedRow])
        return;

    NSCell *clickedCell = [clickedColumnObject dataCellForRow: _clickedRow];

    [clickedCell setControlView: self];
    if ([clickedCell isKindOfClass: [NSButtonCell class]]) {
        [clickedCell
                setObjectValue:
                        [self dataSourceObjectValueForTableColumn:
                                        clickedColumnObject
                                                              row: _clickedRow]];

        if ([clickedCell trackMouse: event
                             inRect: [self frameOfCellAtColumn: _clickedColumn
                                                           row: _clickedRow]
                             ofView: self
                       untilMouseUp: YES]) {
            [clickedCell setNextState];
            NSNumber *value = nil;
            if ([clickedCell isKindOfClass: [NSPopUpButtonCell class]]) {
                value = [NSNumber
                        numberWithInt: [(NSPopUpButtonCell *) clickedCell
                                               indexOfSelectedItem]];
            } else {
                value = [NSNumber numberWithInt: [clickedCell state]];
            }
            [self dataSourceSetObjectValue: value
                            forTableColumn: clickedColumnObject
                                       row: _clickedRow];
            [self sendAction: [clickedCell action] to: [clickedCell target]];
        }

        [self setNeedsDisplay: YES];

        return;
    }

    // NSLog(@"click in col %d row %d", _clickedColumn, _clickedRow);
    // single click behavior
    if ([event clickCount] < 2) {
        if ([self delegateSelectionShouldChange] ==
            NO) // provide delegate opportunity
            return;

        if ([event modifierFlags] &
            NSAlternateKeyMask) {                    // extend/change selection
            if ([self isRowSelected: _clickedRow]) { // deselect previously
                                                     // selected?
                if ([self allowsEmptySelection] ||
                    [self numberOfSelectedColumns] > 1)
                    [self deselectRow: _clickedRow];
            } else if ([self allowsMultipleSelection]) {
                [self selectRowIndexes: [NSIndexSet
                                                indexSetWithIndex: _clickedRow]
                        byExtendingSelection: YES]; // add to selection
            }
        } else if ([event modifierFlags] & NSShiftKeyMask) {
            if ([self allowsMultipleSelection] && [self selectedRow] != -1) {
                NSInteger startRow = [self selectedRow];
                NSInteger endRow = _clickedRow;

                if (_clickedRow < startRow) {
                    endRow = startRow;
                    startRow = _clickedRow;
                }

                [self selectRowIndexes:
                                [NSIndexSet
                                        indexSetWithIndexesInRange:
                                                NSMakeRange(startRow,
                                                            endRow - startRow +
                                                                    1)]
                        byExtendingSelection: NO];
            } else
                [self selectRowIndexes: [NSIndexSet
                                                indexSetWithIndex: _clickedRow]
                        byExtendingSelection: NO];
        } else { // normal selection, allow for dragging
            BOOL dragging = NO;
            if ([_dataSource respondsToSelector: @selector
                             (tableView:writeRowsWithIndexes:toPasteboard:)]) {
                NSPoint currentPoint;
                do {
                    event = [_window
                            nextEventMatchingMask: NSLeftMouseUpMask |
                                                   NSLeftMouseDraggedMask
                                        untilDate: [NSDate distantFuture]
                                           inMode: NSEventTrackingRunLoopMode
                                          dequeue: NO];
                    if ([event type] == NSLeftMouseDragged)
                        event = [_window
                                nextEventMatchingMask: NSLeftMouseUpMask |
                                                       NSLeftMouseDraggedMask];
                    else
                        break;
                    currentPoint = [self convertPoint: [event locationInWindow]
                                             fromView: nil];
                    if (fabs(location.x - currentPoint.x) > 5 ||
                        fabs(location.y - currentPoint.y) > 5) {
                        dragging = YES;
                        break;
                    }
                } while ([event type] != NSLeftMouseUp);
            }
            if (dragging) {
                NSIndexSet *rowIndexes = [self selectedRowIndexes];
                if ([rowIndexes containsIndex: _clickedRow] == NO)
                    rowIndexes = [NSIndexSet indexSetWithIndex: _clickedRow];

                NSPasteboard *pasteboard =
                        [NSPasteboard pasteboardWithName: NSDragPboard];
                if ([_dataSource tableView: self
                            writeRowsWithIndexes: rowIndexes
                                    toPasteboard: pasteboard] == NO)
                    dragging = NO;
                else {
                    NSImage *image = [[[NSImage alloc]
                            initWithSize: NSMakeSize(0, 0)] autorelease];
                    [self dragImage: image
                                    at: NSMakePoint(0, 0)
                                offset: NSMakeSize(0, 0)
                                 event: event
                            pasteboard: pasteboard
                                source: self
                             slideBack: YES];
                }
            }

            if (dragging == NO) {
                // normal selection, allow for dragging
                NSInteger firstClickedRow = _clickedRow;

                [self selectRowIndexes: [NSIndexSet
                                                indexSetWithIndex: _clickedRow]
                        byExtendingSelection: NO];
                if ([self allowsMultipleSelection] == YES) {
                    do {
                        NSPoint point;
                        NSInteger row;

                        event = [_window
                                nextEventMatchingMask: NSLeftMouseUpMask |
                                                       NSLeftMouseDraggedMask];
                        point = [self convertPoint: [event locationInWindow]
                                          fromView: nil];

                        row = [self rowAtPoint: point];
                        if (row != -1) {
                            // we need to smooth out the selection granularity.
                            // on my slow system, the mouse moves too quickly
                            // for the NSEvents to show up for each row..
                            NSInteger startRow, endRow, i;

                            if (firstClickedRow > row) {
                                endRow = firstClickedRow;
                                startRow = row;
                            } else {
                                startRow = firstClickedRow;
                                endRow = row;
                            }

                            for (i = 0; i < numberOfRows; i++) {
                                if (i >= startRow && i <= endRow)
                                    [self selectRowIndexes:
                                                    [NSIndexSet
                                                            indexSetWithIndex:
                                                                    i]
                                            byExtendingSelection: YES];
                                else
                                    [self deselectRow: i];
                            }
                        }

                        [self noteSelectionIsChanging];
                    } while ([event type] != NSLeftMouseUp);
                }
            }
        }

        [self sendAction: [self action] to: [self target]];
    } else if ([event clickCount] == 2) {
        // nb this logic was backwards previously

        id binder = [[_tableColumns objectAtIndex: _clickedColumn]
                _binderForBinding: @"value"
                           create: NO];
        BOOL interpretedAsEdit = NO;
        if ([[_tableColumns objectAtIndex: _clickedColumn] isEditable]) {
            if ([self dataSourceCanSetObjectValue] ||
                [binder allowsEditingForRow: _clickedRow]) {
                if (_clickedColumn != -1 && _clickedRow != -1) {
                    if ([self delegateShouldEditTableColumn:
                                        [_tableColumns
                                                objectAtIndex: _clickedColumn]
                                                        row: _clickedRow]) {
                        interpretedAsEdit = YES;
                        [self editColumn: [self clickedColumn]
                                      row: _clickedRow
                                withEvent: event
                                   select: YES];
                    }
                }
            }
        }
        if (!interpretedAsEdit)
            [self sendAction: [self doubleAction] to: [self target]];
    }
}

- (void) _tightenUpColumn: (NSTableColumn *) column {
    NSInteger i, numberOfRows = [self numberOfRows];
    CGFloat minWidth = 0.0, width;

    for (i = 0; i < numberOfRows; ++i) {
        NSCell *dataCell = [column dataCellForRow: i];

        [dataCell setControlView: self];
        [dataCell setObjectValue:
                          [self dataSourceObjectValueForTableColumn: column
                                                                row: i]];

        width = [[dataCell attributedStringValue] size].width;
        if (width > minWidth)
            minWidth = width;
    }
    width = [[[column headerCell] attributedStringValue] size].width;
    if (width > minWidth)
        minWidth = width;

    [column setMinWidth: minWidth];
}

- (void) sizeToFit {
    NSInteger i, count = [_tableColumns count];

    for (i = 0; i < count; ++i) {
        NSTableColumn *column = [_tableColumns objectAtIndex: i];

        [self _tightenUpColumn: column];
        [column setWidth: [column minWidth]];
    }

    [self tile];
}

- (NSDragOperation) draggingSourceOperationMaskForLocal: (BOOL) isLocal {
    // OSXER APPKIT (table dragging): subclasses can still override this hook.
    return isLocal ? _localDraggingMask : _externalDraggingMask;
}

// OSXER APPKIT (table dragging): configure only the selected destination scope.
- (void) setDraggingSourceOperationMask: (NSDragOperation) mask forLocal: (BOOL) local {
    if (local) _localDraggingMask = mask;
    else _externalDraggingMask = mask;
}

- (NSInteger) _getDraggedRow: (id<NSDraggingInfo>) info {
    NSPoint dragPoint = [self convertPoint: [info draggingLocation]
                                  fromView: nil];
    NSInteger draggedRow = [self rowAtPoint: dragPoint];
    if (-1 == draggedRow) {
        if (dragPoint.y >= [self rectOfRow: [self numberOfRows] - 1].origin.y) {
            draggedRow = [self numberOfRows];
        }
    }
    return draggedRow;
}

- (unsigned) _validateDraggedRow: (id<NSDraggingInfo>) info {
    BOOL result;
    NSInteger proposedRow = [self _getDraggedRow: info];

    if ([_dataSource
                respondsToSelector: @selector
                (tableView:validateDrop:proposedRow:proposedDropOperation:)]) {
        if ((result = [_dataSource tableView: self
                                validateDrop: info
                                 proposedRow: proposedRow
                       proposedDropOperation: NSTableViewDropAbove]))
            _draggingRow = proposedRow;
        else
            _draggingRow = -1;
    }

    [self display];

    return result;
}

- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>) sender {
    for (NSInteger i = 0; i < [[self _draggedTypes] count]; i++) {
        if ([[[sender draggingPasteboard] types]
                    containsObject: [[self _draggedTypes] objectAtIndex: i]])
            return [self _validateDraggedRow: sender];
    }
    return NSDragOperationNone;
}

- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>) sender {
    for (NSInteger i = 0; i < [[self _draggedTypes] count]; i++) {
        if ([[[sender draggingPasteboard] types]
                    containsObject: [[self _draggedTypes] objectAtIndex: i]])
            return [self _validateDraggedRow: sender];
    }
    return NSDragOperationNone;
}

- (void) draggingExited: (id<NSDraggingInfo>) sender {
    _draggingRow = -1;
    [self display];
}

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>) sender {
    _draggingRow = -1;
    [self display];
    return YES;
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>) sender {
    return [_dataSource tableView: self
                       acceptDrop: sender
                              row: [self _getDraggedRow: sender]
                    dropOperation: NSTableViewDropAbove];
}

- (NSString *) description {
    return [NSString stringWithFormat: @"<%@ %0x08lx tableColumns: %@>",
                                       [self class], self, _tableColumns];
}

- (void) _moveUp: (BOOL) up extend: (BOOL) extend {

    NSInteger rowToSelect = -1;

    if ([_selectedRowIndexes count] == 0)
        rowToSelect = 0;
    else if (up) {
        NSInteger first = [_selectedRowIndexes firstIndex];
        if (first > 0)
            rowToSelect = first - 1;
        else if (!extend)
            rowToSelect = first;
    } else {
        NSInteger last = [_selectedRowIndexes lastIndex];
        if (last < [self numberOfRows] - 1)
            rowToSelect = last + 1;
        else if (!extend)
            rowToSelect = last;
    }

    if (rowToSelect != -1) {
        [self selectRow: rowToSelect byExtendingSelection: extend];
        [self scrollRowToVisible: rowToSelect];
    }
}

- (void) moveUp: sender {
    [self _moveUp: YES extend: NO];
}

- (void) moveUpAndModifySelection: sender {
    [self _moveUp: YES extend: YES];
}

- (void) moveDown: sender {
    [self _moveUp: NO extend: NO];
}

- (void) moveDownAndModifySelection: sender {
    [self _moveUp: NO extend: YES];
}

- (void)_writePersistentTableColumns {
    NSUnimplementedMethod();
}

- (void)_readPersistentTableColumns {
    NSUnimplementedMethod();
}


// OSXER APPKIT (table style): Automatic resolves to Inset on macOS 11+ unless the table is
// a source list (selection highlight style), as Apple documents.
- (NSTableViewStyle) style { return _osxerStyle; }
// Without a layout solver rows keep rowHeight / the delegate's heightOfRow:.
- (BOOL) usesAutomaticRowHeights { return _osxerUsesAutomaticRowHeights; }
- (void) setUsesAutomaticRowHeights: (BOOL) flag { _osxerUsesAutomaticRowHeights = flag; }
- (void) setStyle: (NSTableViewStyle) style { _osxerStyle = style; }
- (NSTableViewStyle) effectiveStyle {
    if (_osxerStyle != NSTableViewStyleAutomatic) return _osxerStyle;
    return [self selectionHighlightStyle] == NSTableViewSelectionHighlightStyleSourceList
        ? NSTableViewStyleSourceList : NSTableViewStyleInset;
}
@end

@implementation NSTableView (Bindings)

@end
