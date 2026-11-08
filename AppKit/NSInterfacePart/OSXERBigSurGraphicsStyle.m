#import "OSXERBigSurGraphicsStyle.h"
#import <AppKit/AppKit.h>
#import <AppKit/NSGraphicsContextFunctions.h>
#import <AppKit/NSStringDrawer.h>

@interface NSButtonCell (OSXERDrawing)
- (NSAttributedString *) titleForHighlight;
- (NSImage *) imageForHighlight;
@end

static NSColor *Color(NSString *name) {
    return [OSXERSystemPalette colorWithName: name];
}

static CGContextRef Context(void) {
    return [[NSGraphicsContext currentContext] graphicsPort];
}

static NSBezierPath *Rounded(NSRect rect, CGFloat radius) {
    radius = MAX(0, MIN(radius, MIN(NSWidth(rect), NSHeight(rect)) / 2));
    if (radius == 0) return [NSBezierPath bezierPathWithRect: rect];
    return [NSBezierPath bezierPathWithRoundedRect: rect
            xRadius: radius yRadius: radius];
}

static void Fill(NSRect rect, CGFloat radius, NSString *color) {
    if (NSIsEmptyRect(rect)) return;
    [Color(color) setFill];
    [Rounded(rect, radius) fill];
}

static void Border(NSRect rect, CGFloat radius, CGFloat width, NSString *color) {
    if (NSIsEmptyRect(rect)) return;
    NSBezierPath *path = Rounded(NSInsetRect(rect, width / 2, width / 2),
                                 MAX(0, radius - width / 2));
    [path setLineWidth: width];
    [Color(color) setStroke];
    [path stroke];
}

static NSRect CenterHeight(NSRect rect, CGFloat height) {
    height = MIN(height, NSHeight(rect));
    rect.origin.y += (NSHeight(rect) - height) / 2;
    rect.size.height = height;
    return rect;
}

static void ShadowFill(NSRect rect, CGFloat radius, NSString *fill,
                       NSString *shadow, CGFloat blur, BOOL flipped) {
    CGContextRef ctx = Context();
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, flipped ? 1 : -1), blur,
                               [Color(shadow) CGColor]);
    Fill(rect, radius, fill);
    CGContextRestoreGState(ctx);
}

// Glyph points use a top-left origin independently of the containing view.
static NSPoint GlyphPoint(NSRect rect, CGFloat x, CGFloat y, BOOL flipped) {
    return NSMakePoint(NSMinX(rect) + x, flipped ? NSMinY(rect) + y
                                               : NSMaxY(rect) - y);
}

static void StrokeGlyph(NSPoint *points, NSUInteger count, CGFloat width,
                        NSColor *color) {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth: width];
    [path setLineCapStyle: NSRoundLineCapStyle];
    [path setLineJoinStyle: NSRoundLineJoinStyle];
    [path moveToPoint: points[0]];
    for (NSUInteger i = 1; i < count; ++i) [path lineToPoint: points[i]];
    [color setStroke];
    [path stroke];
}

static NSDictionary *TextAttributes(CGFloat size, NSColor *color) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont systemFontOfSize: size], NSFontAttributeName,
            color, NSForegroundColorAttributeName, nil];
}

static void DrawText(NSAttributedString *text, NSRect rect, NSColor *color,
                     BOOL centered) {
    if (![text length] || NSIsEmptyRect(rect)) return;
    NSMutableAttributedString *title = [[text mutableCopy] autorelease];
    [title addAttribute: NSForegroundColorAttributeName value: color
                 range: NSMakeRange(0, [title length])];
    NSMutableParagraphStyle *paragraph = [[[NSParagraphStyle defaultParagraphStyle]
            mutableCopy] autorelease];
    [paragraph setAlignment: centered ? NSCenterTextAlignment : NSLeftTextAlignment];
    [paragraph setLineBreakMode: NSLineBreakByTruncatingTail];
    [title addAttribute: NSParagraphStyleAttributeName value: paragraph
                 range: NSMakeRange(0, [title length])];
    NSSize size = [title size];
    rect.origin.y += (rect.size.height - size.height) / 2;
    rect.size.height = size.height;
    [title _clipAndDrawInRect: rect truncatingTail: YES];
}

static BOOL TableEmphasized(NSTableView *table) {
    if (![[table window] isKeyWindow]) return NO;
    id responder = [[table window] firstResponder];
    return responder == table || [table currentEditor] != nil;
}

BOOL OSXERBigSurDrawsButton(NSButtonCell *cell) {
    NSString *name = [[cell image] name];
    if ([name isEqualToString: @"NSRadioButton"] || [name isEqualToString: @"NSSwitch"] ||
        [cell isKindOfClass: [NSPopUpButtonCell class]]) return YES;
    NSBezelStyle bezel = [cell bezelStyle];
    return bezel != NSDisclosureBezelStyle && bezel != NSCircularBezelStyle &&
           bezel != NSHelpButtonBezelStyle && bezel != NSRoundedDisclosureBezelStyle &&
           [cell imagePosition] != NSImageAbove && [cell imagePosition] != NSImageBelow;
}

