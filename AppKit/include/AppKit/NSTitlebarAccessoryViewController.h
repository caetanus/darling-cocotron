#import <AppKit/NSViewController.h>
#import <AppKit/NSLayoutConstraint.h>
#import <Foundation/Foundation.h>

// OSXER APPKIT (titlebar accessories): Apple's properties, stored; the theme does not draw
// accessories in the title bar yet. Replaces a stub that swallowed every message.
@interface NSTitlebarAccessoryViewController : NSViewController {
    NSLayoutAttribute _layoutAttribute;
    CGFloat _fullScreenMinHeight;
    BOOL _hidden, _automaticallyAdjustsSize;
}
@property NSLayoutAttribute layoutAttribute;
@property CGFloat fullScreenMinHeight;
@property(getter=isHidden) BOOL hidden;
@property BOOL automaticallyAdjustsSize;
- (void)viewWillAppear;
- (void)viewDidAppear;
- (void)viewDidDisappear;
@end
