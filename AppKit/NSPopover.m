// OSXER APPKIT (popover): immediate presentation over existing NSPanel and
// NSEvent facilities. Arrow decoration, detachment and animation remain absent.
#import <AppKit/NSPopover.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSViewController.h>
#import <AppKit/NSScreen.h>
#import <AppKit/NSEvent.h>
#import <Foundation/Foundation.h>
NSNotificationName const NSPopoverDidCloseNotification = @"NSPopoverDidCloseNotification";
NSNotificationName const NSPopoverWillCloseNotification = @"NSPopoverWillCloseNotification";
NSNotificationName const NSPopoverWillShowNotification = @"NSPopoverWillShowNotification";
NSNotificationName const NSPopoverDidShowNotification = @"NSPopoverDidShowNotification";
NSString *const NSPopoverCloseReasonKey = @"NSPopoverCloseReasonKey";
NSString *const NSPopoverCloseReasonStandard = @"NSPopoverCloseReasonStandard";
@implementation NSPopover
@synthesize contentViewController = _contentViewController, delegate = _delegate;
@synthesize positioningRect = _positioningRect, behavior = _behavior, animates = _animates;
- (id)init { if ((self = [super init])) _animates = YES; return self; }
- (void)dealloc {
    [NSEvent removeMonitor:_osxerEventMonitor]; [_osxerEventMonitor release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_osxerPositioningWindow removeChildWindow:_osxerPopoverWindow];
    [_osxerPopoverWindow orderOut:nil]; [_osxerPopoverWindow release];
    [_contentViewController release]; [super dealloc];
}
- (NSSize)contentSize { return _contentSize; }
- (void)setContentSize:(NSSize)size {
    _contentSize = size;
    if (_osxerShown) [_osxerPopoverWindow setContentSize:size];
}
- (BOOL)isShown { return _osxerShown; }
- (void)_osxerNotify:(NSString *)name selector:(SEL)selector closing:(BOOL)closing {
    NSDictionary *info = closing ? @{NSPopoverCloseReasonKey:NSPopoverCloseReasonStandard} : nil;
    NSNotification *notification = [NSNotification notificationWithName:name object:self userInfo:info];
    if ([_delegate respondsToSelector:selector]) [_delegate performSelector:selector withObject:notification];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}
