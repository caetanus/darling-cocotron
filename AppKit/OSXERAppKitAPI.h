// OSXER APPKIT (API storage): typed category accessors for ABI-neutral stored state.
// These properties preserve application state; their rendering effects are partial.
#import <Foundation/Foundation.h>
#import <Foundation/NSLayoutAnchor.h>
#import <objc/runtime.h>

#define OSXER_API_OBJECT(Type, Getter, Setter, Policy) \
- (Type)Getter { return objc_getAssociatedObject(self, @selector(Getter)); } \
- (void)Setter:(Type)value { objc_setAssociatedObject(self, @selector(Getter), value, Policy); }

#define OSXER_API_SCALAR(Type, Getter, Setter, Default) \
- (Type)Getter { \
    NSValue *stored = objc_getAssociatedObject(self, @selector(Getter)); \
    Type value = Default; if (stored) [stored getValue:&value]; return value; \
} \
- (void)Setter:(Type)value { \
    objc_setAssociatedObject(self, @selector(Getter), \
        [NSValue valueWithBytes:&value objCType:@encode(Type)], OBJC_ASSOCIATION_RETAIN_NONATOMIC); \
}

@interface NSLayoutAnchor (OSXERAnchorConstruction)
- (id)_osxerInitWithItem:(id)item attribute:(NSLayoutAttribute)attribute;
@end

// A single instance per item/attribute; the anchor's item is nonretained.
static inline id OSXERAppKitAnchor(id item, SEL key, Class type, NSLayoutAttribute attribute) {
    id anchor = objc_getAssociatedObject(item, key);
    if (!anchor) {
        anchor = [[type alloc] _osxerInitWithItem:item attribute:attribute];
        objc_setAssociatedObject(item, key, anchor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [anchor release];
    }
    return anchor;
}