NSSize OSXERBigSurButtonSize(NSButtonCell *cell) {
    NSSize title = [[cell attributedTitle] size];
    CGFloat width = [cell imagePosition] == NSImageOnly ? 0 : title.width;
    NSString *name = [[cell image] name];
    if ([name isEqualToString: @"NSSwitch"]) width += 20;
    else if ([name isEqualToString: @"NSRadioButton"]) width += 22;
    else {
        width += 16;
        if ([cell image] && [cell imagePosition] != NSNoImage)
            width += MIN([[cell image] size].width, 20) + 4;
        if ([cell isKindOfClass: [NSPopUpButtonCell class]] &&
            [(NSPopUpButtonCell *) cell arrowPosition] != NSPopUpNoArrow) width += 23;
    }
    return NSMakeSize(ceil(width), 21 - [cell controlSize] * 2);
}

@implementation OSXERBigSurGraphicsStyle

- (BOOL) cellHasFocus: (NSCell *) cell {
    if (![cell isEnabled] || [cell focusRingType] == NSFocusRingTypeNone ||
        ![[_view window] isKeyWindow]) return NO;
    if ([cell showsFirstResponder]) return YES;
    if ([[_view window] firstResponder] == _view) {
        return ![_view isKindOfClass: [NSControl class]] ||
               [(NSControl *) _view selectedCell] == cell;
    }
    return [_view isKindOfClass: [NSTextField class]] &&
           [(NSControl *) _view currentEditor] != nil;
}

- (void) drawFocusRingInRect: (NSRect) rect radius: (CGFloat) radius {
    NSBezierPath *ring = Rounded(NSInsetRect(rect, -1.5, -1.5), radius + 1.5);
    [ring setLineWidth: 3];
    [Color(@"focusRing") setStroke];
    [ring stroke];
}

