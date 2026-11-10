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

#import "NSCustomObject.h"
// OSXER NIB (format selection)
#import "NSNibArchiveUnarchiver.h"
#import "NSIBObjectData.h"
#import "NSNibHelpConnector.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSMenu.h>
#import <AppKit/NSNib.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSTableCornerView.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSURL.h>

NSString *const NSNibOwner = @"NSOwner";
NSString *const NSNibTopLevelObjects = @"NSNibTopLevelObjects";

@implementation NSNib

- initWithCoder: (NSCoder *) coder {
    if ([coder allowsKeyedCoding]) {
        _data = [[coder decodeObjectForKey: @"NSNibFileData"] retain];

        // TODO: NSNibFileIsKeyed
        // NSNibFileUseParentBundle
        // NSNibFileBundleName
        // NSNibFileImages
        // NSNibFileSounds
    } else {
        NSString *bundleIdentifier;
        BOOL isKeyed;
        NSArray *imageBlobs, *soundBlobs;
        NSArray *images, *sounds;

        [coder decodeValuesOfObjCTypes: "@s@@@@@", &_data, &isKeyed,
                                        &bundleIdentifier, &images, &imageBlobs,
                                        &sounds, &soundBlobs];

        // TODO
        [imageBlobs release];
        [images release];
        [soundBlobs release];
        [sounds release];
    }

    // OSXER NIB (embedded archives): table-cell prototype nibs carry their data.
    _flags._isKeyed = [NSNibArchiveUnarchiver isNibArchiveData: _data] ||
            ([coder allowsKeyedCoding] && [coder decodeBoolForKey: @"NSNibFileIsKeyed"]);
    _allObjects = [NSMutableArray new];
    return self;
}

- initWithContentsOfFile: (NSString *) path {

    NIBDEBUG(@"initWithContentsOfFile: %@", path);

    NSString *objects = path;
    BOOL isDirectory = NO;

    if (![[NSFileManager defaultManager] fileExistsAtPath: path
                                              isDirectory: &isDirectory]) {
        [self release];
        return nil;
    }
    if (isDirectory) {
        // OSXER NIB (directory variants): prefer the canonical member, then the
        // highest numbered keyedobjects variant; retain legacy objects.nib.
        NSFileManager *manager = [NSFileManager defaultManager];
        objects = [path stringByAppendingPathComponent: @"keyedobjects.nib"];
        if (![manager fileExistsAtPath: objects]) {
            NSArray *members = [[manager contentsOfDirectoryAtPath: path error: NULL]
                    sortedArrayUsingComparator: ^NSComparisonResult(id a, id b) {
                        return [b compare: a options: NSNumericSearch];
                    }];
            objects = nil;
            for (NSString *member in members) {
                if ([member hasPrefix: @"keyedobjects-"] && [member hasSuffix: @".nib"]) {
                    objects = [path stringByAppendingPathComponent: member];
                    break;
                }
            }
        }
        _flags._isKeyed = objects != nil;
        if (!objects) objects = [path stringByAppendingPathComponent: @"objects.nib"];
    } else {
        _flags._isKeyed = TRUE;
    }

    if ((_data = [[NSData alloc] initWithContentsOfFile: objects]) == nil) {
        [self release];
        return nil;
    }

    _allObjects = [NSMutableArray new];

    return self;
}

- initWithContentsOfURL: (NSURL *) url {

    NIBDEBUG(@"initWithContentsOfURL: %@", url);

    if (![url isFileURL]) {
        [self release];
        return nil;
    }

    return [self initWithContentsOfFile: [url path]];
}

- initWithNibNamed: (NSString *) name bundle: (NSBundle *) bundle {

    NIBDEBUG(@"initWithNibNamed: %@ bundle: %@", name, bundle);

    if (bundle == nil)
        bundle = [NSBundle mainBundle];

    NSString *path = [bundle pathForResource: name ofType: @"nib"];

    if (path == nil) {
        NSLog(@"%s: unable to init nib with name '%@'", __PRETTY_FUNCTION__,
              name);
        [self release];
        return nil;
    }

    return [self initWithContentsOfFile: path];
}

- (void) dealloc {
    [_data release];
    [_allObjects release];
    [super dealloc];
}

- unarchiver: (NSKeyedUnarchiver *) unarchiver didDecodeObject: object {
    if (object != nil)
        [_allObjects addObject: object];
    return object;
}

- (void) unarchiver: (NSKeyedUnarchiver *) unarchiver
        willReplaceObject: object
               withObject: replacement
{
    if (object != nil && replacement != nil) {
        NSUInteger index = [_allObjects indexOfObjectIdenticalTo: object];
        if (index != NSNotFound)
            [_allObjects replaceObjectAtIndex: index withObject: replacement];
    }
}

- (NSDictionary *) externalNameTable {
    return _nameTable;
}

