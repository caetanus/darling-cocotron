/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

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
#import <AppKit/NSRaise.h>
#import <AppKit/NSTreeController.h>

// OSXER NIB (tree controller): initialize the inherited selection/content machinery.
@implementation NSTreeController
@synthesize childrenKeyPath = _childrenKeyPath, countKeyPath = _countKeyPath, leafKeyPath = _leafKeyPath;
@synthesize sortDescriptors = _sortDescriptors, avoidsEmptySelection = _avoidsEmptySelection;
@synthesize preservesSelection = _preservesSelection, selectsInsertedObjects = _selectsInsertedObjects;
@synthesize alwaysUsesMultipleValuesMarker = _alwaysUsesMultipleValuesMarker;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _childrenKeyPath = [[coder decodeObjectForKey:@"NSTreeContentChildrenKey"] copy];
        _countKeyPath = [[coder decodeObjectForKey:@"NSTreeContentCountKey"] copy];
        _leafKeyPath = [[coder decodeObjectForKey:@"NSTreeContentLeafKey"] copy];
        _sortDescriptors = [[coder decodeObjectForKey:@"NSSortDescriptors"] copy];
        _avoidsEmptySelection = [coder decodeBoolForKey:@"NSAvoidsEmptySelection"];
        _preservesSelection = [coder containsValueForKey:@"NSPreservesSelection"] ? [coder decodeBoolForKey:@"NSPreservesSelection"] : YES;
        _selectsInsertedObjects = [coder containsValueForKey:@"NSSelectsInsertedObjects"] ? [coder decodeBoolForKey:@"NSSelectsInsertedObjects"] : YES;
        _alwaysUsesMultipleValuesMarker = [coder decodeBoolForKey:@"NSAlwaysUsesMultipleValuesMarker"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_childrenKeyPath forKey:@"NSTreeContentChildrenKey"];
    [coder encodeObject:_countKeyPath forKey:@"NSTreeContentCountKey"];
    [coder encodeObject:_leafKeyPath forKey:@"NSTreeContentLeafKey"];
    [coder encodeObject:_sortDescriptors forKey:@"NSSortDescriptors"];
    [coder encodeBool:_avoidsEmptySelection forKey:@"NSAvoidsEmptySelection"];
    [coder encodeBool:_preservesSelection forKey:@"NSPreservesSelection"];
    [coder encodeBool:_selectsInsertedObjects forKey:@"NSSelectsInsertedObjects"];
    [coder encodeBool:_alwaysUsesMultipleValuesMarker forKey:@"NSAlwaysUsesMultipleValuesMarker"];
    [coder encodeBool:[self isEditable] forKey:@"NSEditable"];
    [coder encodeBool:[self automaticallyPreparesContent] forKey:@"NSAutomaticallyPreparesContent"];
}
- (id)copyWithZone:(NSZone *)zone {
    NSTreeController *copy = [[[self class] allocWithZone:zone] initWithContent:[self content]];
    [copy setContent:[self content]];
    [copy setChildrenKeyPath:_childrenKeyPath]; [copy setCountKeyPath:_countKeyPath];
    [copy setLeafKeyPath:_leafKeyPath]; [copy setSortDescriptors:_sortDescriptors];
    [copy setAvoidsEmptySelection:_avoidsEmptySelection]; [copy setPreservesSelection:_preservesSelection];
    [copy setSelectsInsertedObjects:_selectsInsertedObjects];
    [copy setAlwaysUsesMultipleValuesMarker:_alwaysUsesMultipleValuesMarker];
    [copy setEditable:[self isEditable]];
    return copy;
}
- (void)dealloc {
    [_childrenKeyPath release]; [_countKeyPath release]; [_leafKeyPath release];
    [_sortDescriptors release]; [super dealloc];
}
@end
