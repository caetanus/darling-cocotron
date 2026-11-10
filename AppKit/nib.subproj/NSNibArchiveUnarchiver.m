// OSXER NIB (decoder): format from BRIEF-nibarchive.md, checked with the supplied
// compiled resources by tools/nibarchive-dump.py. No third-party implementation.
#import "NSNibArchiveUnarchiver.h"
#import <Foundation/NSKeyedArchiver.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct NSNibArchiveObject {
    uint32_t classIndex, first, count;
    id object;                 // borrowed while initWithCoder: runs; _owned afterwards
    BOOL started;
};
struct NSNibArchiveValue {
    uint32_t key, reference;
    uint8_t type;
    id scalar;                 // retained by _storage
};
typedef struct {
    const uint8_t *bytes;
    NSUInteger position, end;
} NibReader;

static void NibInvalid(NSString *reason) {
    [NSException raise: NSInvalidUnarchiveOperationException format: @"%@", reason];
}

// Every byte read goes through this bounds check, including table-local bounds.
static const uint8_t *NibTake(NibReader *r, NSUInteger length) {
    if (r->position > r->end || length > r->end - r->position)
        NibInvalid(@"truncated table");
    const uint8_t *result = r->bytes + r->position;
    r->position += length;
    return result;
}
static uint64_t NibLE(NibReader *r, unsigned count) {
    const uint8_t *p = NibTake(r, count);
    uint64_t n = 0;
    for (unsigned i = 0; i < count; i++) n |= (uint64_t)p[i] << (8 * i);
    return n;
}
static uint32_t NibVarint(NibReader *r) {
    uint32_t n = 0;
    for (unsigned shift = 0; shift <= 28; shift += 7) {
        uint8_t b = *NibTake(r, 1);
        if (shift == 28 && (b & 0x70)) NibInvalid(@"varint overflow");
        n |= (uint32_t)(b & 0x7f) << shift;
        if (b & 0x80) return n;
    }
    NibInvalid(@"unterminated varint");
    return 0;
}
static NSString *NibString(NibReader *r, NSUInteger length) {
    NSString *s = [[[NSString alloc] initWithBytes: NibTake(r, length)
            length: length encoding: NSUTF8StringEncoding] autorelease];
    if (!s) NibInvalid(@"invalid UTF-8");
    return s;
}

// OSXER NIB (immutable inline collections): expose Foundation's immutable
// interfaces while constructing into stable storage, so back references work.
@interface NSNibArchiveArray : NSArray { NSMutableArray *_items; }
- (void) _append: (id) item;
@end
@implementation NSNibArchiveArray
- (id) init { if ((self = [super init])) _items = [NSMutableArray new]; return self; }
- (void) dealloc { [_items release]; [super dealloc]; }
- (NSUInteger) count { return [_items count]; }
- (id) objectAtIndex: (NSUInteger) index { return [_items objectAtIndex: index]; }
- (void) _append: (id) item { [_items addObject: item]; }
- (id) copyWithZone: (NSZone *) zone { return [self retain]; }
- (id) mutableCopyWithZone: (NSZone *) zone { return [_items mutableCopyWithZone: zone]; }
- (Class) classForCoder { return [NSArray class]; }
@end
@interface NSNibArchiveSet : NSSet { NSMutableSet *_items; }
- (void) _append: (id) item;
@end
@implementation NSNibArchiveSet
- (id) init { if ((self = [super init])) _items = [NSMutableSet new]; return self; }
- (void) dealloc { [_items release]; [super dealloc]; }
- (NSUInteger) count { return [_items count]; }
- (id) member: (id) item { return [_items member: item]; }
- (NSEnumerator *) objectEnumerator { return [_items objectEnumerator]; }
- (void) _append: (id) item { [_items addObject: item]; }
- (id) copyWithZone: (NSZone *) zone { return [self retain]; }
- (id) mutableCopyWithZone: (NSZone *) zone { return [_items mutableCopyWithZone: zone]; }
- (Class) classForCoder { return [NSSet class]; }
@end
@interface NSNibArchiveDictionary : NSDictionary { NSMutableDictionary *_items; }
- (void) _put: (id) item key: (id) key;
@end
@implementation NSNibArchiveDictionary
- (id) init { if ((self = [super init])) _items = [NSMutableDictionary new]; return self; }
- (void) dealloc { [_items release]; [super dealloc]; }
- (NSUInteger) count { return [_items count]; }
- (id) objectForKey: (id) key { return [_items objectForKey: key]; }
- (NSEnumerator *) keyEnumerator { return [_items keyEnumerator]; }
- (void) _put: (id) item key: (id) key { [_items setObject: item forKey: key]; }
- (id) copyWithZone: (NSZone *) zone { return [self retain]; }
- (id) mutableCopyWithZone: (NSZone *) zone { return [_items mutableCopyWithZone: zone]; }
- (Class) classForCoder { return [NSDictionary class]; }
@end

