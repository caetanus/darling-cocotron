// OSXER NIB (storyboard context): private hooks shared by the controller loaders.
#import <AppKit/NSStoryboard.h>
#import <AppKit/NSViewController.h>
#import <AppKit/NSWindowController.h>
@interface NSViewController (NSStoryboardOutlet)
- (void) setStoryboard: (NSStoryboard *) storyboard;
@end
@interface NSWindowController (NSStoryboardOutlet)
- (void) setStoryboard: (NSStoryboard *) storyboard;
@end
@interface NSStoryboard (NSNibLoadingPrivate)
- (BOOL) _loadMainMenu;
- (BOOL) _loadViewController: (NSViewController *) controller externalObjects: (NSDictionary *) objects;
@end