- (void)_osxerParentClosed:(NSNotification *)notification { [self close]; }
- (void)_osxerApplicationDeactivated:(NSNotification *)notification {
    if (_behavior == NSPopoverBehaviorTransient) [self performClose:nil];
}
- (void)showRelativeToRect:(NSRect)rect ofView:(NSView *)view preferredEdge:(NSRectEdge)edge {
    [[self retain] autorelease];
    if (![view window] || !_contentViewController)
        [NSException raise:NSInvalidArgumentException format:@"Popover needs a content controller and an attached positioning view"];
    if (_behavior == NSPopoverBehaviorSemitransient && [[view window] parentWindow])
        [NSException raise:NSInvalidArgumentException format:@"Semitransient popovers require a top-level positioning window"];
    if (_osxerShown) [self close];
    NSView *content = [_contentViewController view];
    if (!content) [NSException raise:NSInvalidArgumentException format:@"Popover has no content view"];
    _positioningRect = rect; _osxerPositioningWindow = [view window];
    if (_contentSize.width <= 0 || _contentSize.height <= 0) _contentSize = [content fittingSize];
    NSRect anchor = [[view window] convertRectToScreen:[view convertRect:rect toView:nil]];
    NSRect frame = NSMakeRect(NSMidX(anchor) - _contentSize.width / 2, NSMaxY(anchor), _contentSize.width, _contentSize.height);
    if (edge == NSMinYEdge) frame.origin.y = NSMinY(anchor) - frame.size.height;
    if (edge == NSMinXEdge || edge == NSMaxXEdge) {
        frame.origin.x = edge == NSMinXEdge ? NSMinX(anchor) - frame.size.width : NSMaxX(anchor);
        frame.origin.y = NSMidY(anchor) - frame.size.height / 2;
    }
    NSRect screen = [[_osxerPositioningWindow screen] visibleFrame];
    if (!NSIsEmptyRect(screen)) {
        frame.origin.x = MAX(NSMinX(screen), MIN(frame.origin.x, NSMaxX(screen) - frame.size.width));
        frame.origin.y = MAX(NSMinY(screen), MIN(frame.origin.y, NSMaxY(screen) - frame.size.height));
    }
    if (!_osxerPopoverWindow) {
        _osxerPopoverWindow = [[NSPanel alloc] initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
        [_osxerPopoverWindow setReleasedWhenClosed:NO]; [_osxerPopoverWindow setHasShadow:YES];
    }
    [_osxerPopoverWindow setContentView:content];
    [_osxerPopoverWindow setFrame:frame display:NO];
    [self _osxerNotify:NSPopoverWillShowNotification selector:@selector(popoverWillShow:) closing:NO];
    [_osxerPositioningWindow addChildWindow:_osxerPopoverWindow ordered:NSWindowAbove];
    [_osxerPopoverWindow makeKeyAndOrderFront:nil]; _osxerShown = YES;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_osxerParentClosed:) name:NSWindowWillCloseNotification object:_osxerPositioningWindow];
    [center addObserver:self selector:@selector(_osxerApplicationDeactivated:) name:NSApplicationDidResignActiveNotification object:nil];
    // Under MRC a __block reference is nonretaining; dealloc removes the monitor.
    __block NSPopover *popover = self;
    _osxerEventMonitor = [[NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask | NSRightMouseDownMask | NSKeyDownMask handler:^NSEvent *(NSEvent *event) {
        NSWindow *eventWindow = [event window];
        if (eventWindow == popover->_osxerPopoverWindow) {
            if ([event type] == NSKeyDown && [event keyCode] == 53 &&
                popover->_behavior != NSPopoverBehaviorApplicationDefined) {
                [popover performClose:nil]; return nil;
            }
            return event;
        }
        // OSXER APPKIT (popover behavior): semitransient closes on interaction
        // with the positioning window; transient also observes other windows.
        BOOL transient = popover->_behavior == NSPopoverBehaviorTransient;
        if (transient && [eventWindow isKindOfClass:[NSPanel class]] && [(NSPanel *)eventWindow becomesKeyOnlyIfNeeded])
            return event;
        if (transient || (popover->_behavior == NSPopoverBehaviorSemitransient && eventWindow == popover->_osxerPositioningWindow))
            [popover performClose:nil];
        return event;
    }] retain];
    [self _osxerNotify:NSPopoverDidShowNotification selector:@selector(popoverDidShow:) closing:NO];
}
- (void)performClose:(id)sender {
    [[self retain] autorelease];
    if (![_delegate respondsToSelector:@selector(popoverShouldClose:)] || [_delegate popoverShouldClose:self]) [self close];
}
- (void)close {
    if (!_osxerShown || _osxerClosing) return;
    [[self retain] autorelease]; _osxerClosing = YES;
    @try {
        [self _osxerNotify:NSPopoverWillCloseNotification selector:@selector(popoverWillClose:) closing:YES];
        [NSEvent removeMonitor:_osxerEventMonitor]; [_osxerEventMonitor release]; _osxerEventMonitor = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [_osxerPositioningWindow removeChildWindow:_osxerPopoverWindow];
        [_osxerPopoverWindow orderOut:nil]; _osxerShown = NO; _osxerPositioningWindow = nil;
        [_contentViewController viewDidDisappear];
        [self _osxerNotify:NSPopoverDidCloseNotification selector:@selector(popoverDidClose:) closing:YES];
    } @finally { _osxerClosing = NO; }
}
@end
