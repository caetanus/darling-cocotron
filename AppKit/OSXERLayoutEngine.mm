/* OSXER APPKIT (auto layout): a constraint solver for NSLayoutConstraint.

   Darling's AppKit stored constraints but never solved them, so every Auto Layout view kept the
   frame it had in Interface Builder (Transmission's window: a 480x240 table in a 1280x800
   window). This pass solves a window's constraints with kiwi (a Cassowary implementation,
   Modified BSD, ThirdParty/kiwi/LICENSE) and applies the frames.

   Model, in window coordinates (y up):
   - every view that takes part (a constraint item, or translatesAutoresizingMaskIntoConstraints
     NO) gets four variables: x, y, width, height; a layout guide stands for its owning view;
   - views that translate their autoresizing mask are fixed at their current frame; the
     content view keeps its origin and prefers its size at priority 500 (macOS's
     NSLayoutPriorityWindowSizeStayPut), so required content constraints resize the window; Cocoa's autoresizing moves them when an Auto Layout parent resizes, so the
     pass repeats (at most three times) until nothing moves;
   - Auto Layout views get width, height >= 0, their intrinsic content size as hugging and
     compression-resistance constraints (priorities 250/750 by default, as on macOS), and a
     very weak preference for their current frame, so an underconstrained view stays put;
   - each constraint becomes first.attribute (relation) multiplier * second.attribute + constant
     at its priority; 1000 is required, lower priorities keep their order as kiwi strengths.

   The pass runs before a window displays when a view asked for layout, a constraint changed, or
   the content view changed size. Not modelled: right-to-left leading/trailing, exact baselines
   (estimated from the font), layout margins (the guide is its view's bounds). */

#import <AppKit/NSView.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSControl.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSButtonCell.h>
#import <AppKit/NSCell.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSImageView.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSLayoutConstraint.h>
#import <AppKit/NSLayoutGuide.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <math.h>
#include <map>
#include <vector>
#include "ThirdParty/kiwi/kiwi.h"

extern "C" void OSXERWindowSetNeedsLayoutPass(NSWindow *window);
extern "C" void OSXERLayoutWindowIfNeeded(NSWindow *window);

static const void *OSXERNeedsLayoutKey = &OSXERNeedsLayoutKey;
static const void *OSXERLaidOutSizeKey = &OSXERLaidOutSizeKey;
static const void *OSXERAskedSizeKey = &OSXERAskedSizeKey;
static BOOL OSXERInLayoutPass = NO;

