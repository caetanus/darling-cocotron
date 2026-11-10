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

- (void) discardEditing;

- (BOOL) commitEditing;
- (void) commitEditingWithDelegate: delegate
                 didCommitSelector: (SEL) didCommitSelector
                       contextInfo: (void *) contextInfo;

@end
