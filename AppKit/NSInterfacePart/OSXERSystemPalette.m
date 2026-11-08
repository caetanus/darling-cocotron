#import "OSXERSystemPalette.h"
#import <AppKit/NSColor.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>

BOOL OSXERBigSurEnabled(void) {
    return ![[[NSUserDefaults standardUserDefaults]
            stringForKey: @"OSXERGraphicsStyle"] isEqualToString: @"Classic"];
}

typedef struct {
    unsigned rgb;
    CGFloat alpha;
} OSXERPaletteValue;

typedef struct {
    NSString *name;
    OSXERPaletteValue light;
    OSXERPaletteValue dark; // TODO: supply dark values in the dark appearance round.
} OSXERPaletteEntry;

// A negative alpha denotes an absent dark value, never a usable black colour.
#define ENTRY(name, rgb, alpha) { @name, {rgb, alpha}, {0, -1} }
static const OSXERPaletteEntry entries[] = {
    ENTRY("windowBackgroundColor", 0xECECEC, 1),
    ENTRY("controlBackgroundColor", 0xFFFFFF, 1),
    ENTRY("textBackgroundColor", 0xFFFFFF, 1),
    ENTRY("controlColor", 0xFFFFFF, 1),
    ENTRY("controlTextColor", 0x000000, .85),
    ENTRY("textColor", 0x000000, .85),
    ENTRY("labelColor", 0x000000, .85),
    ENTRY("secondaryLabelColor", 0x000000, .50),
    ENTRY("tertiaryLabelColor", 0x000000, .26),
    ENTRY("disabledControlTextColor", 0x000000, .25),
    ENTRY("controlAccentColor", 0x007AFF, 1),
    ENTRY("keyboardFocusIndicatorColor", 0x007AFF, 1),
    ENTRY("keyboardFocusIndicator", 0x007AFF, 1),
    ENTRY("focusRing", 0x007AFF, .50),
    ENTRY("selectedContentBackgroundColor", 0x0063E1, 1),
    ENTRY("selectedControlColor", 0x0063E1, 1),
    ENTRY("alternateSelectedControlColor", 0x0063E1, 1),
    ENTRY("unemphasizedSelectedContentBackgroundColor", 0xDCDCDC, 1),
    ENTRY("secondarySelectedControlColor", 0xDCDCDC, 1),
    ENTRY("unemphasizedSelectedTextBackgroundColor", 0xDCDCDC, 1),
    ENTRY("unemphasizedSelectedTextColor", 0x000000, .85),
    ENTRY("selectedTextBackgroundColor", 0xB3D7FF, 1),
    ENTRY("selectedTextColor", 0x000000, .85),
    ENTRY("selectedControlTextColor", 0xFFFFFF, 1),
    ENTRY("alternateSelectedControlTextColor", 0xFFFFFF, 1),
    ENTRY("alternatingContentBackgroundColor", 0xF4F5F5, 1),
    ENTRY("gridColor", 0xE6E6E6, 1),
    ENTRY("separatorColor", 0x000000, .10),
    ENTRY("headerColor", 0xFFFFFF, 1),
    ENTRY("headerTextColor", 0x000000, .85),
    ENTRY("selectedMenuItemColor", 0x007AFF, 1),
    ENTRY("selectedMenuItemTextColor", 0xFFFFFF, 1),
    ENTRY("menuItemTextColor", 0x000000, .85),
    ENTRY("menuBackgroundColor", 0xF6F6F6, 1),
    ENTRY("mainMenuBarColor", 0xF6F6F6, 1),
    ENTRY("buttonPressed", 0xE5E5E5, 1),
    ENTRY("buttonBorder", 0x000000, .10),
    ENTRY("buttonShadow", 0x000000, .15),
    ENTRY("checkBorder", 0x000000, .20),
    ENTRY("fieldBorder", 0x000000, .15),
    ENTRY("segmentTrack", 0xE3E3E3, 1),
    ENTRY("sliderTrack", 0xD7D7D7, 1),
    ENTRY("knobShadow", 0x000000, .25),
    ENTRY("tickColor", 0x000000, .25),
    ENTRY("progressTrack", 0xE5E5E5, 1),
    ENTRY("scrollerKnob", 0x000000, .30),
    ENTRY("scrollerKnobHover", 0x000000, .45),
    ENTRY("hairline", 0x000000, .08),
    ENTRY("boxFill", 0x000000, .03),
};
#undef ENTRY

@implementation OSXERSystemPalette
+ (NSColor *) colorWithName: (NSString *) name {
    for (NSUInteger i = 0; i < sizeof(entries) / sizeof(entries[0]); ++i) {
        if ([name isEqualToString: entries[i].name]) {
            OSXERPaletteValue value = entries[i].light;
            return [NSColor colorWithSRGBRed: ((value.rgb >> 16) & 255) / 255.0
                                      green: ((value.rgb >> 8) & 255) / 255.0
                                       blue: (value.rgb & 255) / 255.0
                                      alpha: value.alpha];
        }
    }
    return nil; // Unknown system names retain the backend's existing fallback.
}
@end