@implementation NSNibArchiveUnarchiver

+ (BOOL) isNibArchiveData: (NSData *) data {
    return [data length] >= 10 && memcmp([data bytes], "NIBArchive", 10) == 0;
}

- (void) _recordFailure: (NSException *) exception {
    if (!_failed) NSLog(@"Unable to decode NIBArchive: %@", [exception reason]);
    _failed = YES;
}

- (id) initForReadingWithData: (NSData *) data {
    if (!(self = [super init])) return nil;
    @try {
        if (![[self class] isNibArchiveData: data] || [data length] > 128 * 1024 * 1024)
            NibInvalid(@"invalid magic or archive too large");
        _data = [data copy];
        _keys = [NSMutableArray new];
        _classes = [NSMutableArray new];
        _fallbacks = [NSMutableArray new];
        _storage = [NSMutableArray new];
        _owned = [NSMutableArray new];
        _classMap = [NSMutableDictionary new];
        _byteBuffers = [NSMutableDictionary new];
        NibReader r = {[data bytes], 10, [data length]};
        if (NibLE(&r, 4) != 1) NibInvalid(@"unsupported format version");
        _coderVersion = (unsigned)NibLE(&r, 4);
        uint32_t counts[4], offsets[4];
        for (unsigned i = 0; i < 4; i++) {
            counts[i] = (uint32_t)NibLE(&r, 4);
            offsets[i] = (uint32_t)NibLE(&r, 4);
        }
        // Resource ceilings also bound allocation on syntactically valid but
        // hostile count tables (normal compiled nibs are far smaller).
        if (counts[0] > 1000000 || counts[1] > 1000000 || counts[2] > 4000000 || counts[3] > 65536)
            NibInvalid(@"archive table resource limit exceeded");
        if (offsets[0] != 50 || counts[0] == 0) NibInvalid(@"missing root object");
        for (unsigned table = 0; table < 4; table++) {
            NSUInteger end = table == 3 ? [data length] : offsets[table + 1];
            if (offsets[table] > end || end > [data length] || counts[table] > end - offsets[table])
                NibInvalid(@"invalid table bounds");
            r.position = offsets[table]; r.end = end;
            if (table == 0) {
                _objectCount = counts[0];
                _objects = calloc(_objectCount, sizeof(*_objects));
                if (!_objects) NibInvalid(@"object allocation failed");
            } else if (table == 2) {
                _valueCount = counts[2];
                _values = calloc(MAX(_valueCount, 1), sizeof(*_values));
                if (!_values) NibInvalid(@"value allocation failed");
            }
            for (NSUInteger i = 0; i < counts[table]; i++) {
                if (table == 0) {
                    _objects[i].classIndex = NibVarint(&r);
                    _objects[i].first = NibVarint(&r);
                    _objects[i].count = NibVarint(&r);
                    if (_objects[i].classIndex >= counts[3] || _objects[i].first > counts[2] ||
                        _objects[i].count > counts[2] - _objects[i].first)
                        NibInvalid(@"invalid object range");
                } else if (table == 1) {
                    uint32_t length = NibVarint(&r);
                    [_keys addObject: NibString(&r, length)];
                } else if (table == 2) {
                    NSNibArchiveValue *v = &_values[i];
                    v->key = NibVarint(&r);
                    if (v->key >= counts[1]) NibInvalid(@"invalid key index");
                    v->type = *NibTake(&r, 1);
                    switch (v->type) {
                        case 0: v->scalar = [NSNumber numberWithChar: (int8_t)NibLE(&r, 1)]; break;
                        case 1: v->scalar = [NSNumber numberWithShort: (int16_t)NibLE(&r, 2)]; break;
                        case 2: v->scalar = [NSNumber numberWithInt: (int32_t)NibLE(&r, 4)]; break;
                        case 3: v->scalar = [NSNumber numberWithLongLong: (int64_t)NibLE(&r, 8)]; break;
                        case 4: case 5: v->scalar = [NSNumber numberWithBool: v->type == 5]; break;
                        case 6: {
                            uint32_t bits = (uint32_t)NibLE(&r, 4); float f;
                            memcpy(&f, &bits, sizeof(f));
                            v->scalar = [NSNumber numberWithFloat: f]; break;
                        }
                        case 7: {
                            uint64_t bits = NibLE(&r, 8); double d;
                            memcpy(&d, &bits, sizeof(d));
                            v->scalar = [NSNumber numberWithDouble: d]; break;
                        }
                        case 8: {
                            uint32_t length = NibVarint(&r);
                            v->scalar = [NSData dataWithBytes: NibTake(&r, length) length: length]; break;
                        }
                        case 9: break;
                        case 10:
                            v->reference = (uint32_t)NibLE(&r, 4);
                            if (v->reference >= counts[0]) NibInvalid(@"invalid object reference");
                            break;
                        default: NibInvalid(@"unknown value type");
                    }
                    if (v->scalar) [_storage addObject: v->scalar];
                } else {
                    uint32_t length = NibVarint(&r), count = NibVarint(&r);
                    if (count > (r.end - r.position) / 4) NibInvalid(@"invalid fallback count");
                    NSMutableArray *fallback = [NSMutableArray array];
                    for (uint32_t j = 0; j < count; j++) {
                        uint32_t index = (uint32_t)NibLE(&r, 4);
                        if (index >= counts[3]) NibInvalid(@"invalid fallback class index");
                        [fallback addObject: [NSNumber numberWithUnsignedInt: index]];
                    }
                    if (!length) NibInvalid(@"empty class name");
                    NSString *name = NibString(&r, length - 1);
                    if (*NibTake(&r, 1) || ![name length]) NibInvalid(@"invalid class name terminator");
                    [_classes addObject: name]; [_fallbacks addObject: fallback];
                }
            }
            if (r.position != r.end) NibInvalid(@"unexpected trailing table bytes");
        }
    } @catch (NSException *exception) {
        [self _recordFailure: exception];
        [self release]; return nil;
    }
    return self;
}