// Cell hooks retain model, target/action, hit testing and editing in Cocotron.
- (BOOL) drawButtonCell: (NSButtonCell *) cell inRect: (NSRect) rect {
    NSString *imageName = [[cell image] name];
    BOOL radio = [imageName isEqualToString: @"NSRadioButton"];
    BOOL check = [imageName isEqualToString: @"NSSwitch"];
    BOOL popup = [cell isKindOfClass: [NSPopUpButtonCell class]];
    // Keep special-purpose disclosure/help/circular and vertical image layouts.
    if (!OSXERBigSurDrawsButton(cell)) return NO;
    if ([cell isTransparent]) return YES;

    BOOL flipped = [_view isFlipped];
    BOOL on = [cell state] != NSControlStateValueOff;
    BOOL defaulted = !popup && [cell isBordered] &&
            [[_view window] defaultButtonCell] == cell;
    NSRect body = CenterHeight(rect, 21 - [cell controlSize] * 2);
    body = NSInsetRect(body, 0, .5); // regular: 20 pt bezel at y + 0.5
    NSRect titleRect = NSInsetRect(body, 8, 0);
    CGContextRef ctx = Context();
    CGContextSaveGState(ctx);
    if (![cell isEnabled]) {
        CGContextSetAlpha(ctx, .5);
        CGContextBeginTransparencyLayer(ctx, NULL);
    }
    if (check || radio) {
        CGFloat diameter = radio ? 16 : 14;
        body = NSMakeRect(NSMinX(rect) + 1, NSMidY(rect) - diameter / 2,
                          diameter, diameter);
        CGFloat radius = radio ? 8 : 3;
        ShadowFill(body, radius, on ? @"controlAccentColor" : @"controlColor",
                   @"buttonShadow", 1, flipped);
        if (!on) Border(body, radius, .5, @"checkBorder");
        if ([cell isHighlighted]) Fill(body, radius, @"separatorColor");
        if (on) {
            if (radio) Fill(NSInsetRect(body, 5, 5), 3, @"controlColor");
            else if ([cell state] == NSControlStateValueMixed) {
                NSPoint p[] = {GlyphPoint(body, 3.5, 7, flipped), GlyphPoint(body, 10.5, 7, flipped)};
                StrokeGlyph(p, 2, 2, Color(@"controlColor"));
            } else {
                NSPoint p[] = {GlyphPoint(body, 3, 7, flipped), GlyphPoint(body, 6, 10, flipped),
                               GlyphPoint(body, 11, 4, flipped)};
                StrokeGlyph(p, 3, 2, Color(@"controlColor"));
            }
        }
        titleRect = NSMakeRect(NSMaxX(body) + 5, NSMinY(rect),
                               MAX(0, NSMaxX(rect) - NSMaxX(body) - 5), NSHeight(rect));
    } else if ([cell isBordered]) {
        NSString *fill = defaulted ? @"controlAccentColor" :
                (([cell isHighlighted] || (on && ([cell showsStateBy] & NSChangeGrayCellMask)))
                        ? @"buttonPressed" : @"controlColor");
        ShadowFill(body, 5, fill, @"buttonShadow", 1, flipped);
        if (!defaulted) Border(body, 5, .5, @"buttonBorder");
        else if ([cell isHighlighted]) Fill(body, 5, @"separatorColor");
    }

    if (popup && [(NSPopUpButtonCell *) cell arrowPosition] != NSPopUpNoArrow) {
        BOOL pullsDown = [(NSPopUpButtonCell *) cell pullsDown];
        NSRect arrow = NSMakeRect(NSMaxX(body) - 19, NSMidY(body) - 8, 16, 16);
        if (!pullsDown) Fill(arrow, 4, @"controlAccentColor");
        NSColor *ink = Color(pullsDown ? @"controlTextColor" : @"controlColor");
        if (!pullsDown) {
            NSPoint up[] = {GlyphPoint(arrow, 5, 6, flipped), GlyphPoint(arrow, 8, 3.5, flipped),
                            GlyphPoint(arrow, 11, 6, flipped)};
            StrokeGlyph(up, 3, 1.4, ink);
        }
        CGFloat y = pullsDown ? 6.5 : 10;
        NSPoint down[] = {GlyphPoint(arrow, 5, y, flipped), GlyphPoint(arrow, 8, y + 2.5, flipped),
                          GlyphPoint(arrow, 11, y, flipped)};
        StrokeGlyph(down, 3, 1.4, ink);
        titleRect.size.width = MAX(0, NSMinX(arrow) - NSMinX(titleRect) - 4);
    }

    if (!check && !radio && [cell imagePosition] != NSNoImage && [cell image] != nil) {
        NSImage *image = [cell imageForHighlight];
        NSSize size = [image size];
        CGFloat scale = MIN(1, MIN(NSHeight(body) / MAX(1, size.height),
                                    NSWidth(titleRect) / MAX(1, size.width)));
        size.width *= scale;
        size.height *= scale;
        NSRect imageRect = NSMakeRect(NSMinX(titleRect), NSMidY(body) - size.height / 2,
                                      size.width, size.height);
        if ([cell imagePosition] == NSImageOnly || [cell imagePosition] == NSImageOverlaps)
            imageRect.origin.x = NSMidX(titleRect) - size.width / 2;
        else if ([cell imagePosition] == NSImageRight) {
            imageRect.origin.x = NSMaxX(titleRect) - size.width;
            titleRect.size.width -= size.width + 4;
        } else {
            titleRect.origin.x += size.width + 4;
            titleRect.size.width -= size.width + 4;
        }
        // Draw here to avoid a second disabled-image opacity multiplication.
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, imageRect.origin.x, imageRect.origin.y);
        if (flipped) {
            CGContextTranslateCTM(ctx, 0, imageRect.size.height);
            CGContextScaleCTM(ctx, 1, -1);
        }
        [image drawInRect: NSMakeRect(0, 0, size.width, size.height)
                fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1];
        CGContextRestoreGState(ctx);
    }
    if ([cell imagePosition] != NSImageOnly) {
        DrawText([cell titleForHighlight], titleRect,
                 Color(defaulted ? @"selectedMenuItemTextColor" : @"controlTextColor"),
                 !check && !radio && !popup);
    }
    if (![cell isEnabled]) CGContextEndTransparencyLayer(ctx);
    CGContextRestoreGState(ctx);
    if ([self cellHasFocus: cell])
        [self drawFocusRingInRect: body radius: radio ? 8 : (check ? 3 : 5)];
    return YES;
}

- (void) drawPushButtonNormalInRect: (NSRect) rect defaulted: (BOOL) defaulted {
    rect = NSInsetRect(CenterHeight(rect, 21), 0, .5);
    ShadowFill(rect, 5, defaulted ? @"controlAccentColor" : @"controlColor",
               @"buttonShadow", 1, [_view isFlipped]);
    if (!defaulted) Border(rect, 5, .5, @"buttonBorder");
}
- (void) drawPushButtonPressedInRect: (NSRect) rect {
    rect = NSInsetRect(CenterHeight(rect, 21), 0, .5);
    Fill(rect, 5, @"buttonPressed");
    Border(rect, 5, .5, @"buttonBorder");
}
- (void) drawPushButtonHighlightedInRect: (NSRect) rect {
    [self drawPushButtonPressedInRect: rect];
}

