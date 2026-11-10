#import <AppKit/NSResponder.h>
#import <AppKit/NSUserInterfaceItemIdentification.h>

@class NSView, NSStoryboard;

@interface NSViewController : NSResponder <NSUserInterfaceItemIdentification> {
    NSString *_nibName;
    NSBundle *_nibBundle;
    id _representedObject;
    NSString *_title;
    NSView *_view;
    NSUserInterfaceItemIdentifier _identifier;
    // OSXER NIB (split storyboard views)
    NSStoryboard *_storyboard;
    NSDictionary *_externalObjectsForViewLoading;
    NSArray *_externalSelfIdentifiers;
    // OSXER APPKIT (controller containment): the child holds a nonretained parent.
    NSMutableArray *_osxerChildren;
    NSViewController *_osxerParent;
    BOOL _osxerDidLoadView;
}

- initWithNibName: (NSString *) name bundle: (NSBundle *) bundle;

// OSXER NIB (storyboard ownership)
- (NSStoryboard *) storyboard;
- (NSString *) nibName;
- (NSBundle *) nibBundle;

- (NSView *) view;
- (NSString *) title;
- representedObject;

- (void) setRepresentedObject: object;

- (void) setTitle: (NSString *) value;

- (void) setView: (NSView *) value;

- (void) loadView;
- (BOOL) isViewLoaded; // 10.10
// OSXER APPKIT (controller lifecycle)
- (void)viewDidDisappear;

- (void) discardEditing;

- (BOOL) commitEditing;
- (void) commitEditingWithDelegate: delegate
                 didCommitSelector: (SEL) didCommitSelector
                       contextInfo: (void *) contextInfo;

@end

// OSXER APPKIT (controller lifecycle): presentation/transition animation remains partial.
@interface NSViewController (OSXERControllerAPI)
@property NSSize preferredContentSize;
@property(readonly) NSViewController *parentViewController;
@property(readonly, copy) NSArray *childViewControllers;
- (void)addChildViewController:(NSViewController *)child;
- (void)insertChildViewController:(NSViewController *)child atIndex:(NSInteger)index;
- (void)removeChildViewControllerAtIndex:(NSInteger)index;
- (void)removeFromParentViewController;
- (void)viewDidLoad;
- (void)viewWillAppear;
- (void)viewDidAppear;
- (void)viewWillDisappear;
- (void)viewWillLayout;
- (void)viewDidLayout;
- (void)updateViewConstraints;
@end
