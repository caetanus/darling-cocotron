#import <AppKit/NSTitlebarAccessoryViewController.h>

@implementation NSTitlebarAccessoryViewController
@synthesize layoutAttribute = _layoutAttribute, fullScreenMinHeight = _fullScreenMinHeight;
@synthesize hidden = _hidden, automaticallyAdjustsSize = _automaticallyAdjustsSize;

- (instancetype)initWithNibName:(NSString *)name bundle:(NSBundle *)bundle
{
    if ((self = [super initWithNibName:name bundle:bundle])) {
        _layoutAttribute = NSLayoutAttributeBottom;
        _automaticallyAdjustsSize = YES;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        _layoutAttribute = NSLayoutAttributeBottom;
        _automaticallyAdjustsSize = YES;
        if ([coder allowsKeyedCoding] && [coder containsValueForKey:@"NSLayoutAttribute"])
            _layoutAttribute = [coder decodeIntegerForKey:@"NSLayoutAttribute"];
        if ([coder allowsKeyedCoding] && [coder containsValueForKey:@"NSFullScreenMinHeight"])
            _fullScreenMinHeight = [coder decodeDoubleForKey:@"NSFullScreenMinHeight"];
    }
    return self;
}

// Hiding the accessory hides its view, as on macOS.
- (void)setHidden:(BOOL)hidden
{
    _hidden = hidden;
    if ([self isViewLoaded]) [[self view] setHidden:hidden];
}

- (void)viewWillAppear {}
- (void)viewDidAppear {}
- (void)viewDidDisappear {}
@end