- (void) drawTextFieldCell: (NSTextFieldCell *) cell inRect: (NSRect) rect {
    BOOL search = [cell isKindOfClass: [NSSearchFieldCell class]];
    CGFloat radius = (search || [cell bezelStyle] == NSTextFieldRoundedBezel) ? 6 : 0;
    if ([cell isBezeled] || [cell isBordered]) {
        NSColor *background = [cell drawsBackground] ? [cell backgroundColor] : nil;
        [(background ?: Color(@"textBackgroundColor")) setFill];
        [Rounded(rect, radius) fill];
        Border(rect, radius, 1, @"fieldBorder");
        if ([self cellHasFocus: cell]) [self drawFocusRingInRect: rect radius: radius];
    } else if ([cell drawsBackground]) {
        [([cell backgroundColor] ?: Color(@"textBackgroundColor")) setFill];
        NSRectFill([cell drawingRectForBounds: rect]);
    }
    [cell drawInteriorWithFrame: rect inView: _view];
}

- (void) drawTextFieldBorderInRect: (NSRect) rect bezeledNotLine: (BOOL) bezeled {
    Fill(rect, 0, @"textBackgroundColor");
    Border(rect, 0, 1, @"fieldBorder");
}

- (void) drawSearchGlyphsInRect: (NSRect) rect cancelRect: (NSRect) cancel
                      enabled: (BOOL) enabled showsCancel: (BOOL) showsCancel {
    BOOL flipped = [_view isFlipped];
    NSRect glyph = NSMakeRect(NSMidX(rect) - 6, NSMidY(rect) - 6, 12, 12);
    NSColor *ink = Color(enabled ? @"secondaryLabelColor" : @"disabledControlTextColor");
    NSRect lens = NSMakeRect(NSMinX(glyph) + .5,
            flipped ? NSMinY(glyph) + .5 : NSMaxY(glyph) - 8.5, 8, 8);
    NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect: lens];
    [circle setLineWidth: 1.5];
    [ink setStroke];
    [circle stroke];
    NSPoint handle[] = {GlyphPoint(glyph, 7.5, 7.5, flipped), GlyphPoint(glyph, 11, 11, flipped)};
    StrokeGlyph(handle, 2, 1.5, ink);
    if (showsCancel) {
        NSRect r = NSMakeRect(NSMidX(cancel) - 5, NSMidY(cancel) - 5, 10, 10);
        NSPoint a[] = {GlyphPoint(r, 2, 2, flipped), GlyphPoint(r, 8, 8, flipped)};
        NSPoint b[] = {GlyphPoint(r, 8, 2, flipped), GlyphPoint(r, 2, 8, flipped)};
        StrokeGlyph(a, 2, 1.5, ink);
        StrokeGlyph(b, 2, 1.5, ink);
    }
}

- (void) drawSegmentedTrackInRect: (NSRect) rect {
    rect = NSInsetRect(CenterHeight(rect, 21), 0, .5);
    Fill(rect, 5, @"segmentTrack");
    Border(rect, 5, .5, @"buttonBorder");
}

- (void) drawSegment: (NSInteger) index cell: (NSSegmentedCell *) cell inRect: (NSRect) rect {
    NSRect body = NSInsetRect(CenterHeight(rect, 21), 1, 1.5);
    BOOL selected = [cell isSelectedForSegment: index];
    BOOL accent = selected && [cell trackingMode] == NSSegmentSwitchTrackingSelectAny;
    BOOL enabled = [cell isEnabled] && [cell isEnabledForSegment: index];
    CGContextRef ctx = Context();
    CGContextSaveGState(ctx);
    if (!enabled) { CGContextSetAlpha(ctx, .5); CGContextBeginTransparencyLayer(ctx, NULL); }
    if (selected) {
        ShadowFill(body, 4, accent ? @"controlAccentColor" : @"controlColor",
                   @"buttonShadow", 1, [_view isFlipped]);
        if (!accent) Border(body, 4, .5, @"buttonBorder");
    } else if (index > 0 && ![cell isSelectedForSegment: index - 1]) {
        Fill(NSMakeRect(NSMinX(rect), NSMinY(body) + 3, .5, MAX(0, NSHeight(body) - 6)),
             0, @"separatorColor");
    }
    NSRect titleRect = NSInsetRect(body, 5, 0);
    NSImage *image = [cell imageForSegment: index];
    if (image) {
        NSSize size = [image size];
        CGFloat scale = MIN(1, MIN(16 / MAX(1, size.height), NSWidth(titleRect) / MAX(1, size.width)));
        size.width *= scale; size.height *= scale;
        NSRect imageRect = NSMakeRect(NSMinX(titleRect), NSMidY(rect) - size.height / 2,
                                      size.width, size.height);
        if (![[cell labelForSegment: index] length]) imageRect.origin.x = NSMidX(rect) - size.width / 2;
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, imageRect.origin.x, imageRect.origin.y);
        if ([_view isFlipped]) { CGContextTranslateCTM(ctx, 0, size.height); CGContextScaleCTM(ctx, 1, -1); }
        [image drawInRect: NSMakeRect(0, 0, size.width, size.height) fromRect: NSZeroRect
               operation: NSCompositeSourceOver fraction: 1];
        CGContextRestoreGState(ctx);
        titleRect.origin.x += size.width + 4; titleRect.size.width -= size.width + 4;
    }
    NSAttributedString *title = [[[NSAttributedString alloc]
            initWithString: [cell labelForSegment: index] ?: @""
                attributes: TextAttributes(13, Color(@"controlTextColor"))] autorelease];
    DrawText(title, titleRect, Color(accent ? @"controlColor" : @"controlTextColor"), YES);
    if (!enabled) CGContextEndTransparencyLayer(ctx);
    CGContextRestoreGState(ctx);
}

