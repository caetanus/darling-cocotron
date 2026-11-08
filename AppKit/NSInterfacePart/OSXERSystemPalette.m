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
// OSXER BIGSUR R2 (measured palette): light-focus-window.png, RGB samples:
// background (10,100)=246; field (170,198)=227, bottom (170,221)=187;
// box (400,480)=238, edge (393,480)=228; scroller (356,380)=194;
// separator (20,308)=222; ticks (572,246)=209; level (460,548)=40,205,65.
static const OSXERPaletteEntry entries[] = {
    ENTRY("windowBackgroundColor", 0xF6F6F6, 1),
    ENTRY("controlBackgroundColor", 0xFFFFFF, 1),
    ENTRY("textBackgroundColor", 0xFFFFFF, 1),
    ENTRY("controlColor", 0xFFFFFF, 1),
    // OSXER BIGSUR R2 (label ink): modal dark pixels in Push buttons,
    // Sample text and Titled box are all RGB(38,38,38), on three backgrounds.
    ENTRY("controlTextColor", 0x262626, 1),
    ENTRY("textColor", 0x262626, 1),
    ENTRY("labelColor", 0x262626, 1),
    ENTRY("secondaryLabelColor", 0x000000, .50),
    ENTRY("tertiaryLabelColor", 0x000000, .26),
    ENTRY("disabledControlTextColor", 0xB8B8B8, 1),
    ENTRY("controlAccentColor", 0x007AFF, 1),
    ENTRY("keyboardFocusIndicatorColor", 0x007AFF, 1),
    ENTRY("keyboardFocusIndicator", 0x007AFF, 1),
    ENTRY("focusRing", 0x7CAEF6, 1),
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
    ENTRY("checkBorder", 0xD1D1D1, 1),
    ENTRY("fieldBorder", 0xE3E3E3, 1),
    ENTRY("segmentTrack", 0xE3E3E3, 1),
    ENTRY("sliderTrack", 0xEAEAEA, 1),
    ENTRY("knobShadow", 0x000000, .25),
    ENTRY("tickColor", 0xD1D1D1, 1),
    ENTRY("progressTrack", 0xE5E5E5, 1),
    ENTRY("scrollerKnob", 0xC2C2C2, 1),
    ENTRY("scrollerKnobHover", 0x000000, .45),
    ENTRY("hairline", 0x000000, .08),
    ENTRY("boxFill", 0xEEEEEE, 1),
    ENTRY("boxBorder", 0xE4E4E4, 1),
    ENTRY("fieldBottom", 0xBBBBBB, 1),
    ENTRY("buttonBottom", 0xBABABA, 1),
    ENTRY("disabledButtonInk", 0x808080, 1), // 50% group -> #BBBBBB on #F6F6F6
    ENTRY("scrollerTrack", 0xFAFAFA, 1),
    ENTRY("levelFill", 0x28CD41, 1),
    ENTRY("levelBorder", 0x23B239, 1),
    ENTRY("levelEmpty", 0xE5E5E5, 1),
    ENTRY("levelEmptyBorder", 0xC7C7C7, 1),
    ENTRY("wellBorder", 0xCCCCCC, 1),
    // OSXER BIGSUR R2 (disabled field/check): samples documented at call sites.
    ENTRY("checkTop", 0xBCBCBC, 1),
    ENTRY("disabledFieldFill", 0xFBFBFB, 1),
    ENTRY("disabledFieldBorder", 0xF1F1F1, 1),
    ENTRY("disabledFieldBottom", 0xDCDCDC, 1),
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
