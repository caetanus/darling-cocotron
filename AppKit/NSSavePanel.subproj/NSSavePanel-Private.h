// OSXER MVP (panel directory): shared default for open/save/document panels.
#import <AppKit/NSSavePanel.h>

@interface NSSavePanel (DefaultDirectory)
+ (NSString *) _defaultDirectory;
@end
