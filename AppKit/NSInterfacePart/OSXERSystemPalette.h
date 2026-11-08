#import <Foundation/NSObject.h>

@class NSColor, NSString;

// The preference is read at use time; choose Classic before creating controls.
BOOL OSXERBigSurEnabled(void);

@interface OSXERSystemPalette : NSObject
+ (NSColor *) colorWithName: (NSString *) name;
@end