- (void) dealloc {
    [_data release]; [_keys release]; [_classes release]; [_fallbacks release];
    [_storage release]; [_owned release]; [_classMap release]; [_byteBuffers release];
    free(_objects); free(_values);
    [super dealloc];
}
- (BOOL) allowsKeyedCoding { return YES; }
- (BOOL) requiresSecureCoding { return NO; }
- (unsigned) systemVersion { return _coderVersion; }
- (NSInteger) versionForClassName: (NSString *) name { return 0; }
- (void) setDelegate: (id) delegate { _delegate = delegate; }
- (id) delegate { return _delegate; }
- (BOOL) failed { return _failed; }
- (void) finishDecoding { }
- (void) setClass: (Class) aClass forClassName: (NSString *) name {
    if (aClass) [_classMap setObject: aClass forKey: name];
    else [_classMap removeObjectForKey: name];
}
- (Class) classForClassName: (NSString *) name {
    Class cls = [_classMap objectForKey: name];
    return cls ? cls : NSClassFromString(name);
}
- (NSNibArchiveValue *) _valueForKey: (NSString *) key {
    if (_failed || !key) return NULL;
    NSNibArchiveObject *o = &_objects[_current];
    for (NSUInteger i = o->first; i < o->first + o->count; i++)
        if ([[_keys objectAtIndex: _values[i].key] isEqual: key]) return &_values[i];
    return NULL; // duplicate keys deliberately return the first entry
}
- (BOOL) containsValueForKey: (NSString *) key { return [self _valueForKey: key] != NULL; }

