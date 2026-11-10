// OSXER APPKIT (popover): public window-backed presentation and lifecycle.
#import <AppKit/NSResponder.h>
#import <AppKit/NSView.h>
@class NSViewController, NSWindow;
APPKIT_EXPORT NSNotificationName const NSPopoverDidCloseNotification;
APPKIT_EXPORT NSNotificationName const NSPopoverWillCloseNotification;
APPKIT_EXPORT NSNotificationName const NSPopoverWillShowNotification;
APPKIT_EXPORT NSNotificationName const NSPopoverDidShowNotification;
APPKIT_EXPORT NSString *const NSPopoverCloseReasonKey;
APPKIT_EXPORT NSString *const NSPopoverCloseReasonStandard;
typedef NS_ENUM(NSInteger, NSPopoverBehavior) {
    NSPopoverBehaviorApplicationDefined = 0, NSPopoverBehaviorTransient = 1, NSPopoverBehaviorSemitransient = 2
};
@class NSPopover;
@protocol NSPopoverDelegate <NSObject>
@optional
- (BOOL)popoverShouldClose:(NSPopover *)popover;
- (void)popoverWillShow:(NSNotification *)notification;
- (void)popoverDidShow:(NSNotification *)notification;
- (void)popoverWillClose:(NSNotification *)notification;
- (void)popoverDidClose:(NSNotification *)notification;
@end
@interface NSPopover : NSResponder {
    NSViewController *_contentViewController;
    NSWindow *_osxerPopoverWindow, *_osxerPositioningWindow;
    id<NSPopoverDelegate> _delegate;
    id _osxerEventMonitor;
    NSSize _contentSize;
    NSRect _positioningRect;
    NSPopoverBehavior _behavior;
    BOOL _animates, _osxerShown, _osxerClosing;
}
@property(retain) NSViewController *contentViewController;
@property(assign) id<NSPopoverDelegate> delegate;
@property NSSize contentSize;
@property NSRect positioningRect;
@property NSPopoverBehavior behavior;
@property BOOL animates;
@property(readonly, getter=isShown) BOOL shown;
- (void)showRelativeToRect:(NSRect)rect ofView:(NSView *)view preferredEdge:(NSRectEdge)edge;
- (void)close;
- (void)performClose:(id)sender;
@end
