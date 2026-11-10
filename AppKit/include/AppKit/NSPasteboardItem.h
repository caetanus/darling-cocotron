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

#import <AppKit/NSPasteboard.h>

// OSXER APPKIT (pasteboard items): values plus demand-driven data providers.
@protocol NSPasteboardItemDataProvider;
@interface NSPasteboardItem : NSObject <NSPasteboardWriting, NSPasteboardReading> {
    NSMutableDictionary *_osxerData, *_osxerProviders;
    NSMutableArray *_osxerTypes;
    NSMutableSet *_osxerProviding;
}
@property(readonly, copy) NSArray *types;
- (NSString *)availableTypeFromArray:(NSArray *)types;
- (BOOL)setDataProvider:(id<NSPasteboardItemDataProvider>)provider forTypes:(NSArray *)types;
- (BOOL)setData:(NSData *)data forType:(NSString *)type;
- (BOOL)setString:(NSString *)string forType:(NSString *)type;
- (BOOL)setPropertyList:(id)propertyList forType:(NSString *)type;
- (NSData *)dataForType:(NSString *)type;
- (NSString *)stringForType:(NSString *)type;
- (id)propertyListForType:(NSString *)type;
@end
@protocol NSPasteboardItemDataProvider <NSObject>
- (void)pasteboard:(NSPasteboard *)pasteboard item:(NSPasteboardItem *)item provideDataForType:(NSString *)type;
@optional
- (void)pasteboardFinishedWithDataProvider:(NSPasteboard *)pasteboard;
@end