- (void) replaceObject: (id) object withObject: (id) replacement {
    if (!object || object == replacement) return;
    if (replacement) [_owned addObject: replacement];
    for (NSUInteger i = 0; i < _objectCount; i++)
        if (_objects[i].object == object) _objects[i].object = replacement;
    if ([_delegate respondsToSelector: @selector(unarchiver:willReplaceObject:withObject:)])
        [_delegate unarchiver: (id)self willReplaceObject: object withObject: replacement];
}

- (id) _objectAtIndex: (NSUInteger) index {
    NSNibArchiveObject *o = &_objects[index];
    if (o->started) return o->object;
    if (_depth >= 256) NibInvalid(@"object nesting limit exceeded");
    Class cls = [self classForClassName: [_classes objectAtIndex: o->classIndex]];
    if (!cls) {
        for (NSNumber *fallback in [_fallbacks objectAtIndex: o->classIndex]) {
            cls = [self classForClassName: [_classes objectAtIndex: [fallback unsignedIntegerValue]]];
            if (cls) break;
        }
    }
    if (!cls) NibInvalid([NSString stringWithFormat: @"class %@ is unavailable", [_classes objectAtIndex: o->classIndex]]);
    cls = [cls classForKeyedUnarchiver];
    if (!cls) NibInvalid(@"classForKeyedUnarchiver returned Nil");
    NSUInteger previous = _current;
    _current = index;
    _depth++;
    id initialized = nil;
    @try {
        BOOL array = cls == [NSArray class] || cls == [NSMutableArray class];
        BOOL set = cls == [NSSet class] || cls == [NSMutableSet class];
        BOOL dict = cls == [NSDictionary class] || cls == [NSMutableDictionary class];
        o->started = YES;
        if ((array || set || dict) && [self decodeBoolForKey: @"NSInlinedValue"]) {
            // Stable, initialized storage is needed before following collection cycles.
            Class storage = cls == [NSArray class] ? [NSNibArchiveArray class] :
                    cls == [NSSet class] ? [NSNibArchiveSet class] :
                    cls == [NSDictionary class] ? [NSNibArchiveDictionary class] : cls;
            initialized = [storage new];
            o->object = initialized;
            [_owned addObject: initialized]; [initialized release];
            id pendingKey = nil;
            for (NSUInteger i = o->first; i < o->first + o->count; i++) {
                if (![[_keys objectAtIndex: _values[i].key] isEqual: @"UINibEncoderEmptyKey"]) continue;
                id item = [self _decodeValue: &_values[i]];
                if (!item) NibInvalid(@"nil inline collection element");
                if (dict) {
                    if (!pendingKey) pendingKey = item;
                    else {
                        if (cls == [NSDictionary class]) [initialized _put: item key: pendingKey];
                        else [initialized setObject: item forKey: pendingKey];
                        pendingKey = nil;
                    }
                } else if (cls == [NSArray class] || cls == [NSSet class]) [initialized _append: item];
                else [initialized addObject: item];
            }
            if (pendingKey) NibInvalid(@"odd inline dictionary element count");
            initialized = [initialized retain];
        } else {
            o->object = [cls allocWithZone: [self objectZone]];
            if (cls == [NSObject class]) initialized = [o->object init];
            else {
                if (![o->object respondsToSelector: @selector(initWithCoder:)])
                    NibInvalid([NSString stringWithFormat: @"%@ does not implement initWithCoder:", NSStringFromClass(cls)]);
                initialized = [o->object initWithCoder: self];
            }
        }
        if (!initialized) NibInvalid([NSString stringWithFormat: @"%@ -initWithCoder: returned nil", NSStringFromClass(cls)]);
        initialized = [initialized awakeAfterUsingCoder: self];
        id result = initialized;
        if ([_delegate respondsToSelector: @selector(unarchiver:didDecodeObject:)])
            result = [_delegate unarchiver: (id)self didDecodeObject: result];
        if (result) [_owned addObject: result];
        o->object = result;
        [initialized release];
        return result;
    } @finally {
        _current = previous;
        _depth--;
    }
}
- (id) _decodeValue: (NSNibArchiveValue *) value {
    if (!value || value->type == 9) return nil;
    return value->type == 10 ? [self _objectAtIndex: value->reference] : value->scalar;
}
- (id) decodeObjectForKey: (NSString *) key {
    if (_failed) return nil;
    @try { return [self _decodeValue: [self _valueForKey: key]]; }
    @catch (NSException *exception) {
        if (_depth) @throw;
        [self _recordFailure: exception]; return nil;
    }
}
- (id) _decodePropertyListForKey: (NSString *) key { return [self decodeObjectForKey: key]; }
- (id) decodePropertyListForKey: (NSString *) key { return [self decodeObjectForKey: key]; }
- (NSArray *) _decodeArrayOfObjectsForKey: (NSString *) key { return [self decodeObjectForKey: key]; }