void OSXERWindowSetNeedsLayoutPass(NSWindow *window) {
    if (window && !OSXERInLayoutPass)
        objc_setAssociatedObject(window, OSXERNeedsLayoutKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

namespace {

struct Item {
    kiwi::Variable x, y, w, h;
    bool fixed;
};

static NSView *ItemView(id item) {
    if ([item isKindOfClass: [NSView class]]) return item;
    if ([item isKindOfClass: [NSLayoutGuide class]]) return [(NSLayoutGuide *) item owningView];
    return nil;
}

static double Strength(double priority) {
    if (priority >= NSLayoutPriorityRequired) return kiwi::strength::required;
    if (priority < 1) priority = 1;
    return kiwi::strength::create(0, priority, 0);
}

static double DefaultedPriority(double value, double fallback) {
    return value > 0 ? value : fallback;
}

// Distance from the bottom of the view to its text baseline, estimated from the font: cells
// centre a single line vertically.
static double BaselineFromBottom(NSView *view, double height) {
    if ([view respondsToSelector: @selector(font)]) {
        NSFont *font = [(id) view font];
        if (font) {
            double line = [font ascender] - [font descender];
            return floor((height - line) / 2 - [font descender]);
        }
    }
    return 0;
}

static kiwi::Expression Attribute(Item &v, NSLayoutAttribute attribute, NSView *view, double height) {
    switch (attribute) {
    case NSLayoutAttributeLeft:
    case NSLayoutAttributeLeading: return kiwi::Expression(kiwi::Term(v.x));
    case NSLayoutAttributeRight:
    case NSLayoutAttributeTrailing: return v.x + v.w;
    case NSLayoutAttributeBottom: return kiwi::Expression(kiwi::Term(v.y));
    case NSLayoutAttributeTop: return v.y + v.h;
    case NSLayoutAttributeWidth: return kiwi::Expression(kiwi::Term(v.w));
    case NSLayoutAttributeHeight: return kiwi::Expression(kiwi::Term(v.h));
    case NSLayoutAttributeCenterX: return v.x + 0.5 * v.w;
    case NSLayoutAttributeCenterY: return v.y + 0.5 * v.h;
    case NSLayoutAttributeLastBaseline: return v.y + BaselineFromBottom(view, height);
    case NSLayoutAttributeFirstBaseline: return v.y + BaselineFromBottom(view, height);
    default: return kiwi::Expression(kiwi::Term(v.x));
    }
}

static void Collect(NSView *view, std::vector<NSView *> &views, NSMutableArray *constraints) {
    views.push_back(view);
    [constraints addObjectsFromArray: [view constraints]];
    for (NSView *child in [view subviews]) Collect(child, views, constraints);
}

static void AddConstraint(kiwi::Solver &solver, const kiwi::Constraint &constraint) {
    try {
        solver.addConstraint(constraint);
    } catch (const kiwi::UnsatisfiableConstraint &) {
        // A conflicting required constraint: macOS breaks one and logs; keep it as strong.
        static int logged;
        if (logged++ < 5) NSLog(@"Auto Layout: unsatisfiable required constraint, kept as optional");
        try { solver.addConstraint(kiwi::Constraint(constraint.expression(), constraint.op(), kiwi::strength::create(0, 999, 0))); }
        catch (...) {}
    } catch (...) {
    }
}

// One solve over the window; returns whether any frame changed.
static BOOL LayoutOnce(NSWindow *window) {
    NSView *root = [window contentView];
    if (!root) return NO;
    std::vector<NSView *> views;
    NSMutableArray *constraints = [NSMutableArray array];
    Collect(root, views, constraints);

    std::map<NSView *, Item> items;
    std::map<NSView *, NSRect> rects;
    auto ensure = [&](NSView *view) -> Item * {
        if (!view || (view != root && ![view isDescendantOf: root])) return nullptr;
        auto found = items.find(view);
        if (found != items.end()) return &found->second;
        Item &item = items[view];
        item.fixed = view != root && [view translatesAutoresizingMaskIntoConstraints];
        rects[view] = [view convertRect: [view bounds] toView: nil];
        return &item;
    };
    for (NSLayoutConstraint *constraint in constraints) {
        if (![constraint isActive]) continue;
        ensure(ItemView([constraint firstItem]));
        ensure(ItemView([constraint secondItem]));
    }
    for (NSView *view : views)
        if (![view translatesAutoresizingMaskIntoConstraints]) ensure(view);
    if (items.size() <= 1) return NO;

    kiwi::Solver solver;
    const double weak = kiwi::strength::create(0, 0, 1);
    for (auto &entry : items) {
        NSView *view = entry.first;
        Item &v = entry.second;
        NSRect r = rects[view];
        if (view == root) {
            // The window keeps its size at NSLayoutPriorityWindowSizeStayPut (500): required
            // content constraints, and stronger ones, can resize it, as on macOS.
            AddConstraint(solver, v.x == r.origin.x);
            AddConstraint(solver, v.y == r.origin.y);
            AddConstraint(solver, v.w >= 0);
            AddConstraint(solver, v.h >= 0);
            AddConstraint(solver, (v.w == r.size.width) | Strength(500));
            AddConstraint(solver, (v.h == r.size.height) | Strength(500));
            continue;
        }
        if (v.fixed) {
            AddConstraint(solver, v.x == r.origin.x);
            AddConstraint(solver, v.y == r.origin.y);
            AddConstraint(solver, v.w == r.size.width);
            AddConstraint(solver, v.h == r.size.height);
            continue;
        }
        AddConstraint(solver, v.w >= 0);
        AddConstraint(solver, v.h >= 0);
        AddConstraint(solver, (v.x == r.origin.x) | weak);
        AddConstraint(solver, (v.y == r.origin.y) | weak);
        AddConstraint(solver, (v.w == r.size.width) | weak);
        AddConstraint(solver, (v.h == r.size.height) | weak);
        NSSize intrinsic = [view intrinsicContentSize];
        if (intrinsic.width >= 0) {
            double hug = DefaultedPriority([view contentHuggingPriorityForOrientation: NSLayoutConstraintOrientationHorizontal], 250);
            double resist = DefaultedPriority([view contentCompressionResistancePriorityForOrientation: NSLayoutConstraintOrientationHorizontal], 750);
            AddConstraint(solver, (v.w >= intrinsic.width) | Strength(resist));
            AddConstraint(solver, (v.w <= intrinsic.width) | Strength(hug));
        }
        if (intrinsic.height >= 0) {
            double hug = DefaultedPriority([view contentHuggingPriorityForOrientation: NSLayoutConstraintOrientationVertical], 250);
            double resist = DefaultedPriority([view contentCompressionResistancePriorityForOrientation: NSLayoutConstraintOrientationVertical], 750);
            AddConstraint(solver, (v.h >= intrinsic.height) | Strength(resist));
            AddConstraint(solver, (v.h <= intrinsic.height) | Strength(hug));
        }
    }

    for (NSLayoutConstraint *constraint in constraints) {
        if (![constraint isActive]) continue;
        NSView *firstView = ItemView([constraint firstItem]);
        NSView *secondView = ItemView([constraint secondItem]);
        auto first = items.find(firstView);
        if (first == items.end()) continue;
        kiwi::Expression lhs = Attribute(first->second, [constraint firstAttribute], firstView, rects[firstView].size.height);
        kiwi::Expression rhs(kiwi::Term(first->second.x, 0.0), [constraint constant]);
        if (secondView && [constraint secondAttribute] != NSLayoutAttributeNotAnAttribute) {
            auto second = items.find(secondView);
            if (second == items.end()) continue;
            kiwi::Expression other = Attribute(second->second, [constraint secondAttribute], secondView, rects[secondView].size.height);
            rhs = [constraint multiplier] * other + [constraint constant];
        }
        double strength = Strength([constraint priority]);
        switch ([constraint relation]) {
        case NSLayoutRelationLessThanOrEqual: AddConstraint(solver, (lhs <= rhs) | strength); break;
        case NSLayoutRelationGreaterThanOrEqual: AddConstraint(solver, (lhs >= rhs) | strength); break;
        default: AddConstraint(solver, (lhs == rhs) | strength); break;
        }
    }

    solver.updateVariables();

    // The content's size: resize the window when the constraints moved it, unless the window
    // manager already refused that size (a tiling manager keeps its own), so passes don't fight.
    BOOL changed = NO;
    Item &content = items[root];
    NSSize wanted = NSMakeSize(round(content.w.value()), round(content.h.value()));
    NSSize current = [root frame].size;
    if (fabs(wanted.width - current.width) >= 1 || fabs(wanted.height - current.height) >= 1) {
        NSValue *asked = objc_getAssociatedObject(window, OSXERAskedSizeKey);
        if (!asked || !NSEqualSizes([asked sizeValue], wanted)) {
            objc_setAssociatedObject(window, OSXERAskedSizeKey, [NSValue valueWithSize: wanted],
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [window setContentSize: wanted];
            changed = YES;
        }
    }

    // Parents first: a child's frame is relative to its superview's new position.
    for (NSView *view : views) {
        auto found = items.find(view);
        if (found == items.end() || found->second.fixed || view == root) continue;
        Item &v = found->second;
        NSRect inWindow = NSMakeRect(round(v.x.value()), round(v.y.value()),
                                     round(MAX(0, v.w.value())), round(MAX(0, v.h.value())));
        NSView *superview = [view superview];
        NSRect frame = superview ? [superview convertRect: inWindow fromView: nil] : inWindow;
        frame = NSIntegralRect(frame);
        if (!NSEqualRects(frame, [view frame])) {
            [view setFrame: frame];
            changed = YES;
        }
    }
    return changed;
}

} // namespace

void OSXERLayoutWindowIfNeeded(NSWindow *window) {
    if (!window || OSXERInLayoutPass) return;
    NSView *root = [window contentView];
    if (!root) return;
    NSValue *laidOut = objc_getAssociatedObject(window, OSXERLaidOutSizeKey);
    BOOL sizeChanged = !laidOut || !NSEqualSizes([laidOut sizeValue], [root frame].size);
    if (!sizeChanged && !objc_getAssociatedObject(window, OSXERNeedsLayoutKey)) return;
    OSXERInLayoutPass = YES;
    @try {
        for (int pass = 0; pass < 3 && LayoutOnce(window); pass++) {}
    } @catch (NSException *exception) {
        NSLog(@"Auto Layout pass failed: %@", exception);
    } @finally {
        OSXERInLayoutPass = NO;
    }
    objc_setAssociatedObject(window, OSXERNeedsLayoutKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(window, OSXERLaidOutSizeKey, [NSValue valueWithSize: [root frame].size],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [root setNeedsDisplay: YES];
}

// OSXER APPKIT (auto layout): intrinsic content sizes of the common controls, as macOS reports
// them: the cell's natural size; editable text fields have no intrinsic width.
@implementation NSControl (OSXERIntrinsicSize)
- (NSSize) intrinsicContentSize {
    NSCell *cell = [self cell];
    if (!cell) return [super intrinsicContentSize];
    NSSize size = [cell cellSize];
    if (size.width <= 0 || size.width > 1e5) size.width = NSViewNoIntrinsicMetric;
    if (size.height <= 0 || size.height > 1e5) size.height = NSViewNoIntrinsicMetric;
    return size;
}
@end

// Push buttons: the Big Sur style insets the body 6 pt per side (5 small, plus 1 when default)
// and the title 8 pt more, so the title needs that room to draw untruncated.
@implementation NSButton (OSXERIntrinsicSize)
- (NSSize) intrinsicContentSize {
    NSSize size = [super intrinsicContentSize];
    NSButtonCell *cell = [self cell];
    if (size.width >= 0 && [cell isBordered] && [cell imagePosition] != NSImageOnly &&
        ([cell bezelStyle] == NSRoundedBezelStyle || [cell bezelStyle] == NSRegularSquareBezelStyle)) {
        CGFloat title = [[cell attributedTitle] size].width;
        CGFloat side = [cell controlSize] == NSSmallControlSize ? 5 : 6;
        size.width = MAX(size.width, ceil(title + 2 * (side + 8) + 2));
    }
    return size;
}
@end

@implementation NSTextField (OSXERIntrinsicSize)
- (NSSize) intrinsicContentSize {
    NSSize size = [super intrinsicContentSize];
    if ([self isEditable]) size.width = NSViewNoIntrinsicMetric;
    return size;
}
@end

@implementation NSImageView (OSXERIntrinsicSize)
- (NSSize) intrinsicContentSize {
    NSImage *image = [self image];
    if (!image) return NSMakeSize(NSViewNoIntrinsicMetric, NSViewNoIntrinsicMetric);
    return [image size];
}
@end