- (NSSize) sliderKnobSizeForControlSize: (NSControlSize) size {
    return NSMakeSize(20, 20);
}
- (void) drawSliderTrackInRect: (NSRect) rect vertical: (BOOL) vertical hasTickMarks: (BOOL) ticks {
    NSCell *cell = [_view isKindOfClass: [NSControl class]] ? [(NSControl *) _view selectedCell] : nil;
    if (vertical) { rect.origin.x = NSMidX(rect) - 2; rect.size.width = 4; rect = NSInsetRect(rect, 0, 10); }
    else { rect.origin.y = NSMidY(rect) - 2; rect.size.height = 4; rect = NSInsetRect(rect, 10, 0); }
    Fill(rect, 2, @"sliderTrack");
    if ([cell isKindOfClass: [NSSliderCell class]]) {
        NSSliderCell *slider = (NSSliderCell *) cell;
        double span = [slider maxValue] - [slider minValue];
        double fraction = span > 0 ? ([slider doubleValue] - [slider minValue]) / span : 0;
        fraction = fmin(1, fmax(0, fraction));
        // Cocotron's knob mapping runs min -> max along increasing coordinates.
        NSRect fill = rect;
        if (vertical) fill.size.height *= fraction; else fill.size.width *= fraction;
        Fill(fill, 2, @"controlAccentColor");
    }
}
- (void) drawSliderKnobInRect: (NSRect) rect vertical: (BOOL) vertical
                  highlighted: (BOOL) highlighted hasTickMarks: (BOOL) ticks
             tickMarkPosition: (NSTickMarkPosition) position {
    ShadowFill(rect, 10, @"controlColor", @"knobShadow", 2, [_view isFlipped]);
    Border(rect, 10, .5, @"fieldBorder");
    if (highlighted) Fill(rect, 10, @"boxFill");
    if ([_view isKindOfClass: [NSControl class]] &&
        [self cellHasFocus: [(NSControl *) _view selectedCell]])
        [self drawFocusRingInRect: rect radius: 10];
}
- (void) drawSliderTickInRect: (NSRect) rect { Fill(rect, 0, @"tickColor"); }

- (NSRect) drawProgressIndicatorBackground: (NSRect) rect clipRect: (NSRect) clip bezeled: (BOOL) bezeled {
    rect = CenterHeight(rect, 6);
    Fill(rect, 3, @"progressTrack");
    return rect;
}
- (void) drawProgressIndicatorDeterminate: (NSRect) rect clipRect: (NSRect) clip
                                  bezeled: (BOOL) bezeled value: (double) value {
    rect = [self drawProgressIndicatorBackground: rect clipRect: clip bezeled: bezeled];
    rect.size.width *= isfinite(value) ? fmin(1, fmax(0, value)) : 0;
    Fill(rect, 3, @"controlAccentColor");
}
- (void) drawProgressIndicatorIndeterminate: (NSRect) rect clipRect: (NSRect) clip
                                    bezeled: (BOOL) bezeled animation: (double) animation {
    rect = [self drawProgressIndicatorBackground: rect clipRect: clip bezeled: bezeled];
    CGContextSaveGState(Context());
    [Rounded(rect, 3) addClip];
    Fill(rect, 3, @"controlAccentColor");
    [[Color(@"controlColor") colorWithAlphaComponent: .35] setFill];
    CGFloat phase = fmod(animation * NSWidth([_view bounds]), 12);
    for (CGFloat x = NSMinX(rect) - 12 + phase; x < NSMaxX(rect) + 12; x += 12) {
        NSBezierPath *stripe = [NSBezierPath bezierPath];
        [stripe moveToPoint: NSMakePoint(x, NSMinY(rect))];
        [stripe lineToPoint: NSMakePoint(x + 5, NSMinY(rect))];
        [stripe lineToPoint: NSMakePoint(x - 1, NSMaxY(rect))];
        [stripe lineToPoint: NSMakePoint(x - 6, NSMaxY(rect))];
        [stripe closePath]; [stripe fill];
    }
    CGContextRestoreGState(Context());
}

- (void) drawScrollerButtonInRect: (NSRect) rect enabled: (BOOL) enabled
                          pressed: (BOOL) pressed vertical: (BOOL) vertical upOrLeft: (BOOL) before {}
