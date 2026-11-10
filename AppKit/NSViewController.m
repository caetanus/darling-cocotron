#import <AppKit/NSNib.h>
// OSXER NIB (storyboard context)
#import "NSStoryboardPrivate.h"
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSViewController.h>
#import <AppKit/NSView.h>

@implementation NSViewController

// OSXER APPKIT (controller lifecycle): documented default hook does nothing.
- (void)viewDidDisappear {}

@synthesize identifier = _identifier;

- initWithNibName: (NSString *) name bundle: (NSBundle *) bundle {
    _nibName = [name copy];
    _nibBundle = [bundle retain];
    return self;
}

- initWithCoder: (NSCoder *) coder {
    if ([coder allowsKeyedCoding]) {
        _nibName = [[coder decodeObjectForKey: @"NSNibName"] copy];
        // OSXER NIB (split view state)
        _identifier = [[coder decodeObjectForKey: @"NSStoryboardIdentifier"] copy];
        NSDictionary *external = [coder decodeObjectForKey: @"NSExternalObjectsTableForViewLoading"];
        NSMutableDictionary *others = [NSMutableDictionary dictionary];
        NSMutableArray *selfIdentifiers = [NSMutableArray array];
        for (NSString *key in external) {
            id value = [external objectForKey: key];
            if (value == self) [selfIdentifiers addObject: key];
            else [others setObject: value forKey: key];
        }
        // The upstream-owner entry must not create a controller -> table ->
        // controller retain cycle. Reconstitute it only during view loading.
        _externalObjectsForViewLoading = [others copy];
        _externalSelfIdentifiers = [selfIdentifiers copy];
        _title = [[coder decodeObjectForKey: @"NSTitle"] copy];
        NSString *bundleIdentifier =
                [coder decodeObjectForKey: @"NSNibBundleIdentifier"];
        if (bundleIdentifier != nil)
            _nibBundle = [[NSBundle bundleWithIdentifier: bundleIdentifier] retain];
    }

    return self;
}

- (void) dealloc {
    // OSXER APPKIT (controller containment): no dangling parent after release.
    for (NSViewController *child in _osxerChildren) child->_osxerParent = nil;
    [_osxerChildren release];
    [_identifier release];
    // OSXER NIB (controller ownership)
    [_nibName release]; [_nibBundle release]; [_title release];
    [_representedObject release]; [_view release];
    [_storyboard release]; [_externalObjectsForViewLoading release]; [_externalSelfIdentifiers release];

    [super dealloc];
}

// OSXER NIB (storyboard outlet)
- (NSStoryboard *) storyboard { return _storyboard; }
- (void) setStoryboard: (NSStoryboard *) storyboard {
    [storyboard retain]; [_storyboard release]; _storyboard = storyboard;
}

- (NSString *) nibName {
    return _nibName;
}

- (NSBundle *) nibBundle {
    return _nibBundle;
}

- (NSView *) view {
    if (_view == nil) [self loadView];
    if (_view && !_osxerDidLoadView) { _osxerDidLoadView = YES; [self viewDidLoad]; }
    return _view;
}

- (BOOL) isViewLoaded {
    return _view != nil;
}

- (NSString *) title {
    return _title;
}

- representedObject {
    return _representedObject;
}

- (void) setRepresentedObject: object {
    object = [object retain];
    [_representedObject release];
    _representedObject = object;
}

- (void) setTitle: (NSString *) value {
    value = [value retain];
    [_title release];
    _title = value;
}

- (void) setView: (NSView *) value {
    value = [value retain];
    [_view release];
    _view = value;
    if (!value) _osxerDidLoadView = NO;
}

- (void) loadView {
    // OSXER NIB (split view resource): preserve subclass loadView dispatch.
    if (_storyboard) {
        NSMutableDictionary *external = [NSMutableDictionary dictionaryWithDictionary: _externalObjectsForViewLoading ?: @{}];
        for (NSString *key in _externalSelfIdentifiers) [external setObject: self forKey: key];
        [_storyboard _loadViewController: self externalObjects: external];
        return;
    }
    NSString *name = [self nibName];
    NSBundle *bundle = [self nibBundle];

    if (name == nil) {
        // should pathForResource assert name for non-nil?
        [NSException raise: NSInvalidArgumentException
                    format: @"-[%@ %s] nibName is nil", [self class], _cmd];
        return;
    }

    if (bundle == nil)
        bundle = [NSBundle mainBundle];

    NSString *path = [bundle pathForResource: name ofType: @"nib"];
    NSDictionary *nameTable = [NSDictionary dictionaryWithObject: self
                                                          forKey: NSNibOwner];

    if (path == nil)
        NSLog(@"NSViewController unable to find nib named %@, bundle=%@", name,
              bundle);

    [bundle loadNibFile: path externalNameTable: nameTable withZone: NULL];
}

- (void) discardEditing {
    NSUnimplementedMethod();
}

- (BOOL) commitEditing {
    NSUnimplementedMethod();
    return NO;
}

- (void) commitEditingWithDelegate: delegate
                 didCommitSelector: (SEL) didCommitSelector
                       contextInfo: (void *) contextInfo
{
    NSUnimplementedMethod();
}

@end

// OSXER APPKIT (controller containment): preserve identity and reject cycles before mutation.
#import "OSXERAppKitAPI.h"
@implementation NSViewController (OSXERControllerAPI)
OSXER_API_SCALAR(NSSize, preferredContentSize, setPreferredContentSize, NSZeroSize)
- (NSViewController *)parentViewController { return _osxerParent; }
- (NSArray *)childViewControllers { return _osxerChildren ? [[_osxerChildren copy] autorelease] : [NSArray array]; }
- (void)addChildViewController:(NSViewController *)child { [self insertChildViewController:child atIndex:[_osxerChildren count]]; }
- (void)insertChildViewController:(NSViewController *)child atIndex:(NSInteger)index {
    if (!child || child->_osxerParent || index < 0 || index > [_osxerChildren count])
        [NSException raise:NSInvalidArgumentException format:@"Invalid child controller insertion"];
    for (NSViewController *parent = self; parent; parent = parent->_osxerParent)
        if (parent == child) [NSException raise:NSInvalidArgumentException format:@"Controller containment cycle"];
    if (!_osxerChildren) _osxerChildren = [NSMutableArray new];
    [_osxerChildren insertObject:child atIndex:index]; child->_osxerParent = self;
}
- (void)removeChildViewControllerAtIndex:(NSInteger)index {
    NSViewController *child = [_osxerChildren objectAtIndex:index]; child->_osxerParent = nil;
    [_osxerChildren removeObjectAtIndex:index];
}
- (void)removeFromParentViewController {
    if (_osxerParent) [_osxerParent removeChildViewControllerAtIndex:[_osxerParent->_osxerChildren indexOfObjectIdenticalTo:self]];
}
- (void)viewDidLoad { }
- (void)viewWillAppear { }
- (void)viewDidAppear { }
- (void)viewWillDisappear { }
- (void)viewWillLayout { }
- (void)viewDidLayout { }
- (void)updateViewConstraints { [[self view] updateConstraintsForSubtreeIfNeeded]; }
@end
