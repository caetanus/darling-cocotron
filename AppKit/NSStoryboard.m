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

// OSXER NIB (compiled storyboards): public controller creation API and resource
// layout checked against the supplied .storyboardc Info.plists and nib data.
#import "NSStoryboardPrivate.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSNib.h>
#import <AppKit/NSViewController.h>
#import <AppKit/NSWindowController.h>
#import <objc/runtime.h>

@interface NSStoryboardSceneOwner : NSObject {
    id _sceneController;
}
@property(retain) id sceneController;
@end
@implementation NSStoryboardSceneOwner
@synthesize sceneController = _sceneController;
- (void) dealloc { [_sceneController release]; [super dealloc]; }
@end

@implementation NSStoryboard
+ (instancetype) storyboardWithName: (NSString *) name bundle: (NSBundle *) bundle {
    @try {
    if (![name isKindOfClass: [NSString class]] || ![name length]) return nil;
    if (!bundle) bundle = [NSBundle mainBundle];
    NSString *path;
    if ([name isAbsolutePath]) path = name;
    else path = [bundle pathForResource: [name stringByDeletingPathExtension] ofType: @"storyboardc"];
    if (!path) {
        NSLog(@"Unable to find storyboard %@", name);
        return nil;
    }
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
            [path stringByAppendingPathComponent: @"Info.plist"]];
    if (![info isKindOfClass: [NSDictionary class]] ||
        ![[info objectForKey: @"NSViewControllerIdentifiersToNibNames"] isKindOfClass: [NSDictionary class]]) {
        NSLog(@"Unable to load storyboard metadata for %@", name);
        return nil;
    }
    id version = [info objectForKey: @"NSStoryboardVersion"];
    id entry = [info objectForKey: @"NSStoryboardDesignatedEntryPointIdentifier"];
    if ((version && (![version isKindOfClass: [NSNumber class]] || [version integerValue] != 1)) ||
        (entry && ![entry isKindOfClass: [NSString class]]))
        [NSException raise: NSInvalidUnarchiveOperationException format: @"Invalid storyboard version or entry point"];
    NSStoryboard *storyboard = [[[self alloc] init] autorelease];
    storyboard->_path = [path copy];
    storyboard->_bundle = [bundle retain];
    storyboard->_info = [info copy];
    storyboard->_loading = [NSMutableSet new];
    return storyboard;
    } @catch (NSException *exception) {
        NSLog(@"Unable to load storyboard: %@", [exception reason]); return nil;
    }
}
- (void) dealloc {
    [_path release]; [_bundle release]; [_info release]; [_loading release];
    [super dealloc];
}
- (NSString *) _nibPath: (NSString *) name {
    // Metadata refers to members of this storyboard, never arbitrary paths.
    if (![name isKindOfClass: [NSString class]] || ![name length] ||
        ![[name lastPathComponent] isEqual: name] || [name isEqual: @".."])
        [NSException raise: NSInvalidUnarchiveOperationException format: @"Invalid storyboard nib name"];
    if (![[name pathExtension] isEqual: @"nib"]) name = [name stringByAppendingPathExtension: @"nib"];
    return [_path stringByAppendingPathComponent: name];
}
- (BOOL) _loadNib: (NSString *) name owner: (id) owner external: (NSDictionary *) external
          objects: (NSArray **) objects {
    NSNib *nib = [[[NSNib alloc] initWithContentsOfURL: [NSURL fileURLWithPath: [self _nibPath: name]]] autorelease];
    if (!nib) return NO;
    NSMutableArray *top = [NSMutableArray array];
    NSMutableDictionary *table = [NSMutableDictionary dictionaryWithDictionary: external ?: @{}];
    [table setObject: self forKey: @"NSStoryboardPlaceholder"];
    if (owner) [table setObject: owner forKey: NSNibOwner];
    [table setObject: top forKey: NSNibTopLevelObjects];
    BOOL loaded = [nib instantiateNibWithExternalNameTable: table];
    if (objects) *objects = [[top copy] autorelease];
    // The array now owns these; balance NSNib's legacy extra top-level retains.
    [top makeObjectsPerformSelector: @selector(release)];
    return loaded;
}
- (id) instantiateInitialController {
    NSString *identifier = [_info objectForKey: @"NSStoryboardDesignatedEntryPointIdentifier"];
    return identifier ? [self instantiateControllerWithIdentifier: identifier] : nil;
}
- (id) instantiateControllerWithIdentifier: (NSString *) identifier {
    @try {
        if (![identifier isKindOfClass: [NSString class]]) {
            NSLog(@"Unable to instantiate storyboard scene: invalid identifier"); return nil;
        }
        NSString *name = [[_info objectForKey: @"NSViewControllerIdentifiersToNibNames"] objectForKey: identifier];
        if (!name) {
            NSLog(@"Unable to instantiate storyboard scene: unknown identifier %@", identifier); return nil;
        }
        if ([_loading containsObject: identifier])
            [NSException raise: NSInvalidUnarchiveOperationException format: @"Recursive storyboard scene %@", identifier];
        [_loading addObject: identifier];
        @try {
            NSStoryboardSceneOwner *owner = [[[NSStoryboardSceneOwner alloc] init] autorelease];
            NSArray *top = nil;
            if (![self _loadNib: name owner: owner external: nil objects: &top]) return nil;
            id controller = [owner sceneController];
            if (![controller isKindOfClass: [NSViewController class]] &&
                ![controller isKindOfClass: [NSWindowController class]]) return nil;
            // Keep auxiliary top-level objects for the lifetime of their controller.
            NSMutableArray *peers = [NSMutableArray array];
            for (id item in top) if (item != controller) [peers addObject: item];
            objc_setAssociatedObject(controller, @selector(instantiateControllerWithIdentifier:),
                    peers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return [[controller retain] autorelease];
        } @finally { [_loading removeObject: identifier]; }
    } @catch (NSException *exception) {
        NSLog(@"Unable to instantiate storyboard scene: %@", [exception reason]);
        return nil;
    }
}
- (BOOL) _loadMainMenu {
    NSString *name = [_info objectForKey: @"NSStoryboardMainMenu"];
    if (!name) return YES;
    @try {
        // Xcode also emits NSStoryboardMainMenu in view-only storyboards. It
        // does not imply that a MainMenu.nib member exists.
        if (![[NSFileManager defaultManager] fileExistsAtPath: [self _nibPath: name]]) return YES;
        NSArray *top = nil;
        if (![self _loadNib: name owner: NSApp external: nil objects: &top]) return NO;
        objc_setAssociatedObject(NSApp, @selector(_loadMainMenu), top, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"Unable to instantiate storyboard menu: %@", [exception reason]); return NO;
    }
}
- (BOOL) _loadViewController: (NSViewController *) controller externalObjects: (NSDictionary *) external {
    @try {
    NSArray *top = nil;
    BOOL loaded = [self _loadNib: [controller nibName] owner: controller external: external objects: &top];
    if (loaded) objc_setAssociatedObject(controller, @selector(_loadViewController:externalObjects:),
            top, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return loaded;
    } @catch (NSException *exception) {
        NSLog(@"Unable to instantiate storyboard view: %@", [exception reason]); return NO;
    }
}
@end

// OSXER NIB (unsupported scene references): preserve the former placeholder
// class, but fail explicitly instead of forwarding with an incorrect void ABI.
// None of the supplied compiled storyboards contains this class.
@interface NSStoryboardControllerPlaceholder : NSObject
@end
@implementation NSStoryboardControllerPlaceholder
- (id) initWithCoder: (NSCoder *) coder {
    [self release];
    [NSException raise: NSInvalidUnarchiveOperationException
                format: @"Cross-storyboard controller placeholders are not supported"];
    return nil;
}
@end
