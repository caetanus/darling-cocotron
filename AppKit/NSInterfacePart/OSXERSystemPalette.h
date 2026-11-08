#import <Foundation/NSObject.h>

@class NSAppearance, NSColor, NSString;

// The preference is read at use time; choose Classic before creating controls.
BOOL OSXERBigSurEnabled(void);

// OSXER BIGSUR DARK (selection): used only when NSApp.appearance is nil.
NSAppearance *OSXERPreferredAppearance(void);

// OSXER BIGSUR DARK (drawing): share appearance resolution with paint geometry.
BOOL OSXERDarkAppearance(void);

@interface OSXERSystemPalette : NSObject
+ (NSColor *) colorWithName: (NSString *) name;
@end