- (void) drawScrollerTrackInRect: (NSRect) rect vertical: (BOOL) vertical upOrLeft: (BOOL) before {
    [self drawScrollerTrackInRect: rect vertical: vertical];
}
- (void) drawScrollerTrackInRect: (NSRect) rect vertical: (BOOL) vertical {
    Fill(rect, 0, @"controlColor");
    if (vertical) rect.size.width = .5; else rect.size.height = .5;
    Fill(rect, 0, @"hairline");
}
- (void) drawScrollerKnobInRect: (NSRect) rect vertical: (BOOL) vertical highlight: (BOOL) highlight {
    if (vertical) { rect.origin.x = NSMidX(rect) - 3.5; rect.size.width = 7; rect = NSInsetRect(rect, 0, 2); }
    else { rect.origin.y = NSMidY(rect) - 3.5; rect.size.height = 7; rect = NSInsetRect(rect, 2, 0); }
    Fill(rect, 3.5, highlight ? @"scrollerKnobHover" : @"scrollerKnob");
}

- (void) drawTableViewHeaderInRect: (NSRect) rect highlighted: (BOOL) highlighted {
    Fill(rect, 0, @"headerColor");
    CGFloat bottom = [_view isFlipped] ? NSMaxY(rect) - .5 : NSMinY(rect);
    Fill(NSMakeRect(NSMinX(rect), bottom, NSWidth(rect), .5), 0, @"separatorColor");
    Fill(NSMakeRect(NSMaxX(rect) - .5, NSMinY(rect) + 4, .5, MAX(0, NSHeight(rect) - 8)), 0, @"hairline");
}
- (void) drawTableViewCornerInRect: (NSRect) rect {
    [self drawTableViewHeaderInRect: rect highlighted: NO];
}
- (void) drawHeaderText: (NSAttributedString *) text inRect: (NSRect) rect {
    NSMutableAttributedString *title = [[text mutableCopy] autorelease];
    [title addAttribute: NSFontAttributeName value: [NSFont systemFontOfSize: 11]
                 range: NSMakeRange(0, [title length])];
    DrawText(title, NSInsetRect(rect, 5, 0), Color(@"headerTextColor"), NO);
}
- (void) drawTableBackground: (NSTableView *) table clipRect: (NSRect) rect {
    [( [table backgroundColor] ?: Color(@"controlBackgroundColor")) setFill];
    NSRectFill(rect);
    if (![table usesAlternatingRowBackgroundColors]) return;
    NSRange rows = [table rowsInRect: rect];
    NSInteger count = [table numberOfRows];
    for (NSUInteger row = rows.location; row != NSNotFound && row < NSMaxRange(rows) && row < count; ++row) {
        NSRect stripe = [table rectOfRow: row];
        stripe.origin.x = NSMinX(rect); stripe.size.width = NSWidth(rect);
        Fill(NSIntersectionRect(stripe, rect), 0,
             row % 2 ? @"alternatingContentBackgroundColor" : @"controlBackgroundColor");
    }
    CGFloat end = count > 0 ? NSMaxY([table rectOfRow: count - 1]) : NSMinY([table bounds]);
    CGFloat stride = [table rowHeight] + [table intercellSpacing].height;
    if (stride <= 0) return;
    NSInteger extra = MAX(0, (NSInteger) floor((NSMinY(rect) - end) / stride));
    for (CGFloat y = end + extra * stride; y < NSMaxY(rect); y += stride, ++extra)
        Fill(NSIntersectionRect(NSMakeRect(NSMinX(rect), y, NSWidth(rect), stride), rect), 0,
             (count + extra) % 2 ? @"alternatingContentBackgroundColor" : @"controlBackgroundColor");
}
- (NSColor *) tableSelectionTextColor: (NSTableView *) table {
    return Color(TableEmphasized(table) ? @"selectedControlTextColor" : @"controlTextColor");
}
- (void) drawTableSelection: (NSTableView *) table clipRect: (NSRect) rect {
    if ([table selectionHighlightStyle] == NSTableViewSelectionHighlightStyleNone) return;
    NSString *color = TableEmphasized(table) ? @"selectedContentBackgroundColor" :
                                             @"unemphasizedSelectedContentBackgroundColor";
    NSRange rows = [table rowsInRect: rect];
    for (NSUInteger row = rows.location; row != NSNotFound && row < NSMaxRange(rows) && row < [table numberOfRows]; ++row) {
        if ([table isRowSelected: row]) {
            NSRect selection = [table rectOfRow: row];
            selection.origin.x = NSMinX(rect); selection.size.width = NSWidth(rect);
            Fill(NSIntersectionRect(selection, rect), 0, color);
        } else {
            for (NSUInteger column = 0; column < [[table tableColumns] count]; ++column) {
                if ([table isColumnSelected: column]) {
                    NSRect selection = [table frameOfCellAtColumn: column row: row];
                    selection.size.width += [table intercellSpacing].width;
                    selection.size.height += [table intercellSpacing].height;
                    Fill(NSIntersectionRect(selection, rect), 0, color);
                }
            }
        }
    }
}

