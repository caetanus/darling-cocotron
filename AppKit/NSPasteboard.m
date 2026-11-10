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

#import <AppKit/NSDisplay.h>
#import <AppKit/NSPasteboard.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSPasteboardItem.h>
#import <CoreServices/CoreServices.h>
// OSXER APPKIT (pasteboard objects): portable multi-item payload transported
// by the existing backend. The first item's standard flavors stay interoperable.
static NSString *const OSXERPasteboardItemsType = @"org.darling-project.pasteboard-items";

const NSPasteboardType NSPasteboardTypeString = @"NSStringPboardType";
const NSPasteboardType NSPasteboardTypePDF = @"NSPDFPboardType";
const NSPasteboardType NSPasteboardTypePNG = @"NSPDFPboardType";
const NSPasteboardType NSPasteboardTypeTIFF = @"NSTIFFPboardType";
const NSPasteboardType NSPasteboardTypeRTF = @"NSRTFPboardType";
const NSPasteboardType NSPasteboardTypeRTFD = @"NSRTFDPboardType";
const NSPasteboardType NSPasteboardTypeHTML = @"NSPasteboardTypeHTML";
const NSPasteboardType NSPasteboardTypeTabularText = @"NSTabularTextPboardType";
const NSPasteboardType NSPasteboardTypeFont = @"NSFontPboardType";
const NSPasteboardType NSPasteboardTypeRuler = @"NSRulerPboardType";
const NSPasteboardType NSPasteboardTypeURL = @"public.url";
const NSPasteboardType NSPasteboardTypeColor = @"NSColorPboardType";
const NSPasteboardType NSPasteboardTypeFileURL = @"public.file-url";
const NSPasteboardType NSPasteboardTypeMultipleTextSelection = @"com.apple.cocoa.pasteboard.multiple-text-selection";

const NSPasteboardType NSColorPboardType = @"NSColorPboardType";
const NSPasteboardType NSFileContentsPboardType = @"NSFileContentsPboardType";
const NSPasteboardType NSFilenamesPboardType = @"NSFilenamesPboardType";
const NSPasteboardType NSFontPboardType = @"NSFontPboardType";
const NSPasteboardType NSPDFPboardType = @"NSPDFPboardType";
const NSPasteboardType NSPICTPboardType = @"NSPICTPboardType";
const NSPasteboardType NSPostScriptPboardType = @"NSPostScriptPboardType";
const NSPasteboardType NSRTFDPboardType = @"NSRTFDPboardType";
const NSPasteboardType NSRTFPboardType = @"NSRTFPboardType";
const NSPasteboardType NSRulerPboardType = @"NSRulerPboardType";
const NSPasteboardType NSStringPboardType = @"NSStringPboardType";
const NSPasteboardType NSTabularTextPboardType = @"NSTabularTextPboardType";
const NSPasteboardType NSTIFFPboardType = @"NSTIFFPboardType";
const NSPasteboardType NSURLPboardType = @"NSURLPboardType";
const NSPasteboardType NSHTMLPboardType = @"Apple HTML pasteboard type";
const NSPasteboardType NSVCardPboardType = @"NSVCardPboardType";
const NSPasteboardType NSInkTextPboardType = @"Apple InkText pasteboard type";
const NSPasteboardType NSMultipleTextSelectionPboardType = @"Apple multiple text selection pasteboard type";

const NSPasteboardType NSFilesPromisePboardType =
        @"Apple files promise pasteboard type";

const NSPasteboardName NSPasteboardNameDrag = @"Apple CFPasteboard drag";
NSString *const NSPasteboardURLReadingFileURLsOnlyKey =
        @"NSPasteboardURLReadingFileURLsOnlyKey";

const NSPasteboardName NSDragPboard = @"NSDragPboard";
const NSPasteboardName NSFindPboard = @"NSFindPboard";
const NSPasteboardName NSFontPboard = @"NSFontPboard";
const NSPasteboardName NSGeneralPboard = @"NSGeneralPboard";
const NSPasteboardName NSRulerPboard = @"NSRulerPboard";

const NSPasteboardName NSPasteboardNameFind = @"Apple CFPasteboard find";
const NSPasteboardName NSPasteboardNameFont = @"Apple CFPasteboard font";
const NSPasteboardName NSPasteboardNameGeneral = @"Apple CFPasteboard general";

const NSPasteboardReadingOptionKey
        NSPasteboardURLReadingContentsConformToTypesKey =
                @"NSPasteboardURLReadingContentsConformToTypesKey";

@implementation NSPasteboard

+ (NSPasteboard *) generalPasteboard {
    return [self pasteboardWithName: NSGeneralPboard];
}

+ (NSPasteboard *) pasteboardWithName: (NSPasteboardName) name {
    return [[NSDisplay currentDisplay] pasteboardWithName: name];
}

- (NSPasteboardName) name {
    NSUnimplementedMethod();
    return nil;
}

- (NSInteger) changeCount {
    NSUnimplementedMethod();
    return 0;
}