- (BOOL) instantiateNibWithExternalNameTable: (NSDictionary *) nameTable {

    NIBDEBUG(@"instantiateNibWithExternalNameTable: %@", nameTable);

    // OSXER NIB (failure boundary): malformed compiled resources fail once,
    // before connections or awake callbacks run. Keyed plist behavior is retained.
    BOOL binary = [NSNibArchiveUnarchiver isNibArchiveData: _data];
    NSIBObjectData *objectData = nil;
    @try {
    @autoreleasepool {
        [_allObjects removeAllObjects];
        _nameTable = [nameTable retain];

        NSCoder *unarchiver;
        int i, count;
        NSMenu *menu;
        NSArray *topLevelObjects;

        if (binary || _flags._isKeyed) {
            id keyed;
            Class decoder = binary ? [NSNibArchiveUnarchiver class] : [NSKeyedUnarchiver class];
            unarchiver = keyed = [[[decoder alloc] initForReadingWithData: _data] autorelease];
            [keyed setDelegate: self];

            /*
            TO DO:
            - utf8 in the multinational panel
            - misaligned objects in boxes everywhere
            */
            [keyed setClass: [NSTableCornerView class]
                    forClassName: @"_NSCornerView"];
            [keyed setClass: [NSNibHelpConnector class]
                    forClassName: @"NSIBHelpConnector"];

            objectData = [keyed decodeObjectForKey: @"IB.objectdata"];
        } else {
            NSUnarchiver *unkeyed;
            unarchiver = unkeyed = [[[NSUnarchiver alloc]
                    initForReadingWithData: _data] autorelease];

            [unkeyed decodeClassName: @"_NSCornerView"
                         asClassName: @"NSTableCornerView"];
            [unkeyed decodeClassName: @"NSIBHelpConnector"
                         asClassName: @"NSNibHelpConnector"];

            objectData = [unkeyed decodeObject];
        }

        if (binary && ![objectData isKindOfClass: [NSIBObjectData class]]) {
            if (unarchiver && ![(NSNibArchiveUnarchiver *)unarchiver failed])
                NSLog(@"Unable to decode NIBArchive: missing IB.objectdata");
            return NO;
        }
        [objectData buildConnectionsWithNameTable: _nameTable];
        if ((menu = [objectData mainMenu]) != nil) {
            // Rename the first item to have the application name.
            if ([menu numberOfItems] > 0) {
                NSMenuItem *firstItem = [menu itemAtIndex: 0];
                NSString *appName = [[NSBundle mainBundle]
                        objectForInfoDictionaryKey: (NSString *)
                                                            kCFBundleNameKey];
                // OSXER NIB (standalone loading): bundles may omit a display name.
                if ([appName length]) [firstItem setTitle: appName];
            }
            [NSApp setMainMenu: menu];
        }

        topLevelObjects = [objectData topLevelObjects];

        // Top-level objects are always retained - this echoes observed Cocoa
        // behaviour
        [topLevelObjects makeObjectsPerformSelector: @selector(retain)];

        // if external table contains a mutable array for key
        // NSNibTopLevelObjects, then this array also retains all top-level
        // objects,
        if ([_nameTable objectForKey: NSNibTopLevelObjects]) {
            [[_nameTable objectForKey: NSNibTopLevelObjects]
                    setArray: topLevelObjects];
        }

        // We do not need to add the objects from nameTable to allObjects as
        // they get put into the uid->object table already Do we send
        // awakeFromNib to objects in the nameTable *not* present in the nib ?

        count = [_allObjects count];

        for (i = 0; i < count; i++) {
            id object = [_allObjects objectAtIndex: i];

            if ([object respondsToSelector: @selector(awakeFromNib)])
                [object awakeFromNib];
        }

        for (i = 0; i < count; i++) {
            id object = [_allObjects objectAtIndex: i];

            if ([object respondsToSelector: @selector(postAwakeFromNib)])
                [object performSelector: @selector(postAwakeFromNib)];
        }

        [[objectData visibleWindows]
                makeObjectsPerformSelector: @selector(makeKeyAndOrderFront:)
                                withObject: nil];

    }
    } @catch (NSException *exception) {
        if (!binary) @throw;
        NSLog(@"Unable to instantiate NIBArchive: %@", [exception reason]);
        objectData = nil;
    } @finally {
        [_nameTable release];
        _nameTable = nil;
    }

    return (objectData != nil);
}

- (BOOL) instantiateNibWithOwner: owner topLevelObjects: (NSArray **) objects {

    NIBDEBUG(@"instantiateNibWithOwner: %@ topLevelObjects: ", owner);

    NSMutableArray *topLevelObjects = [[NSMutableArray alloc] init];
    // The owner goes last so a nil owner doesn't drop the array from the table.
    NSDictionary *nameTable = [NSDictionary
            dictionaryWithObjectsAndKeys: topLevelObjects, NSNibTopLevelObjects,
                                          owner, NSNibOwner, nil];
    BOOL result = [self instantiateNibWithExternalNameTable: nameTable];

    if (objects != NULL && result)
        *objects = [NSArray arrayWithArray: topLevelObjects];
    [topLevelObjects release];

    return result;
}

- (BOOL) instantiateWithOwner: (id) owner topLevelObjects: (NSArray **) objects {
    NSArray *topLevelObjects = nil;
    if (![self instantiateNibWithOwner: owner topLevelObjects: &topLevelObjects])
        return NO;

    // Unlike instantiateNibWithOwner:, the caller doesn't own the top-level objects.
    [topLevelObjects makeObjectsPerformSelector: @selector(autorelease)];
    if (objects != NULL)
        *objects = topLevelObjects;
    return YES;
}

@end