- (void) drawBoxWithLineInRect: (NSRect) rect {
    Fill(rect, 6, @"boxFill"); Border(rect, 6, 1, @"separatorColor");
}
- (void) drawBoxWithBezelInRect: (NSRect) rect clipRect: (NSRect) clip { [self drawBoxWithLineInRect: rect]; }
- (void) drawBoxWithGrooveInRect: (NSRect) rect clipRect: (NSRect) clip { [self drawBoxWithLineInRect: rect]; }
- (void) drawTabPaneInRect: (NSRect) rect { [self drawBoxWithLineInRect: rect]; }
- (void) drawTabInRect: (NSRect) rect clipRect: (NSRect) clip color: (NSColor *) color selected: (BOOL) selected {
    Fill(rect, 4, selected ? @"controlColor" : @"segmentTrack");
    if (selected) Border(rect, 4, .5, @"buttonBorder");
}
- (NSRect) tabRectAtIndex: (NSUInteger) index inTabView: (NSTabView *) tabView {
    NSArray *items = [tabView tabViewItems];
    CGFloat total = 0, offset = 0, width = 0;
    for (NSUInteger i = 0; i < [items count]; ++i) {
        CGFloat w = MAX(40, [[items objectAtIndex: i] sizeOfLabel: NO].width + 16);
        if (i < index) offset += w;
        if (i == index) width = w;
        total += w;
    }
    NSRect bounds = [tabView bounds];
    CGFloat scale = total > 0 ? MIN(1, MAX(0, NSWidth(bounds) - 12) / total) : 1;
    return NSMakeRect(NSMidX(bounds) - total * scale / 2 + offset * scale,
                      [tabView isFlipped] ? NSMinY(bounds) + 1 : NSMaxY(bounds) - 22,
                      width * scale, 21);
}
- (void) drawTopTabView: (NSTabView *) tabView {
    NSRect pane = NSInsetRect([tabView bounds], .5, .5);
    pane.size.height -= 11;
    if ([tabView isFlipped]) pane.origin.y += 11;
    [self drawTabPaneInRect: pane];
    NSUInteger count = [[tabView tabViewItems] count];
    if (!count) return;
    NSRect track = NSUnionRect([self tabRectAtIndex: 0 inTabView: tabView],
                               [self tabRectAtIndex: count - 1 inTabView: tabView]);
    [self drawSegmentedTrackInRect: track];
    for (NSUInteger i = 0; i < count; ++i) {
        NSTabViewItem *item = [tabView tabViewItemAtIndex: i];
        NSRect tab = [self tabRectAtIndex: i inTabView: tabView];
        if (item == [tabView selectedTabViewItem]) {
            ShadowFill(NSInsetRect(tab, 1, 1.5), 4, @"controlColor", @"buttonShadow", 1, [tabView isFlipped]);
            Border(NSInsetRect(tab, 1, 1.5), 4, .5, @"buttonBorder");
            if ([[tabView window] firstResponder] == tabView && [[tabView window] isKeyWindow])
                [self drawFocusRingInRect: NSInsetRect(tab, 1, 1.5) radius: 4];
        } else if (i > 0 && [tabView tabViewItemAtIndex: i - 1] != [tabView selectedTabViewItem]) {
            Fill(NSMakeRect(NSMinX(tab), NSMinY(tab) + 5, .5, 11), 0, @"separatorColor");
        }
        NSAttributedString *title = [[[NSAttributedString alloc] initWithString: [item label] ?: @""
                attributes: TextAttributes(13, Color(@"controlTextColor"))] autorelease];
        DrawText(title, NSInsetRect(tab, 7, 0), Color(@"controlTextColor"), YES);
    }
}