- (NSInteger) clearContents {
    NSUnimplementedMethod();
    return 0;
}

- (oneway void) releaseGlobally {
    NSUnimplementedMethod();
}

- (NSArray<NSPasteboardType> *) types {
    NSUnimplementedMethod();
    return nil;
}

- (NSPasteboardType) availableTypeFromArray: (NSArray<NSPasteboardType> *) types
{
    NSArray<NSPasteboardType> *available = [self types];
    for (NSPasteboardType type in types) {
        if ([available containsObject: type]) {
            return type;
        }
    }
    return nil;
}

- (NSData *) dataForType: (NSPasteboardType) type {
    NSUnimplementedMethod();
    return nil;
}

- (NSString *) stringForType: (NSPasteboardType) type {
    NSData *data = [self dataForType: type];

    return [[[NSString alloc] initWithData: data
                                  encoding: NSUnicodeStringEncoding]
            autorelease];
}

- (id) propertyListForType: (NSPasteboardType) type {
    NSData *data = [self dataForType: type];
    NSString *errorDesc = nil;
    id plist = [NSPropertyListSerialization
            propertyListFromData: data
                mutabilityOption: NSPropertyListImmutable
                          format: NULL
                errorDescription: &errorDesc];
    if (plist && errorDesc == nil) {
        return plist;
    }
    NSLog(@"propertyListForType: produced error: %@", errorDesc);
    return nil;
}

- (NSInteger) declareTypes: (NSArray<NSPasteboardType> *) types
                     owner: (id<NSPasteboardTypeOwner>) owner
{
    NSUnimplementedMethod();
    return 0;
}

- (NSInteger) addTypes: (NSArray<NSPasteboardType> *) types
                 owner: (id<NSPasteboardTypeOwner>) owner
{
    NSUnimplementedMethod();
    return 0;
}

- (BOOL) setData: (NSData *) data forType: (NSPasteboardType) type {
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) setString: (NSString *) string forType: (NSPasteboardType) type {
    NSData *data = [string dataUsingEncoding: NSUnicodeStringEncoding];
    return [self setData: data forType: type];
}

- (BOOL) setPropertyList: (id) plist forType: (NSPasteboardType) type {
    NSString *errorDesc = nil;
    NSData *data = [NSPropertyListSerialization
            dataFromPropertyList: plist
                          format: NSPropertyListXMLFormat_v1_0
                errorDescription: &errorDesc];
    if (data && errorDesc == nil) {
        return [self setData: data forType: type];
    }
    NSLog(@"setPropertyList:forType: produced error: %@", errorDesc);
    return NO;
}

