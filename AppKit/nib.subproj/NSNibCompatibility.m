// OSXER NIB (archive support classes): independent implementations from the
// supplied archive schema. These classes carry compiler metadata, not app code.
#import <AppKit/NSView.h>
#import <AppKit/NSLayoutGuide.h>
#import <AppKit/NSWindowController.h>
#import <Foundation/Foundation.h>

@interface IBClassReference : NSObject <NSCoding> {
    NSString *_className, *_moduleName;
    NSString *_moduleProvider;
}
@property(readonly) NSString *className;
@end
@implementation IBClassReference
@synthesize className = _className;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _className = [[coder decodeObjectForKey:@"IBClassName"] copy];
        _moduleName = [[coder decodeObjectForKey:@"IBModuleName"] copy];
        _moduleProvider = [[coder decodeObjectForKey:@"IBModuleProvider"] copy];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_className forKey:@"IBClassName"];
    [coder encodeObject:_moduleName forKey:@"IBModuleName"];
    [coder encodeObject:_moduleProvider forKey:@"IBModuleProvider"];
}
- (void)dealloc { [_className release]; [_moduleName release]; [_moduleProvider release]; [super dealloc]; }
@end

@interface IBImageConfiguration : NSObject <NSCoding> {
    NSArray *_colors;
    id _locale;
    NSInteger _renderingMode, _symbolScale;
    NSNumber *_variableValue;
}
@end
@implementation IBImageConfiguration
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _colors = [[coder decodeObjectForKey:@"IBHierarchicalColors"] copy];
        _locale = [[coder decodeObjectForKey:@"IBLocale"] retain];
        _renderingMode = [coder decodeIntegerForKey:@"IBRenderingMode"];
        _symbolScale = [coder decodeIntegerForKey:@"IBSymbolScale"];
        _variableValue = [[coder decodeObjectForKey:@"IBVariableValue"] retain];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_colors forKey:@"IBHierarchicalColors"];
    [coder encodeObject:_locale forKey:@"IBLocale"];
    [coder encodeInteger:_renderingMode forKey:@"IBRenderingMode"];
    [coder encodeInteger:_symbolScale forKey:@"IBSymbolScale"];
    [coder encodeObject:_variableValue forKey:@"IBVariableValue"];
}
- (void)dealloc { [_colors release]; [_locale release]; [_variableValue release]; [super dealloc]; }
@end

@interface IBNSViewAutolayoutGuide : NSLayoutGuide { NSInteger _systemType; }
@end
@implementation IBNSViewAutolayoutGuide
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder]))
        _systemType = [coder decodeIntegerForKey:@"IBNSLayoutGuideSystemType"];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeInteger:_systemType forKey:@"IBNSLayoutGuideSystemType"];
}
@end

@interface IBNSWindowController : NSWindowController
@end
@implementation IBNSWindowController
@end

@interface _NSCornerView : NSView
@end
@implementation _NSCornerView
@end

@interface _NSRuleEditorViewUnboundRowHolder : NSObject <NSCoding> { NSArray *_boundArray; }
@property(readonly) NSArray *boundArray;
@end
@implementation _NSRuleEditorViewUnboundRowHolder
@synthesize boundArray = _boundArray;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) _boundArray = [[coder decodeObjectForKey:@"NSBoundArray"] retain];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeObject:_boundArray forKey:@"NSBoundArray"]; }
- (void)dealloc { [_boundArray release]; [super dealloc]; }
@end

@interface NSStackViewContainer : NSView {
    NSArray *_nonDroppedViews;
    id _stackView;
    id _customSpacing, _visibilityPriorities;
}
@property(readonly) NSArray *nonDroppedViews;
@end
@implementation NSStackViewContainer
@synthesize nonDroppedViews = _nonDroppedViews;
- (id)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _nonDroppedViews = [[coder decodeObjectForKey:@"NSStackViewContainerNonDroppedViews"] copy];
        _stackView = [coder decodeObjectForKey:@"NSStackViewContainerStackView"];
        _customSpacing = [[coder decodeObjectForKey:@"NSStackViewContainerViewToCustomAfterSpaceMap"] retain];
        _visibilityPriorities = [[coder decodeObjectForKey:@"NSStackViewContainerVisibilityPriorities"] retain];
    }
    return self;
}
- (void)dealloc {
    [_nonDroppedViews release]; [_customSpacing release]; [_visibilityPriorities release]; [super dealloc];
}
@end
