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

#import <AppKit/NSPasteboardItem.h>

// OSXER APPKIT (pasteboard items): providers can fill values reentrantly. A
// recursive request for the same missing type returns nil rather than looping.
@implementation NSPasteboardItem
- (id)init {
    if ((self = [super init])) {
        _osxerData = [NSMutableDictionary new]; _osxerProviders = [NSMutableDictionary new];
        _osxerTypes = [NSMutableArray new]; _osxerProviding = [NSMutableSet new];
    }
    return self;
}
- (void)dealloc {
    [_osxerData release]; [_osxerProviders release]; [_osxerTypes release]; [_osxerProviding release];
    [super dealloc];
}
- (NSArray *)types { return [[_osxerTypes copy] autorelease]; }
- (NSString *)availableTypeFromArray:(NSArray *)types {
    for (NSString *type in types) if ([_osxerTypes containsObject:type]) return type;
    return nil;
}
- (BOOL)setDataProvider:(id<NSPasteboardItemDataProvider>)provider forTypes:(NSArray *)types {
    if (!provider || ![types count]) return NO;
    for (NSString *type in types) {
        if (![_osxerTypes containsObject:type]) [_osxerTypes addObject:type];
        [_osxerData removeObjectForKey:type]; [_osxerProviders setObject:provider forKey:type];
    }
    return YES;
}
- (BOOL)setData:(NSData *)data forType:(NSString *)type {
    if (!data || !type) return NO;
    if (![_osxerTypes containsObject:type]) [_osxerTypes addObject:type];
    [_osxerData setObject:[[data copy] autorelease] forKey:type];
    [_osxerProviders removeObjectForKey:type]; return YES;
}
- (BOOL)setString:(NSString *)string forType:(NSString *)type {
    return [self setData:[string dataUsingEncoding:NSUTF8StringEncoding] forType:type];
}
- (BOOL)setPropertyList:(id)plist forType:(NSString *)type {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    return [self setData:data forType:type];
}
- (NSData *)dataForType:(NSString *)type {
    id provider = [[[_osxerProviders objectForKey:type] retain] autorelease];
    if (![_osxerData objectForKey:type] && provider && ![_osxerProviding containsObject:type]) {
        [_osxerProviding addObject:type];
        @try { [provider pasteboard:nil item:self provideDataForType:type]; }
        @finally { [_osxerProviding removeObject:type]; }
    }
    return [[[_osxerData objectForKey:type] retain] autorelease];
}
- (NSString *)stringForType:(NSString *)type {
    return [[[NSString alloc] initWithData:[self dataForType:type] encoding:NSUTF8StringEncoding] autorelease];
}
- (id)propertyListForType:(NSString *)type {
    NSData *data = [self dataForType:type];
    return data ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL] : nil;
}
- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard { return [self types]; }
- (id)pasteboardPropertyListForType:(NSString *)type { return [self dataForType:type]; }
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard { return [pasteboard types]; }
+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard { return NSPasteboardReadingAsData; }
- (id)initWithPasteboardPropertyList:(id)value ofType:(NSString *)type {
    if ((self = [self init])) [self setData:value forType:type];
    return self;
}
@end