// OSXER APPKIT (pasteboard objects): serialize completely before modifying the
// board. Providers may supply their data now, as allowed by NSPasteboardWriting.
- (BOOL)writeObjects:(NSArray *)objects {
    if (![objects count]) return NO;
    NSMutableArray *payload = [NSMutableArray array];
    for (id object in objects) {
        NSMutableDictionary *values = [NSMutableDictionary dictionary];
        for (NSString *type in [object writableTypesForPasteboard:self]) {
            id value = [object pasteboardPropertyListForType:type];
            if (value) [values setObject:value forKey:type];
        }
        if (![values count]) return NO;
        [payload addObject:values];
    }
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:payload format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    if (!data) return NO;
    // Appending preserves already-written items until clearContents is called.
    NSArray *old = [[self types] containsObject:OSXERPasteboardItemsType] ? [self propertyListForType:OSXERPasteboardItemsType] : nil;
    if ([old isKindOfClass:[NSArray class]]) {
        [payload insertObjects:old atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[old count])]];
        data = [NSPropertyListSerialization dataWithPropertyList:payload format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    }
    NSDictionary *first = [payload objectAtIndex:0];
    NSMutableArray *types = [NSMutableArray arrayWithArray:[first allKeys]];
    [types addObject:OSXERPasteboardItemsType];
    [self addTypes:types owner:nil];
    for (NSString *type in first) {
        id value = [first objectForKey:type];
        BOOL ok = [value isKindOfClass:[NSData class]] ? [self setData:value forType:type] :
            [value isKindOfClass:[NSString class]] ? [self setString:value forType:type] : [self setPropertyList:value forType:type];
        if (!ok) return NO;
    }
    return [self setData:data forType:OSXERPasteboardItemsType];
}
- (NSArray *)pasteboardItems {
    NSData *data = [[self types] containsObject:OSXERPasteboardItemsType] ? [self dataForType:OSXERPasteboardItemsType] : nil;
    id payload = data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL] : nil;
    NSMutableArray *items = [NSMutableArray array];
    if ([payload isKindOfClass:[NSArray class]]) {
        for (id values in payload) {
            if (![values isKindOfClass:[NSDictionary class]]) return nil;
            NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
            for (id type in values) {
                if (![type isKindOfClass:[NSString class]]) return nil;
                id value = [values objectForKey:type];
                if ([value isKindOfClass:[NSData class]]) [item setData:value forType:type];
                else if ([value isKindOfClass:[NSString class]]) [item setString:value forType:type];
                else [item setPropertyList:value forType:type];
            }
            [items addObject:item];
        }
    } else {
        NSPasteboardItem *item = [[[NSPasteboardItem alloc] init] autorelease];
        for (NSString *type in [self types]) {
            if ([type isEqual:OSXERPasteboardItemsType]) continue;
            if ([type isEqual:NSPasteboardTypeString] || [type isEqual:NSPasteboardTypeURL] || [type isEqual:NSPasteboardTypeFileURL])
                [item setString:[self stringForType:type] forType:type];
            else [item setData:[self dataForType:type] forType:type];
        }
        if ([[item types] count]) [items addObject:item];
    }
    return [items count] ? items : nil;
}
- (BOOL)canReadItemWithDataConformingToTypes:(NSArray *)types {
    for (NSPasteboardItem *item in [self pasteboardItems]) for (NSString *available in [item types])
        for (NSString *type in types)
            if ([type isEqual:available] || UTTypeConformsTo((CFStringRef)available,(CFStringRef)type)) return YES;
    return NO;
}
- (NSArray *)readObjectsForClasses:(NSArray *)classes options:(NSDictionary *)options {
    NSMutableArray *result = [NSMutableArray array];
    for (NSPasteboardItem *item in [self pasteboardItems]) {
        for (Class cls in classes) {
            if (cls == [NSPasteboardItem class]) { [result addObject:item]; break; }
            if (![cls respondsToSelector:@selector(readableTypesForPasteboard:)]) continue;
            NSString *type = [item availableTypeFromArray:[cls readableTypesForPasteboard:self]];
            if (!type) continue;
            NSPasteboardReadingOptions mode = [cls respondsToSelector:@selector(readingOptionsForType:pasteboard:)] ?
                [cls readingOptionsForType:type pasteboard:self] : NSPasteboardReadingAsData;
            id value = mode & NSPasteboardReadingAsString ? [item stringForType:type] :
                mode & NSPasteboardReadingAsPropertyList ? [item propertyListForType:type] : [item dataForType:type];
            if (!value) continue;
            // OSXER APPKIT (pasteboard reading): archive readers use initWithCoder,
            // and need not implement the property-list initializer at all.
            id object = mode & NSPasteboardReadingAsKeyedArchive ? [NSKeyedUnarchiver unarchiveObjectWithData:value] :
                [[[cls alloc] initWithPasteboardPropertyList:value ofType:type] autorelease];
            if (object && ![object isKindOfClass:cls]) continue;
            if ([object isKindOfClass:[NSURL class]]) {
                if ([[options objectForKey:NSPasteboardURLReadingFileURLsOnlyKey] boolValue] && ![object isFileURL]) continue;
                NSArray *filter = [options objectForKey:NSPasteboardURLReadingContentsConformToTypesKey];
                if (filter) {
                    NSString *uti = [(NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                        (CFStringRef)[[object path] pathExtension], NULL) autorelease];
                    BOOL match = NO;
                    for (NSString *wanted in filter) if (uti && UTTypeConformsTo((CFStringRef)uti,(CFStringRef)wanted)) match = YES;
                    if (!match) continue;
                }
            }
            if (object) { [result addObject:object]; break; }
        }
    }
    return [result count] ? result : nil;
}
- (BOOL)canReadObjectForClasses:(NSArray *)classes options:(NSDictionary *)options {
    return [[self readObjectsForClasses:classes options:options] count] != 0;
}
@end

// OSXER APPKIT (pasteboard Foundation roles): these are AppKit categories, so
// Foundation does not depend on clipboard or display facilities.
@implementation NSString (OSXERPasteboard)
- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard { return @[NSPasteboardTypeString]; }
- (id)pasteboardPropertyListForType:(NSString *)type { return [type isEqual:NSPasteboardTypeString] ? self : nil; }
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard { return @[NSPasteboardTypeString, @"public.utf8-plain-text"]; }
+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard { return NSPasteboardReadingAsString; }
- (id)initWithPasteboardPropertyList:(id)value ofType:(NSString *)type { return [self initWithString:value]; }
@end
@implementation NSURL (OSXERPasteboard)
- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard { return [self isFileURL] ? @[NSPasteboardTypeFileURL, NSPasteboardTypeURL] : @[NSPasteboardTypeURL]; }
- (id)pasteboardPropertyListForType:(NSString *)type {
    return [[self writableTypesForPasteboard:nil] containsObject:type] ? [self absoluteString] : nil;
}
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard { return @[NSPasteboardTypeFileURL, NSPasteboardTypeURL]; }
+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard { return NSPasteboardReadingAsString; }
- (id)initWithPasteboardPropertyList:(id)value ofType:(NSString *)type { return [self initWithString:value]; }
+ (NSURL *)URLFromPasteboard:(NSPasteboard *)pasteboard {
    NSArray *urls = [pasteboard readObjectsForClasses:@[[NSURL class]] options:nil];
    return [urls count] ? [urls objectAtIndex:0] : nil;
}
@end