// Menu geometry is shared by layout, drawing and hit testing in NSSubmenuView.
- (CGFloat) menuBarHeight { return 24; }
- (NSSize) menuItemSeparatorSize { return NSMakeSize(0, 9); }
- (NSSize) menuItemCheckMarkSize { return NSMakeSize(12, 12); }
- (NSSize) menuItemGutterSize { return NSMakeSize(19, 22); }
- (NSSize) menuItemBranchArrowSize { return NSMakeSize(16, 12); }
- (CGFloat) menuItemGutterGap { return 2; }
- (Margins) menuItemTextMargins { Margins m = {0, 0, 0, 0}; return m; }
- (NSSize) menuItemTextSize: (NSString *) title {
    NSSize size = [title sizeWithAttributes: TextAttributes(13, Color(@"menuItemTextColor"))];
    return NSMakeSize(ceil(size.width), 22);
}
- (NSSize) menuItemAttributedTextSize: (NSAttributedString *) title {
    NSSize size = [title size]; return NSMakeSize(ceil(size.width), MAX(22, size.height));
}
- (void) drawMenuBarBackgroundInRect: (NSRect) rect { Fill(rect, 0, @"mainMenuBarColor"); }
- (void) drawMenuWindowBackgroundInRect: (NSRect) rect {
    // Use full bounds: partial invalidation must not produce a new panel edge.
    rect = NSInsetRect([_view bounds], .5, .5);
    ShadowFill(rect, 6, @"menuBackgroundColor", @"knobShadow", 3, [_view isFlipped]);
    Border(rect, 6, 1, @"fieldBorder");
}
- (void) drawPopUpButtonWindowBackgroundInRect: (NSRect) rect { [self drawMenuWindowBackgroundInRect: rect]; }
- (void) drawMenuSelectionInRect: (NSRect) rect enabled: (BOOL) enabled {
    if (!enabled) return;
    // Submenu content already has a 3 pt window inset; total inset is 5 pt.
    rect.origin.x = NSMinX([_view bounds]) + 5;
    rect.size.width = MAX(0, NSWidth([_view bounds]) - 10);
    Fill(rect, 4, @"selectedMenuItemColor");
}
- (void) drawMenuBarItemBorderInRect: (NSRect) rect hover: (BOOL) hover selected: (BOOL) selected {
    if (selected) Fill(NSInsetRect(rect, 1, 1), 4, @"selectedMenuItemColor");
}
- (void) drawMenuSeparatorInRect: (NSRect) rect {
    Fill(NSMakeRect(NSMinX([_view bounds]) + 10, floor(NSMidY(rect)),
                    MAX(0, NSWidth([_view bounds]) - 20), 1), 0, @"separatorColor");
}
- (void) drawMenuGutterInRect: (NSRect) rect {}
- (void) drawMenuItemText: (NSString *) string inRect: (NSRect) rect
                  enabled: (BOOL) enabled selected: (BOOL) selected {
    NSColor *ink = Color(!enabled ? @"disabledControlTextColor" :
                        selected ? @"selectedMenuItemTextColor" : @"menuItemTextColor");
    NSAttributedString *title = [[[NSAttributedString alloc] initWithString: string ?: @""
            attributes: TextAttributes(13, ink)] autorelease];
    DrawText(title, rect, ink, NO);
}
- (void) drawAttributedMenuItemText: (NSAttributedString *) string inRect: (NSRect) rect
                            enabled: (BOOL) enabled selected: (BOOL) selected {
    DrawText(string, rect, Color(!enabled ? @"disabledControlTextColor" :
             selected ? @"selectedMenuItemTextColor" : @"menuItemTextColor"), NO);
}
- (void) drawMenuKeyEquivalent: (NSString *) text inRect: (NSRect) rect
                      enabled: (BOOL) enabled selected: (BOOL) selected {
    NSColor *ink = Color(!enabled ? @"disabledControlTextColor" :
                        selected ? @"selectedMenuItemTextColor" : @"secondaryLabelColor");
    NSDictionary *attrs = TextAttributes(13, ink);
    CGFloat width = ceil([text sizeWithAttributes: attrs].width);
    rect.origin.x = NSMaxX(rect) - width; rect.size.width = width;
    NSAttributedString *title = [[[NSAttributedString alloc] initWithString: text attributes: attrs] autorelease];
    DrawText(title, rect, ink, NO);
}
- (void) drawMenuCheckmarkInRect: (NSRect) rect enabled: (BOOL) enabled selected: (BOOL) selected {
    NSRect glyph = NSMakeRect(NSMidX(rect) - 5, NSMidY(rect) - 5, 10, 10);
    NSPoint p[] = {GlyphPoint(glyph, 1, 5, [_view isFlipped]), GlyphPoint(glyph, 4, 8, [_view isFlipped]),
                   GlyphPoint(glyph, 9, 1.5, [_view isFlipped])};
    StrokeGlyph(p, 3, 1.7, Color(!enabled ? @"disabledControlTextColor" :
                selected ? @"selectedMenuItemTextColor" : @"menuItemTextColor"));
}
- (void) drawMenuBranchArrowInRect: (NSRect) rect enabled: (BOOL) enabled selected: (BOOL) selected {
    NSRect glyph = NSMakeRect(NSMidX(rect) - 3, NSMidY(rect) - 4, 6, 8);
    NSPoint p[] = {GlyphPoint(glyph, 1, 1, [_view isFlipped]), GlyphPoint(glyph, 4, 4, [_view isFlipped]),
                   GlyphPoint(glyph, 1, 7, [_view isFlipped])};
    StrokeGlyph(p, 3, 1.5, Color(!enabled ? @"disabledControlTextColor" :
                selected ? @"selectedMenuItemTextColor" : @"secondaryLabelColor"));
}
// Match the older two-argument X11 category selector as well.
- (void) drawMenuBranchArrowInRect: (NSRect) rect selected: (BOOL) selected {
    [self drawMenuBranchArrowInRect: rect enabled: YES selected: selected];
}
@end