- (NSNumber *) _numberForKey: (NSString *) key {
    NSNibArchiveValue *v = [self _valueForKey: key];
    if (!v) return nil;
    if (v->type <= 7) return v->scalar;
    NSException *e = [NSException exceptionWithName: NSInvalidUnarchiveOperationException
            reason: @"non-numeric value for scalar key" userInfo: nil];
    if (_depth) @throw e;
    [self _recordFailure: e]; return nil;
}
- (BOOL) decodeBoolForKey: (NSString *) key { return [[self _numberForKey: key] boolValue]; }
- (int) decodeIntForKey: (NSString *) key { return [[self _numberForKey: key] intValue]; }
- (int32_t) decodeInt32ForKey: (NSString *) key { return [[self _numberForKey: key] intValue]; }
- (int64_t) decodeInt64ForKey: (NSString *) key { return [[self _numberForKey: key] longLongValue]; }
- (NSInteger) decodeIntegerForKey: (NSString *) key { return [[self _numberForKey: key] integerValue]; }
- (float) decodeFloatForKey: (NSString *) key { return [[self _numberForKey: key] floatValue]; }
- (double) decodeDoubleForKey: (NSString *) key { return [[self _numberForKey: key] doubleValue]; }
- (const uint8_t *) decodeBytesForKey: (NSString *) key returnedLength: (NSUInteger *) length {
    if (length) *length = 0;
    NSNibArchiveValue *v = [self _valueForKey: key];
    if (!v) return NULL;
    if (v->type != 8) {
        NSException *e = [NSException exceptionWithName: NSInvalidUnarchiveOperationException
                reason: @"non-data value for bytes key" userInfo: nil];
        if (_depth) @throw e;
        [self _recordFailure: e]; return NULL;
    }
    // A spare NUL also bounds legacy AppKit readers that parse ASCII color components.
    NSNumber *index = [NSNumber numberWithUnsignedInteger: v - _values];
    NSMutableData *buffer = [_byteBuffers objectForKey: index];
    if (!buffer) {
        buffer = [NSMutableData dataWithData: v->scalar];
        uint8_t zero = 0; [buffer appendBytes: &zero length: 1];
        [_byteBuffers setObject: buffer forKey: index];
    }
    if (length) *length = [v->scalar length];
    return [buffer bytes];
}
// OSXER NIB (geometry): the keyed string representation, with the same
// failure boundary as scalar/object decoding when called directly by clients.
- (NSString *) _geometryStringForKey: (NSString *) key {
    id string = [self decodeObjectForKey: key];
    if (string && ![string isKindOfClass: [NSString class]]) NibInvalid(@"non-string geometry value");
    return string;
}
- (NSPoint) decodePointForKey: (NSString *) key {
    @try {
        NSString *s = [self _geometryStringForKey: key];
        return s ? NSPointFromString(s) : NSZeroPoint;
    } @catch (NSException *e) {
        if (_depth) @throw;
        [self _recordFailure: e]; return NSZeroPoint;
    }
}
- (NSSize) decodeSizeForKey: (NSString *) key {
    @try {
        NSString *s = [self _geometryStringForKey: key];
        return s ? NSSizeFromString(s) : NSZeroSize;
    } @catch (NSException *e) {
        if (_depth) @throw;
        [self _recordFailure: e]; return NSZeroSize;
    }
}
- (NSRect) decodeRectForKey: (NSString *) key {
    @try {
        NSString *s = [self _geometryStringForKey: key];
        return s ? NSRectFromString(s) : NSZeroRect;
    } @catch (NSException *e) {
        if (_depth) @throw;
        [self _recordFailure: e]; return NSZeroRect;
    }
}
@end
