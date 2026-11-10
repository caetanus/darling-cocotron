// OSXER NIB (decoder): private AppKit coder for compiled interface archives.
#import <Foundation/Foundation.h>

typedef struct NSNibArchiveObject NSNibArchiveObject;
typedef struct NSNibArchiveValue NSNibArchiveValue;

@interface NSNibArchiveUnarchiver : NSCoder {
    NSData *_data;
    NSMutableArray *_keys, *_classes, *_fallbacks, *_storage, *_owned;
    NSMutableDictionary *_classMap, *_byteBuffers;
    NSNibArchiveObject *_objects;
    NSNibArchiveValue *_values;
    NSUInteger _objectCount, _valueCount, _current, _depth;
    unsigned _coderVersion;
    id _delegate;
    BOOL _failed;
}
+ (BOOL) isNibArchiveData: (NSData *) data;
- (id) initForReadingWithData: (NSData *) data;
- (void) setClass: (Class) aClass forClassName: (NSString *) name;
- (Class) classForClassName: (NSString *) name;
- (void) setDelegate: (id) delegate;
- (id) delegate;
- (void) replaceObject: (id) object withObject: (id) replacement;
- (void) finishDecoding;
- (BOOL) failed;
@end
