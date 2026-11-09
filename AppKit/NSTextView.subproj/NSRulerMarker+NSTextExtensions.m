//
//  NSRulerMarker+NSTextExtensions.m
//  AppKit
//
//  Created by Airy ANDRE on 16/11/12.
//
//

#import "NSRulerMarker+NSTextExtensions.h"

#import "NSInterfacePart/OSXERSystemPalette.h"

// OSXER TEXTEDIT LOOK (marker hit areas): distinct 5 pt indent handles must
// not share a transparent 15 pt image rectangle, or the first always wins hits.
@interface NSTextRulerMarker : NSRulerMarker {
    CGFloat _verticalOffset;
}
- (void) setVerticalOffset: (CGFloat) offset;
@end
@implementation NSTextRulerMarker
- (void) setVerticalOffset: (CGFloat) offset { _verticalOffset = offset; }
- (NSRect) imageRectInRuler {
    NSRect rect = [super imageRectInRuler];
    if ([[self ruler] orientation] == NSHorizontalRuler) rect.origin.y += _verticalOffset;
    else rect.origin.x += _verticalOffset;
    return rect;
}
- (CGFloat) thicknessRequiredInRuler { return [super thicknessRequiredInRuler] + _verticalOffset; }
@end

// OSXER TEXTEDIT LOOK (markers): reference tab flags are 6x9 px, #808080,
// with their stem on the stop; margin/first-line handles are 9x5 px.
static NSRulerMarker *OSXERTextMarker(NSRulerView *ruler, CGFloat location, NSInteger kind) {
    NSImage *image;
    NSPoint anchor = NSZeroPoint;
    CGFloat offset = 0;
    if (!OSXERBigSurEnabled()) image = [NSImage imageNamed: @"NSRulerMarkerTab"];
    else {
        image = [[[NSImage alloc] initWithSize: NSMakeSize(9, kind < 4 ? 9 : 5)] autorelease];
        offset = kind < 4 ? 5 : kind == 6 ? 4 : 9;
        [image lockFocus];
        [[NSColor colorWithCalibratedWhite: 128.0/255 alpha: 1] setFill];
        NSBezierPath *path = [NSBezierPath bezierPath];
        if (kind < 4) {
            CGFloat stem = kind == 1 ? 8 : kind >= 2 ? 4 : 1;
            anchor.x = stem;
            NSRectFill(NSMakeRect(stem, 0, 1, 9));
            if (kind == 0 || kind == 1) {
                CGFloat tip = kind == 0 ? 7 : 2;
                [path moveToPoint: NSMakePoint(stem, 9)];
                [path lineToPoint: NSMakePoint(tip, 5)];
                [path lineToPoint: NSMakePoint(stem, 2)];
            } else {
                NSRectFill(NSMakeRect(1, 8, 7, 1));
                if (kind == 3) NSRectFill(NSMakeRect(7, 2, 1, 1));
            }
        } else {
            anchor.x = 4;
            BOOL first = kind == 6;
            CGFloat y = 0;
            [path moveToPoint: NSMakePoint(0, y + (first ? 5 : 0))];
            [path lineToPoint: NSMakePoint(8, y + (first ? 5 : 0))];
            [path lineToPoint: NSMakePoint(4, y + (first ? 0 : 5))];
        }
        if (kind != 2 && kind != 3) { [path closePath]; [path fill]; }
        [image unlockFocus];
    }
    NSTextRulerMarker *marker = [[[NSTextRulerMarker alloc] initWithRulerView: ruler
        markerLocation: location image: image imageOrigin: anchor] autorelease];
    [marker setVerticalOffset: offset];
    [marker setRemovable: kind < 4];
    return marker;
}

@implementation NSRulerMarker (NSTextExtensions)
+ (NSRulerMarker *) leftTabMarkerWithRulerView: (NSRulerView *) ruler location: (CGFloat) location {
    return OSXERTextMarker(ruler, location, 0);
}
+ (NSRulerMarker *) rightTabMarkerWithRulerView: (NSRulerView *) ruler location: (CGFloat) location {
    return OSXERTextMarker(ruler, location, 1);
}
+ (NSRulerMarker *) centerTabMarkerWithRulerView: (NSRulerView *) ruler location: (CGFloat) location {
    return OSXERTextMarker(ruler, location, 2);
}
+ (NSRulerMarker *) decimalTabMarkerWithRulerView: (NSRulerView *) ruler location: (CGFloat) location {
    return OSXERTextMarker(ruler, location, 3);
}
+ (NSRulerMarker *) leftMarginMarkerWithRulerView: (NSRulerView *) ruler location: (CGFloat) location {
    return OSXERTextMarker(ruler, location, 4);
}
+ (NSRulerMarker *) rightMarginMarkerWithRulerView: (NSRulerView *) ruler location: (CGFloat) location {
    return OSXERTextMarker(ruler, location, 5);
}
+ (NSRulerMarker *) firstIndentMarkerWithRulerView: (NSRulerView *) ruler location: (CGFloat) location {
    return OSXERTextMarker(ruler, location, 6);
}
+ (NSRulerMarker *) leftIndentMarkerWithRulerView: (NSRulerView *) ruler location: (CGFloat) location {
    return OSXERTextMarker(ruler, location, 7);
}
+ (NSRulerMarker *) rightIndentMarkerWithRulerView: (NSRulerView *) ruler location: (CGFloat) location {
    return OSXERTextMarker(ruler, location, 8);
}
@end
