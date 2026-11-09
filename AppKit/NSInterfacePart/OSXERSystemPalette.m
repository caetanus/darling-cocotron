#import "OSXERSystemPalette.h"
#import <AppKit/NSColor.h>
#import <AppKit/NSAppearance.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUserDefaults.h>
#include <stdlib.h>
#include <strings.h>

BOOL OSXERBigSurEnabled(void) {
    return ![[[NSUserDefaults standardUserDefaults]
            stringForKey: @"OSXERGraphicsStyle"] isEqualToString: @"Classic"];
}

// OSXER BIGSUR DARK (selection): explicit application appearance wins in
// NSApplication; otherwise env dark/light > OSXERAppearance Dark/Light > Aqua.
NSAppearance *OSXERPreferredAppearance(void) {
    const char *environment = getenv("OSXER_APPEARANCE");
    NSString *preference = [[NSUserDefaults standardUserDefaults]
            stringForKey: @"OSXERAppearance"];
    BOOL dark = preference != nil && [preference caseInsensitiveCompare: @"Dark"] == NSOrderedSame;
    if (environment && strcasecmp(environment, "dark") == 0) dark = YES;
    else if (environment && strcasecmp(environment, "light") == 0) dark = NO;
    return [NSAppearance appearanceNamed: dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
}

typedef struct {
    unsigned rgb;
    CGFloat alpha;
} OSXERPaletteValue;

typedef struct {
    NSString *name;
    OSXERPaletteValue light;
    OSXERPaletteValue dark;
} OSXERPaletteEntry;

// OSXER BIGSUR DARK (macOS 15 calibration): supplied dark-window.png and
// dark-focus-window.png, sampled by gallery/measure-dark-calibrate.py.
// Coordinates below are PNG pixels from the top left. Opaque paint values
// are composited observations; gradients interpolate measured endpoints.
// Uncaptured semantic states explicitly reuse measured neighbouring roles.
// Light columns are unchanged, including their previous fitted values.
#define ENTRY(name, rgb, alpha, darkRGB, darkAlpha) \
    { @name, {rgb, alpha}, {darkRGB, darkAlpha} }
static const OSXERPaletteEntry entries[] = {
    // dark-window.png (10,100)=#282828
    ENTRY("windowBackgroundColor", 0xF6F6F6, 1, 0x282828, 1),
    // dark-window.png (100,380)=#1E1E1E
    ENTRY("controlBackgroundColor", 0xFFFFFF, 1, 0x1E1E1E, 1),
    // dark-window.png (170,216)=#333333
    ENTRY("textBackgroundColor", 0xFFFFFF, 1, 0x333333, 1),
    // dark-window.png (150,48)=#5E5E5E
    ENTRY("controlColor", 0xFFFFFF, 1, 0x5E5E5E, 1),
    // dark-window.png (69,47)=#DEDEDE
    ENTRY("controlTextColor", 0x262626, 1, 0xDEDEDE, 1),
    // dark-window.png (207,210)=#E1E1E1
    ENTRY("textColor", 0x262626, 1, 0xE1E1E1, 1),
    // dark-window.png (69,47)=#DEDEDE
    ENTRY("labelColor", 0x262626, 1, 0xDEDEDE, 1),
    // dark-window.png (396,14)=#A2A2A2; fallback: subdued window-title ink; no secondaryLabelColor control in gallery
    ENTRY("secondaryLabelColor", 0x000000, .50, 0xA2A2A2, 1),
    // dark-window.png (336,210)=#626262; fallback: disabled field ink; no tertiary label in gallery
    ENTRY("tertiaryLabelColor", 0x000000, .26, 0x626262, 1),
    // dark-window.png (336,210)=#626262
    ENTRY("disabledControlTextColor", 0xB8B8B8, 1, 0x626262, 1),
    // dark-window.png (410,245)=#177BE5
    ENTRY("controlAccentColor", 0x007AFF, 1, 0x177BE5, 1),
    // dark-window.png (410,245)=#177BE5; fallback: slider accent; semantic focus colour not separately exposed
    ENTRY("keyboardFocusIndicatorColor", 0x007AFF, 1, 0x177BE5, 1),
    // dark-window.png (410,245)=#177BE5; fallback: slider accent; actual ring measured separately
    ENTRY("keyboardFocusIndicator", 0x007AFF, 1, 0x177BE5, 1),
    // dark-focus-window.png (15,210)=#216993
    ENTRY("focusRing", 0x7CAEF6, 1, 0x216993, 1),
    // dark-window.png (547,283)=#1769E6; fallback: busy accent; emphasized table selection absent
    ENTRY("selectedContentBackgroundColor", 0x0063E1, 1, 0x1769E6, 1),
    // dark-window.png (547,283)=#1769E6; fallback: busy accent; emphasized selection absent
    ENTRY("selectedControlColor", 0x0063E1, 1, 0x1769E6, 1),
    // dark-window.png (547,283)=#1769E6; fallback: busy accent; emphasized selection absent
    ENTRY("alternateSelectedControlColor", 0x0063E1, 1, 0x1769E6, 1),
    // dark-window.png (100,400)=#464646
    ENTRY("unemphasizedSelectedContentBackgroundColor", 0xDCDCDC, 1, 0x464646, 1),
    // dark-window.png (100,400)=#464646
    ENTRY("secondarySelectedControlColor", 0xDCDCDC, 1, 0x464646, 1),
    // dark-window.png (100,400)=#464646
    ENTRY("unemphasizedSelectedTextBackgroundColor", 0xDCDCDC, 1, 0x464646, 1),
    // dark-window.png (34,400)=#E3E3E3
    ENTRY("unemphasizedSelectedTextColor", 0x000000, .85, 0xE3E3E3, 1),
    // dark-window.png (100,400)=#464646; fallback: unemphasized table selection; selected text absent
    ENTRY("selectedTextBackgroundColor", 0xB3D7FF, 1, 0x464646, 1),
    // dark-window.png (34,400)=#E3E3E3; fallback: selected table ink; selected text absent
    ENTRY("selectedTextColor", 0x000000, .85, 0xE3E3E3, 1),
    // dark-window.png (34,400)=#E3E3E3
    ENTRY("selectedControlTextColor", 0xFFFFFF, 1, 0xE3E3E3, 1),
    // dark-window.png (34,400)=#E3E3E3
    ENTRY("alternateSelectedControlTextColor", 0xFFFFFF, 1, 0xE3E3E3, 1),
    // dark-window.png (100,446)=#292929
    ENTRY("alternatingContentBackgroundColor", 0xF4F5F5, 1, 0x292929, 1),
    // dark-window.png (36,444)=#DFDFDF, text on alternating #292929 row.
    ENTRY("tableAlternateText", 0x262626, 1, 0xDFDFDF, 1),
    // dark-window.png (191,351)=#424242; fallback: header divider; row grid disabled in gallery
    ENTRY("gridColor", 0xE6E6E6, 1, 0x424242, 1),
    // dark-window.png (20,308)=#3D3D3D
    ENTRY("separatorColor", 0x000000, .10, 0x3D3D3D, 1),
    // dark-window.png (30,345)=#1E1E1E
    ENTRY("headerColor", 0xFFFFFF, 1, 0x1E1E1E, 1),
    // dark-window.png (26,352)=#FFFFFF
    ENTRY("headerTextColor", 0x000000, .85, 0xFFFFFF, 1),
    // dark-window.png (547,283)=#1769E6; fallback: busy accent; menu absent
    ENTRY("selectedMenuItemColor", 0x007AFF, 1, 0x1769E6, 1),
    // dark-window.png (288,51)=#DCEAF9; fallback: default button glyph; menu absent
    ENTRY("selectedMenuItemTextColor", 0xFFFFFF, 1, 0xDCEAF9, 1),
    // dark-window.png (69,47)=#DEDEDE; fallback: primary label; menu absent
    ENTRY("menuItemTextColor", 0x000000, .85, 0xDEDEDE, 1),
    // dark-window.png (10,100)=#282828; fallback: window; menu absent
    ENTRY("menuBackgroundColor", 0xF6F6F6, 1, 0x282828, 1),
    // dark-window.png (10,100)=#282828; fallback: window; menu bar absent
    ENTRY("mainMenuBarColor", 0xF6F6F6, 1, 0x282828, 1),
    // dark-window.png (177,240)=#666666; fallback: selected segment; pressed button absent
    ENTRY("buttonPressed", 0xE5E5E5, 1, 0x666666, 1),
    // dark-window.png (150,40)=#646464
    ENTRY("buttonBorder", 0x000000, .10, 0x646464, 1),
    // dark-window.png (150,60)=#222222; 1 - observed/window; blur remains a fit, not recovered from one pixel
    ENTRY("buttonShadow", 0x000000, .15, 0x000000, 0.15),
    // dark-window.png (136,86)=#565656
    ENTRY("checkBorder", 0xD1D1D1, 1, 0x565656, 1),
    // dark-window.png (170,199)=#444444
    ENTRY("fieldBorder", 0xE3E3E3, 1, 0x444444, 1),
    // dark-window.png (170,216)=#333333
    ENTRY("segmentTrack", 0xE3E3E3, 1, 0x333333, 1),
    // dark-window.png (530,245)=#3E3E3E
    ENTRY("sliderTrack", 0xEAEAEA, 1, 0x3E3E3E, 1),
    // dark-window.png (150,60)=#222222; 1 - observed/window; blur remains a fit, not recovered from one pixel
    ENTRY("knobShadow", 0x000000, .25, 0x000000, 0.15),
    // dark-window.png (572,246)=#535353
    ENTRY("tickColor", 0xD1D1D1, 1, 0x535353, 1),
    // dark-window.png (530,245)=#3E3E3E
    ENTRY("progressTrack", 0xE5E5E5, 1, 0x3E3E3E, 1),
    // dark-window.png (356,380)=#6B6B6B
    ENTRY("scrollerKnob", 0xC2C2C2, 1, 0x6B6B6B, 1),
    // dark-window.png (356,380)=#6B6B6B; fallback: resting scroller; hover absent
    ENTRY("scrollerKnobHover", 0x000000, .45, 0x6B6B6B, 1),
    // dark-window.png (191,351)=#424242
    ENTRY("hairline", 0x000000, .08, 0x424242, 1),
    // dark-window.png (400,480)=#2F2F2F
    ENTRY("boxFill", 0xEEEEEE, 1, 0x2F2F2F, 1),
    // dark-window.png (393,480)=#484848
    ENTRY("boxBorder", 0xE4E4E4, 1, 0x484848, 1),
    // dark-window.png (170,220)=#606060
    ENTRY("fieldBottom", 0xBBBBBB, 1, 0x606060, 1),
    // dark-window.png (150,60)=#222222
    ENTRY("buttonBottom", 0xBABABA, 1, 0x222222, 1),
    // dark-window.png (398,50)=#727272; 2 * observed - window; disabled group alpha=0.5
    ENTRY("disabledButtonInk", 0x808080, 1, 0xBCBCBC, 1),
    // dark-window.png (354,490)=#2B2B2B
    ENTRY("scrollerTrack", 0xFAFAFA, 1, 0x2B2B2B, 1),
    // dark-window.png (460,548)=#32D74B
    ENTRY("levelFill", 0x28CD41, 1, 0x32D74B, 1),
    // dark-window.png (455,548)=#2CBB41
    ENTRY("levelBorder", 0x23B239, 1, 0x2CBB41, 1),
    // dark-window.png (540,548)=#3E3E3E
    ENTRY("levelEmpty", 0xE5E5E5, 1, 0x3E3E3E, 1),
    // dark-window.png (540,540)=#363636
    ENTRY("levelEmptyBorder", 0xC7C7C7, 1, 0x363636, 1),
    // dark-window.png (150,48)=#5E5E5E
    ENTRY("wellBorder", 0xCCCCCC, 1, 0x5E5E5E, 1),
    // dark-window.png (143,79)=#4F4F4F
    ENTRY("checkTop", 0xBCBCBC, 1, 0x4F4F4F, 1),
    // dark-window.png (320,216)=#2D2D2D
    ENTRY("disabledFieldFill", 0xFBFBFB, 1, 0x2D2D2D, 1),
    // dark-window.png (320,199)=#353535
    ENTRY("disabledFieldBorder", 0xF1F1F1, 1, 0x353535, 1),
    // dark-window.png (320,220)=#414141
    ENTRY("disabledFieldBottom", 0xDCDCDC, 1, 0x414141, 1),
    // dark-window.png (250,41)=#187AE5
    ENTRY("accentTop", 0x2891FF, 1, 0x187AE5, 1),
    // dark-window.png (250,59)=#146ECC
    ENTRY("accentBottom", 0x007AFF, 1, 0x146ECC, 1),
    // dark-window.png (288,51)=#DCEAF9
    ENTRY("accentGlyph", 0xFFFFFF, 1, 0xDCEAF9, 1),
    // dark-window.png (62,210)=#666666
    ENTRY("placeholderText", 0xC0C0C0, 1, 0x666666, 1),
    // dark-window.png (20,308)=#3D3D3D
    ENTRY("separatorLine", 0xDEDEDE, 1, 0x3D3D3D, 1),
    // dark-window.png (410,245)=#177BE5; fallback: slider accent; caret not visible in focused PNG
    // OSXER TEXTEDIT LOOK (caret): light reference x4..5, y88..101 = #007AFF.
    ENTRY("insertionPoint", 0x007AFF, 1, 0x177BE5, 1),
    // dark-window.png (547,283)=#1769E6
    ENTRY("busyFill", 0x007AFF, 1, 0x1769E6, 1),
    // dark-window.png (177,240)=#666666
    ENTRY("segmentSelected", 0xFFFFFF, 1, 0x666666, 1),
    // dark-window.png (150,40)=#646464
    ENTRY("buttonTop", 0xFFFFFF, 1, 0x646464, 1),
    // dark-window.png (136,86)=#565656
    ENTRY("stepperDivider", 0xE3E3E3, 1, 0x565656, 1),
    // dark-window.png (530,245)=#3E3E3E
    ENTRY("scrollerEdge", 0x000000, .08, 0x3E3E3E, 1),
    // dark-window.png (207,210)=#E1E1E1
    ENTRY("segmentText", 0x262626, 1, 0xE1E1E1, 1),
    // dark-window.png (165,216)=#3E3E3E
    ENTRY("fieldSide", 0xE3E3E3, 1, 0x3E3E3E, 1),
    // dark-window.png (170,200)=#303030
    ENTRY("fieldInsetTop", 0xFFFFFF, 1, 0x303030, 1),
    // dark-window.png (170,201)=#323232
    ENTRY("fieldInsetSecond", 0xFFFFFF, 1, 0x323232, 1),
    // dark-window.png (313,216)=#333333
    ENTRY("disabledFieldSide", 0xF1F1F1, 1, 0x333333, 1),
    // dark-window.png (320,200)=#2C2C2C
    ENTRY("disabledFieldInset", 0xFBFBFB, 1, 0x2C2C2C, 1),
    // dark-window.png (180,50)=#E7E7E7
    ENTRY("buttonText", 0x262626, 1, 0xE7E7E7, 1),
    // dark-window.png (159,120)=#DFDFDF
    ENTRY("checkText", 0x262626, 1, 0xDFDFDF, 1),
    // dark-window.png (216,247)=#E8E8E8
    ENTRY("segmentSelectedText", 0x262626, 1, 0xE8E8E8, 1),
    // dark-window.png (250,40)=#2481E6
    ENTRY("accentEdge", 0x2891FF, 1, 0x2481E6, 1),
    // dark-window.png (250,60)=#202020, below the default bezel.
    ENTRY("accentShadow", 0x007AFF, 1, 0x202020, 1),
    // dark-window.png (143,80)=#494949
    ENTRY("checkOffTop", 0xFFFFFF, 1, 0x494949, 1),
    // dark-window.png (143,92)=#656565
    ENTRY("checkOffBottom", 0xFFFFFF, 1, 0x656565, 1),
    // dark-window.png (253,80)=#1768E5
    ENTRY("checkOnTop", 0x2891FF, 1, 0x1768E5, 1),
    // dark-window.png (253,92)=#155FCE
    ENTRY("checkOnBottom", 0x007AFF, 1, 0x155FCE, 1),
    // dark-window.png (253,79)=#2372E7
    ENTRY("checkOnEdge", 0x2891FF, 1, 0x2372E7, 1),
    // dark-window.png (253,87)=#DCE8F9
    ENTRY("checkGlyph", 0xFFFFFF, 1, 0xDCE8F9, 1),
    // dark-window.png (460,246)=#949494
    ENTRY("sliderKnob", 0xFFFFFF, 1, 0x949494, 1),
    // dark-window.png (95,279)=#DADADA
    ENTRY("stepperText", 0x262626, 1, 0xDADADA, 1),
    // dark-window.png (100,368)=#383838
    ENTRY("headerSeparator", 0x000000, .10, 0x383838, 1),
    // dark-window.png (251,551)=#DFDFDF
    ENTRY("dateText", 0x262626, 1, 0xDFDFDF, 1),
    // dark-window.png (513,87)=#5E5E5E; 2 * observed - window; disabled group alpha=0.5
    ENTRY("disabledCheckInk", 0x808080, 1, 0x949494, 1),
    // dark-window.png (16,460)=#353535
    ENTRY("tableBorder", 0xE5E5E5, 1, 0x353535, 1),
    // dark-window.png: eight ray cores, clockwise from west. Light does not
    // use these roles; its existing twelve-ray grayscale renderer is retained.
    // (712,286)=#424242; (724,296)=#A1A1A1
    ENTRY("spinnerDim", 0x000000, 1, 0x424242, 1),
    ENTRY("spinnerBright", 0xE6E6E6, 1, 0xA1A1A1, 1),
    // (717,279)=#4F4F4F; (724,276)=#616161; (730,279)=#6C6C6C
    ENTRY("spinnerNW", 0x000000, 1, 0x4F4F4F, 1),
    ENTRY("spinnerN", 0x000000, 1, 0x616161, 1),
    ENTRY("spinnerNE", 0x000000, 1, 0x6C6C6C, 1),
    // (734,286)=#818181; (731,293)=#8A8A8A; (717,292)=#4E4E4E
    ENTRY("spinnerE", 0x000000, 1, 0x818181, 1),
    ENTRY("spinnerSE", 0x000000, 1, 0x8A8A8A, 1),
    ENTRY("spinnerSW", 0x000000, 1, 0x4E4E4E, 1),
};
#undef ENTRY

// OSXER BIGSUR DARK (drawing scope): includes the gallery's explicit
// setAppearance: call, without an application-specific environment check.
BOOL OSXERDarkAppearance(void) {
    NSAppearanceName match = [[NSAppearance currentDrawingAppearance]
            bestMatchFromAppearancesWithNames: [NSArray arrayWithObjects:
                    NSAppearanceNameAqua, NSAppearanceNameDarkAqua, nil]];
    return [match isEqualToString: NSAppearanceNameDarkAqua];
}

@implementation OSXERSystemPalette
+ (NSColor *) colorWithName: (NSString *) name {
    BOOL dark = OSXERDarkAppearance();
    for (NSUInteger i = 0; i < sizeof(entries) / sizeof(entries[0]); ++i) {
        if ([name isEqualToString: entries[i].name]) {
            OSXERPaletteValue value = dark ? entries[i].dark : entries[i].light;
            return [NSColor colorWithSRGBRed: ((value.rgb >> 16) & 255) / 255.0
                                      green: ((value.rgb >> 8) & 255) / 255.0
                                       blue: (value.rgb & 255) / 255.0
                                      alpha: value.alpha];
        }
    }
    return nil; // Unknown system names retain the backend's existing fallback.
}
@end
