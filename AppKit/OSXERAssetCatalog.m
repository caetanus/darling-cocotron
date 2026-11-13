/* OSXER APPKIT (asset catalogs): images from compiled asset catalogs (Assets.car).

   Xcode compiles an app's image assets into Contents/Resources/Assets.car, which macOS reads
   through the private CoreUI framework; Darling had no reader, so +[NSImage imageNamed:]
   found none of an app's own images. This reads the format directly:

   - the BOMStore container (big-endian) with its named blocks and B+ trees;
   - KEYFORMAT (which attribute each rendition-key slot holds), FACETKEYS (image name ->
     identifier, attribute 17), APPEARANCEKEYS, RENDITIONS (key -> CSI record);
   - CSI records (little-endian): CELM bitmaps (uncompressed, zip, LZFSE, LZFSE in KCBC
     chunks, Deepmap2), RAWD data (PNG, JPEG, PDF...), and internal links into packed atlases
     (crop rectangle with a lower-left origin).

   Format knowledge and the Deepmap2 decoder follow carfile-go by devcxm (MIT License,
   github.com/devcxm/carfile-go, docs/assets-car-format.md and codec/deepmap2), ported to C.
   Not decoded yet: RLE, palette and legacy deepmap bitmaps, JPEG-LZFSE, ASTC, HEVC, SVG,
   named colours and gradients; such images stay missing, as before. */

#import <AppKit/NSImage.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSAppearance.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <compression.h>
#include <zlib.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

extern size_t __darling_lzvn_decode_buffer(uint8_t *dst, size_t dst_size, const uint8_t *src, size_t src_size);

#pragma mark - Byte helpers

static uint32_t BE32(const uint8_t *p) { return ((uint32_t) p[0] << 24) | ((uint32_t) p[1] << 16) | ((uint32_t) p[2] << 8) | p[3]; }
static uint16_t BE16(const uint8_t *p) { return (uint16_t) ((p[0] << 8) | p[1]); }
static uint32_t LE32(const uint8_t *p) { return (uint32_t) p[0] | ((uint32_t) p[1] << 8) | ((uint32_t) p[2] << 16) | ((uint32_t) p[3] << 24); }
static uint16_t LE16(const uint8_t *p) { return (uint16_t) (p[0] | (p[1] << 8)); }
static uint64_t LE64(const uint8_t *p) { return (uint64_t) LE32(p) | ((uint64_t) LE32(p + 4) << 32); }

#pragma mark - Pixel buffers

typedef struct {
    uint8_t *bytes;   // tightly packed rows
    size_t width, height, bytesPerPixel; // 4: BGRA premultiplied, 2: gray + alpha
} OSXERPixels;

static void OSXERPixelsFree(OSXERPixels *p) { free(p->bytes); p->bytes = NULL; }

// Keeps the first tightRow bytes of every source row (decoders pad rows to an alignment).
static BOOL OSXERStripRows(OSXERPixels *out, const uint8_t *src, size_t srcBytes, size_t width, size_t height, size_t bpp) {
    size_t tight = width * bpp;
    if (!width || !height || srcBytes < tight * height) return NO;
    size_t sourceRow = srcBytes == tight * height ? tight : srcBytes / height;
    if (sourceRow < tight) return NO;
    out->bytes = malloc(tight * height);
    if (!out->bytes) return NO;
    for (size_t row = 0; row < height; row++) memcpy(out->bytes + row * tight, src + row * sourceRow, tight);
    out->width = width; out->height = height; out->bytesPerPixel = bpp;
    return YES;
}

// LZFSE ("bvx" blocks) into a fresh buffer of at most limit bytes; returns the size.
static uint8_t *OSXERLZFSE(const uint8_t *src, size_t srcBytes, size_t limit, size_t *outBytes) {
    uint8_t *dst = malloc(limit ? limit : 1);
    if (!dst) return NULL;
    size_t n = compression_decode_buffer(dst, limit, src, srcBytes, NULL, COMPRESSION_LZFSE);
    if (n == 0) { free(dst); return NULL; }
    *outBytes = n;
    return dst;
}

// zlib or gzip (auto-detected header) into a fresh buffer of at most limit bytes.
static uint8_t *OSXERInflate(const uint8_t *src, size_t srcBytes, size_t limit, size_t *outBytes) {
    uint8_t *dst = malloc(limit ? limit : 1);
    if (!dst) return NULL;
    z_stream z;
    memset(&z, 0, sizeof z);
    if (inflateInit2(&z, 15 + 32) != Z_OK) { free(dst); return NULL; }
    z.next_in = (Bytef *) src; z.avail_in = (uInt) srcBytes;
    z.next_out = dst; z.avail_out = (uInt) limit;
    int status = inflate(&z, Z_FINISH);
    size_t n = limit - z.avail_out;
    inflateEnd(&z);
    if (status != Z_STREAM_END && !(status == Z_BUF_ERROR && z.avail_out == 0)) { free(dst); return NULL; }
    *outBytes = n;
    return dst;
}

typedef uint8_t *(*OSXERDecompress)(const uint8_t *, size_t, size_t, size_t *);

// Generous bound for padded rows: CoreUI aligns rows to at most 64 bytes.
static size_t OSXERPaddedBound(size_t width, size_t height, size_t bpp) {
    return height * (width * bpp + 64) + 4096;
}

static BOOL OSXERDecodeKCBC(OSXERPixels *out, const uint8_t *src, size_t srcBytes, size_t width, size_t height, size_t bpp, OSXERDecompress decompress) {
    size_t tight = width * bpp, offset = 0, rows = 0;
    uint8_t *dst = malloc(tight * height);
    if (!dst) return NO;
    while (rows < height) {
        if (srcBytes - offset < 20 || memcmp(src + offset, "KCBC", 4) != 0) goto fail;
        size_t chunkRows = LE32(src + offset + 12), length = LE32(src + offset + 16);
        if (!chunkRows || chunkRows > height - rows || length > srcBytes - offset - 20) goto fail;
        size_t got = 0;
        uint8_t *decoded = decompress(src + offset + 20, length, OSXERPaddedBound(width, chunkRows, bpp), &got);
        if (!decoded) goto fail;
        size_t sourceRow = got / chunkRows;
        if (got % chunkRows || sourceRow < tight) { free(decoded); goto fail; }
        for (size_t r = 0; r < chunkRows; r++) memcpy(dst + (rows + r) * tight, decoded + r * sourceRow, tight);
        free(decoded);
        rows += chunkRows;
        offset += 20 + length;
    }
    out->bytes = dst; out->width = width; out->height = height; out->bytesPerPixel = bpp;
    return YES;
fail:
    free(dst);
    return NO;
}

#pragma mark - Deepmap2 (port of carfile-go codec/deepmap2, MIT)

typedef struct { int components, bytesPerComponent; BOOL hasAlpha; } OSXERDmpLayout;

static BOOL OSXERDmpLayoutFor(uint8_t format, OSXERDmpLayout *layout) {
    switch (format) {
    case 1: *layout = (OSXERDmpLayout) {1, 1, NO}; return YES;
    case 2: *layout = (OSXERDmpLayout) {2, 1, YES}; return YES;
    case 3: *layout = (OSXERDmpLayout) {3, 1, NO}; return YES;
    case 4: *layout = (OSXERDmpLayout) {4, 1, YES}; return YES;
    default: return NO; // 20 (wide RGBW) is not used for images AppKit draws here
    }
}

static BOOL OSXERIsLZFSEBlock(const uint8_t *p, size_t n) {
    return n >= 4 && p[0] == 'b' && p[1] == 'v' && p[2] == 'x' && (p[3] == '2' || p[3] == '-' || p[3] == 'n' || p[3] == '1');
}

// One compressed segment: LZFSE when it has a block header, else raw LZVN of expected bytes.
static uint8_t *OSXERDmpSegment(const uint8_t *src, size_t n, size_t expected, size_t *outBytes) {
    if (OSXERIsLZFSEBlock(src, n)) return OSXERLZFSE(src, n, expected * 2 + 65536, outBytes);
    if (!expected) return NULL;
    uint8_t *dst = malloc(expected);
    if (!dst) return NULL;
    *outBytes = __darling_lzvn_decode_buffer(dst, expected, src, n);
    if (!*outBytes) { free(dst); return NULL; }
    return dst;
}

static void OSXERUnpredictRow(int16_t *row, const int16_t *previous, size_t count, uint8_t predictor) {
    switch (predictor) {
    case 1:
        for (int c = 0; c < 3; c++) row[c] = (int16_t) (row[c] + previous[c]);
        for (size_t i = 3; i < count; i += 3) {
            int leftY = row[i - 3], upY = previous[i], upLeftY = previous[i - 3];
            const int16_t *predict = abs(upY - upLeftY) > abs(leftY - upLeftY) ? previous + i : row + i - 3;
            for (int c = 0; c < 3; c++) row[i + c] = (int16_t) (row[i + c] + predict[c]);
        }
        break;
    case 2:
        for (size_t i = 3; i < count; i++) row[i] = (int16_t) (row[i] + row[i - 3]);
        break;
    case 3:
        for (size_t i = 0; i < count; i++) row[i] = (int16_t) (row[i] + previous[i]);
        break;
    case 4:
        for (int c = 0; c < 3; c++) row[c] = (int16_t) (row[c] + previous[c]);
        for (size_t i = 3; i < count; i++) {
            int32_t sum = (int32_t) row[i - 3] + (int32_t) previous[i] + 1;
            if (sum < 0) sum++;
            row[i] = (int16_t) (row[i] + (int16_t) (sum >> 1));
        }
        break;
    default:
        break;
    }
}

// The "default" method: alpha plane, one predictor byte per row, then two byte planes of
// sign-folded residuals (high bytes first) in YCoCg-R for colour.
static uint8_t *OSXERDmpDefaultPixels(const uint8_t *src, size_t srcBytes, size_t width, size_t height, OSXERDmpLayout layout) {
    size_t pixels = width * height;
    int residual = layout.components - (layout.hasAlpha ? 1 : 0);
    size_t alphaBytes = layout.hasAlpha ? pixels : 0;
    size_t needed = alphaBytes + height + 2 * (size_t) residual * pixels;
    if (srcBytes < needed || srcBytes - needed >= 16) return NULL;
    const uint8_t *alpha = src, *predictors = src + alphaBytes;
    const uint8_t *firstPlane = predictors + height, *secondPlane = firstPlane + residual * pixels;
    size_t bpp = layout.components * layout.bytesPerComponent;
    uint8_t *out = calloc(pixels, bpp);
    int16_t *previous = calloc(width * 3, sizeof(int16_t)), *current = calloc(width * 3, sizeof(int16_t));
    if (!out || !previous || !current) { free(out); free(previous); free(current); return NULL; }
    for (size_t row = 0; row < height; row++) {
        memset(current, 0, width * 3 * sizeof(int16_t));
        for (size_t column = 0; column < width; column++)
            for (int c = 0; c < residual; c++) {
                size_t index = (row * width + column) * residual + c;
                uint16_t encoded = (uint16_t) (secondPlane[index] | (firstPlane[index] << 8));
                int16_t value = (int16_t) (encoded >> 1);
                current[column * 3 + c] = (encoded & 1) ? (int16_t) -value : value;
            }
        OSXERUnpredictRow(current, previous, width * 3, predictors[row]);
        for (size_t column = 0; column < width; column++) {
            int16_t *s = current + column * 3;
            uint8_t *d = out + (row * width + column) * bpp;
            if (residual == 1) {
                d[0] = (uint8_t) s[0];
                if (layout.hasAlpha) d[1] = alpha[row * width + column];
                continue;
            }
            int16_t y = s[0], co = (int16_t) ((uint16_t) s[1] << 1), cg = (int16_t) ((uint16_t) s[2] << 1);
            int16_t t = (int16_t) (y - cg / 2);
            int16_t green = (int16_t) (t + cg);
            int16_t blue = (int16_t) (t - co / 2);
            int16_t red = (int16_t) (blue + co);
            d[0] = (uint8_t) red; d[1] = (uint8_t) green; d[2] = (uint8_t) blue; // CoreUI byte order
            if (layout.hasAlpha) d[3] = alpha[row * width + column];
        }
        int16_t *swap = previous; previous = current; current = swap;
    }
    free(previous); free(current);
    return out;
}

static BOOL OSXERDecodeDeepmap2(OSXERPixels *out, const uint8_t *src, size_t n);

static BOOL OSXERDecodeDeepmap2KCBC(OSXERPixels *out, const uint8_t *src, size_t n) {
    size_t offset = 0, width = 0, height = 0, bpp = 0, capacity = 0;
    uint8_t *pixels = NULL;
    while (offset < n) {
        if (n - offset < 20 || memcmp(src + offset, "KCBC", 4) != 0) goto fail;
        size_t length = LE32(src + offset + 16);
        if (length > n - offset - 20) goto fail;
        OSXERPixels part = {0};
        if (!OSXERDecodeDeepmap2(&part, src + offset + 20, length)) goto fail;
        if (!pixels) { width = part.width; bpp = part.bytesPerPixel; }
        else if (part.width != width || part.bytesPerPixel != bpp) { OSXERPixelsFree(&part); goto fail; }
        size_t add = part.width * part.height * bpp;
        uint8_t *grown = realloc(pixels, capacity + add);
        if (!grown) { OSXERPixelsFree(&part); goto fail; }
        pixels = grown;
        memcpy(pixels + capacity, part.bytes, add);
        capacity += add; height += part.height;
        OSXERPixelsFree(&part);
        offset += 20 + length;
    }
    if (!pixels) return NO;
    out->bytes = pixels; out->width = width; out->height = height; out->bytesPerPixel = bpp;
    return YES;
fail:
    free(pixels);
    return NO;
}

static BOOL OSXERDecodeDeepmap2(OSXERPixels *out, const uint8_t *src, size_t n) {
    if (n >= 4 && memcmp(src, "KCBC", 4) == 0) return OSXERDecodeDeepmap2KCBC(out, src, n);
    if (n < 28 || LE32(src) != 1) return NO;
    uint64_t outerLength = LE64(src + 8);
    if (outerLength > n - 16) return NO;
    size_t end = 16 + (size_t) outerLength;
    if (end < 28 || memcmp(src + 16, "dmp2", 4) != 0 || src[21] != 1) return NO;
    uint8_t method = src[20];
    OSXERDmpLayout layout;
    if (!OSXERDmpLayoutFor(src[23], &layout)) return NO;
    size_t width = LE16(src + 24), height = LE16(src + 26);
    size_t bpp = layout.components * layout.bytesPerComponent;
    if (!width || !height) return NO;
    size_t pixelBytes = width * height * bpp;

    if (method == 1) { // raw
        if (end - 28 != pixelBytes) return NO;
        return OSXERStripRows(out, src + 28, pixelBytes, width, height, bpp);
    }
    if (end < 32) return NO;
    uint32_t descriptor = LE32(src + 28);
    const uint8_t *payload = src + 32;
    size_t remaining = end - 32;

    if (method == 2 || method == 3) { // default (predictive) or lossless, in segments
        uint8_t *all = NULL;
        size_t allBytes = 0, rows = 0;
        size_t length = descriptor;
        int residual = layout.components - (layout.hasAlpha ? 1 : 0);
        size_t defaultRow = (layout.hasAlpha ? width : 0) + 1 + 2 * (size_t) residual * width;
        for (;;) {
            if (!length || length > remaining) { free(all); return NO; }
            size_t expected = method == 2 ? ((defaultRow * height + 15) & ~(size_t) 15) : pixelBytes - allBytes;
            size_t got = 0;
            uint8_t *decoded = OSXERDmpSegment(payload, length, expected, &got);
            if (!decoded) { free(all); return NO; }
            uint8_t *segmentPixels = decoded;
            size_t segmentRows;
            if (method == 2) {
                segmentRows = got / defaultRow;
                if (!segmentRows || got - segmentRows * defaultRow >= 16) { free(decoded); free(all); return NO; }
                segmentPixels = OSXERDmpDefaultPixels(decoded, got, width, segmentRows, layout);
                free(decoded);
                if (!segmentPixels) { free(all); return NO; }
                got = segmentRows * width * bpp;
            } else {
                segmentRows = got / (width * bpp);
            }
            uint8_t *grown = realloc(all, allBytes + got);
            if (!grown) { free(segmentPixels); free(all); return NO; }
            all = grown;
            memcpy(all + allBytes, segmentPixels, got);
            allBytes += got; rows += segmentRows;
            free(segmentPixels);
            payload += length; remaining -= length;
            if (!remaining) break;
            if (remaining < 4) { free(all); return NO; }
            length = LE32(payload); payload += 4; remaining -= 4;
        }
        if (allBytes != rows * width * bpp || !rows) { free(all); return NO; }
        out->bytes = all; out->width = width; out->height = rows; out->bytesPerPixel = bpp;
        return YES;
    }

    if (method == 4) { // palette
        size_t count = descriptor & 0xffff, paletteComponents = descriptor >> 16;
        if (!count || count > 256 || !paletteComponents || (int) paletteComponents > layout.components) return NO;
        size_t paletteBytes = count * bpp;
        if (paletteBytes + 4 > remaining) return NO;
        size_t encoded = LE32(payload + paletteBytes);
        if (encoded > remaining - paletteBytes - 4) return NO;
        size_t pixels = width * height;
        size_t separate = layout.components - paletteComponents;
        size_t planeBytes = pixels * separate * layout.bytesPerComponent;
        size_t decodedBytes = planeBytes + pixels;
        size_t got = 0;
        uint8_t *planes = OSXERDmpSegment(payload + paletteBytes + 4, encoded, decodedBytes, &got);
        if (!planes || got != decodedBytes) { free(planes); return NO; }
        uint8_t *dst = malloc(pixels * bpp);
        if (!dst) { free(planes); return NO; }
        const uint8_t *indices = planes + planeBytes;
        for (size_t i = 0; i < pixels; i++) {
            if (indices[i] >= count) { free(planes); free(dst); return NO; }
            memcpy(dst + i * bpp, payload + indices[i] * bpp, bpp);
            for (size_t c = 0; c < separate; c++) {
                size_t from = c * pixels * layout.bytesPerComponent + i * layout.bytesPerComponent;
                size_t to = i * bpp + (paletteComponents + c) * layout.bytesPerComponent;
                memcpy(dst + to, planes + from, layout.bytesPerComponent);
            }
        }
        free(planes);
        out->bytes = dst; out->width = width; out->height = height; out->bytesPerPixel = bpp;
        return YES;
    }
    return NO;
}

#pragma mark - Images

static void OSXERReleasePixels(void *info, const void *data, size_t size) { free((void *) data); }

// A bitmap rep from CoreUI pixels: BGRA premultiplied (ARGB) or gray + alpha (GA8), which is
// expanded to BGRA. Takes ownership of the pixels.
static NSBitmapImageRep *OSXERRepFromPixels(OSXERPixels *p, CGFloat scale) {
    size_t count = p->width * p->height;
    uint8_t *bgra = p->bytes;
    if (p->bytesPerPixel == 2) {
        bgra = malloc(count * 4);
        if (!bgra) { OSXERPixelsFree(p); return nil; }
        for (size_t i = 0; i < count; i++) {
            uint8_t gray = p->bytes[i * 2], alpha = p->bytes[i * 2 + 1];
            bgra[i * 4 + 0] = gray; bgra[i * 4 + 1] = gray; bgra[i * 4 + 2] = gray; bgra[i * 4 + 3] = alpha;
        }
        OSXERPixelsFree(p);
    } else if (p->bytesPerPixel != 4) {
        OSXERPixelsFree(p);
        return nil;
    }
    p->bytes = NULL;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, bgra, count * 4, OSXERReleasePixels);
    CGImageRef image = CGImageCreate(p->width, p->height, 8, 32, p->width * 4, space,
                                     kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little,
                                     provider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(space);
    if (!image) return nil;
    NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithCGImage: image] autorelease];
    CGImageRelease(image);
    [rep setSize: NSMakeSize(p->width / scale, p->height / scale)];
    return rep;
}

#pragma mark - The catalog

typedef struct { uint16_t type, value; } OSXERKeyToken;

@interface OSXERAssetCatalog : NSObject {
@public
    NSData *_data;
    const uint8_t *_bytes;
    size_t _length;
    NSArray *_blocks;            // NSValue(NSRange) per block id
    NSMutableDictionary *_vars;  // name -> block id
    uint32_t *_keyFormat;        // attribute type per key slot
    size_t _keyCount;
    NSMutableDictionary *_facets;      // name -> identifier (NSNumber)
    NSMutableDictionary *_renditions;  // identifier -> NSArray of NSData (key ++ csi offsets)
    NSMutableArray *_allRenditions;    // NSData: key bytes, then the CSI block's NSRange
    uint16_t _darkAppearance;
}
+ (OSXERAssetCatalog *) catalogForBundle: (NSBundle *) bundle;
- (NSImage *) imageNamed: (NSString *) name;
@end

@implementation OSXERAssetCatalog

static BOOL OSXERBlock(OSXERAssetCatalog *self, uint32_t index, const uint8_t **bytes, size_t *length) {
    if (index >= [self->_blocks count]) return NO;
    NSRange r = [[self->_blocks objectAtIndex: index] rangeValue];
    if (r.location == 0xffffffff || NSMaxRange(r) > self->_length) return NO;
    *bytes = self->_bytes + r.location; *length = r.length;
    return YES;
}

// Calls visit(key, keyLength, value, valueLength) for every leaf entry of a named tree.
- (BOOL) _walkTree: (NSString *) name visit: (void (^)(const uint8_t *, size_t, const uint8_t *, size_t)) visit {
    NSNumber *treeBlock = [_vars objectForKey: name];
    const uint8_t *tree; size_t treeLength;
    if (!treeBlock || !OSXERBlock(self, [treeBlock unsignedIntValue], &tree, &treeLength) ||
        treeLength < 21 || memcmp(tree, "tree", 4) != 0) return NO;
    uint32_t child = BE32(tree + 8);
    const uint8_t *node; size_t nodeLength;
    for (int depth = 0; depth < 64; depth++) {
        if (!OSXERBlock(self, child, &node, &nodeLength) || nodeLength < 12) return NO;
        if (BE16(node)) break;
        if (nodeLength < 16) return NO;
        child = BE32(node + 12);
    }
    for (int guard = 0; guard < 1000000 && child; guard++) {
        if (!OSXERBlock(self, child, &node, &nodeLength) || nodeLength < 12) return NO;
        uint16_t count = BE16(node + 2);
        if (12 + 8 * (size_t) count > nodeLength) return NO;
        for (uint16_t i = 0; i < count; i++) {
            const uint8_t *key, *value; size_t keyLength, valueLength;
            if (OSXERBlock(self, BE32(node + 12 + 8 * i + 4), &key, &keyLength) &&
                OSXERBlock(self, BE32(node + 12 + 8 * i), &value, &valueLength))
                visit(key, keyLength, value, valueLength);
        }
        child = BE32(node + 4);
    }
    return YES;
}

- (instancetype) initWithPath: (NSString *) path {
    if (!(self = [super init])) return nil;
    _data = [[NSData alloc] initWithContentsOfFile: path];
    _bytes = [_data bytes]; _length = [_data length];
    if (_length < 32 || memcmp(_bytes, "BOMStore", 8) != 0) { [self release]; return nil; }
    uint32_t indexOffset = BE32(_bytes + 16), varsOffset = BE32(_bytes + 24);
    if ((uint64_t) indexOffset + 4 > _length || (uint64_t) varsOffset + 4 > _length) { [self release]; return nil; }
    uint32_t count = BE32(_bytes + indexOffset);
    if ((uint64_t) indexOffset + 4 + 8ull * count > _length) { [self release]; return nil; }
    NSMutableArray *blocks = [NSMutableArray arrayWithCapacity: count];
    for (uint32_t i = 0; i < count; i++) {
        const uint8_t *e = _bytes + indexOffset + 4 + 8 * i;
        [blocks addObject: [NSValue valueWithRange: NSMakeRange(BE32(e), BE32(e + 4))]];
    }
    _blocks = [blocks retain];
    _vars = [NSMutableDictionary new];
    uint32_t vars = BE32(_bytes + varsOffset);
    size_t p = varsOffset + 4;
    for (uint32_t i = 0; i < vars && p + 5 <= _length; i++) {
        uint32_t block = BE32(_bytes + p);
        uint8_t nameLength = _bytes[p + 4];
        if (p + 5 + nameLength > _length) break;
        NSString *name = [[[NSString alloc] initWithBytes: _bytes + p + 5 length: nameLength encoding: NSUTF8StringEncoding] autorelease];
        if (name) [_vars setObject: @(block) forKey: name];
        p += 5 + nameLength;
    }

    // KEYFORMAT: 'kfmt' tag, version, count, then the attribute types (little-endian).
    const uint8_t *kf; size_t kfLength;
    NSNumber *kfBlock = [_vars objectForKey: @"KEYFORMAT"];
    if (!kfBlock || !OSXERBlock(self, [kfBlock unsignedIntValue], &kf, &kfLength) || kfLength < 12) { [self release]; return nil; }
    _keyCount = LE32(kf + 8);
    if (12 + 4 * _keyCount > kfLength) { [self release]; return nil; }
    _keyFormat = calloc(_keyCount ? _keyCount : 1, sizeof(uint32_t));
    for (size_t i = 0; i < _keyCount; i++) _keyFormat[i] = LE32(kf + 12 + 4 * i);

    // FACETKEYS: name -> hot spot (4 bytes), count, (type, value) pairs; 17 is the identifier.
    _facets = [NSMutableDictionary new];
    [self _walkTree: @"FACETKEYS" visit: ^(const uint8_t *key, size_t keyLength, const uint8_t *value, size_t valueLength) {
        if (valueLength < 6) return;
        NSString *name = [[[NSString alloc] initWithBytes: key length: keyLength encoding: NSUTF8StringEncoding] autorelease];
        uint16_t pairs = LE16(value + 4);
        for (uint16_t i = 0; i < pairs && 6 + 4 * (size_t) (i + 1) <= valueLength; i++)
            if (LE16(value + 6 + 4 * i) == 17 && name)
                [_facets setObject: @(LE16(value + 8 + 4 * i)) forKey: name];
    }];

    // APPEARANCEKEYS: appearance name -> id; renditions for the dark one are skipped.
    _darkAppearance = 0xffff;
    [self _walkTree: @"APPEARANCEKEYS" visit: ^(const uint8_t *key, size_t keyLength, const uint8_t *value, size_t valueLength) {
        NSString *name = [[[NSString alloc] initWithBytes: key length: keyLength encoding: NSUTF8StringEncoding] autorelease];
        if (valueLength >= 2 && [name rangeOfString: @"Dark"].location != NSNotFound) _darkAppearance = LE16(value);
    }];

    // RENDITIONS: key (one uint16 per KEYFORMAT slot) -> CSI record.
    _renditions = [NSMutableDictionary new];
    _allRenditions = [NSMutableArray new];
    [self _walkTree: @"RENDITIONS" visit: ^(const uint8_t *key, size_t keyLength, const uint8_t *value, size_t valueLength) {
        if (keyLength < 2 * _keyCount || valueLength < 184) return;
        NSMutableData *entry = [NSMutableData dataWithBytes: key length: 2 * _keyCount];
        NSRange csi = NSMakeRange(value - _bytes, valueLength);
        [entry appendBytes: &csi length: sizeof csi];
        [_allRenditions addObject: entry];
        uint16_t identifier = 0;
        for (size_t i = 0; i < _keyCount; i++) if (_keyFormat[i] == 17) identifier = LE16(key + 2 * i);
        NSMutableArray *list = [_renditions objectForKey: @(identifier)];
        if (!list) { list = [NSMutableArray array]; [_renditions setObject: list forKey: @(identifier)]; }
        [list addObject: entry];
    }];
    return self;
}

- (void) dealloc {
    [_data release]; [_blocks release]; [_vars release]; [_facets release];
    [_renditions release]; [_allRenditions release];
    free(_keyFormat);
    [super dealloc];
}

static uint16_t OSXERKeyValue(OSXERAssetCatalog *self, NSData *entry, uint32_t attribute) {
    const uint8_t *key = [entry bytes];
    for (size_t i = 0; i < self->_keyCount; i++) if (self->_keyFormat[i] == attribute) return LE16(key + 2 * i);
    return 0;
}

static NSRange OSXERCSIRange(OSXERAssetCatalog *self, NSData *entry) {
    NSRange r;
    memcpy(&r, (const uint8_t *) [entry bytes] + 2 * self->_keyCount, sizeof r);
    return r;
}

// Decodes a rendition's bitmap (following an internal link into a packed atlas).
- (BOOL) _pixels: (OSXERPixels *) out forCSI: (NSRange) range scale: (CGFloat *) scale depth: (int) depth {
    if (depth > 2 || NSMaxRange(range) > _length || range.length < 184) return NO;
    const uint8_t *csi = _bytes + range.location;
    if (memcmp(csi, "ISTC", 4) != 0) return NO;
    size_t width = LE32(csi + 12), height = LE32(csi + 16);
    *scale = LE32(csi + 20) ? LE32(csi + 20) / 100.0 : 1;
    uint32_t format = LE32(csi + 24);
    size_t tlvLength = LE32(csi + 168), bitmapCount = LE32(csi + 172);
    size_t tlvStart = 180 + 4 * bitmapCount;
    if (tlvStart + tlvLength > range.length) return NO;
    const uint8_t *tlv = csi + tlvStart, *payload = tlv + tlvLength;
    size_t payloadLength = range.length - tlvStart - tlvLength;

    // Internal link (TLV 1010): crop of another rendition (a packed atlas).
    for (size_t p = 0; p + 8 <= tlvLength;) {
        uint32_t type = LE32(tlv + p), length = LE32(tlv + p + 4);
        if (length > tlvLength - p - 8) break;
        if (type == 1010 && length >= 30) {
            const uint8_t *v = tlv + p + 8;
            size_t cropX = LE32(v + 8), cropY = LE32(v + 12), cropW = LE32(v + 16), cropH = LE32(v + 20);
            size_t tokens = LE32(v + 26) / 4;
            if (30 + tokens * 4 > length) return NO;
            for (NSData *candidate in _allRenditions) {
                BOOL match = YES;
                for (size_t t = 0; t < tokens && match; t++)
                    if (OSXERKeyValue(self, candidate, LE16(v + 30 + 4 * t)) != LE16(v + 32 + 4 * t)) match = NO;
                if (!match) continue;
                OSXERPixels atlas = {0};
                CGFloat atlasScale = 1;
                if (![self _pixels: &atlas forCSI: OSXERCSIRange(self, candidate) scale: &atlasScale depth: depth + 1]) return NO;
                if (cropX + cropW > atlas.width || cropY + cropH > atlas.height) { OSXERPixelsFree(&atlas); return NO; }
                size_t bpp = atlas.bytesPerPixel, top = atlas.height - cropY - cropH; // lower-left origin
                uint8_t *dst = malloc(cropW * cropH * bpp);
                if (!dst) { OSXERPixelsFree(&atlas); return NO; }
                for (size_t r = 0; r < cropH; r++)
                    memcpy(dst + r * cropW * bpp, atlas.bytes + ((top + r) * atlas.width + cropX) * bpp, cropW * bpp);
                OSXERPixelsFree(&atlas);
                out->bytes = dst; out->width = cropW; out->height = cropH; out->bytesPerPixel = bpp;
                return YES;
            }
            return NO;
        }
        p += 8 + length;
    }

    if (payloadLength < 16 || memcmp(payload, "MLEC", 4) != 0) return NO;
    size_t bpp = format == 'ARGB' ? 4 : format == 'GA8 ' ? 2 : 0;
    if (!bpp || !width || !height) return NO;
    uint32_t compression = LE32(payload + 8);
    const uint8_t *data = payload + 16;
    size_t dataLength = payloadLength - 16;
    BOOL chunked = dataLength >= 4 && memcmp(data, "KCBC", 4) == 0;
    size_t got = 0;
    uint8_t *raw;
    BOOL ok;
    switch (compression) {
    case 0:
        return OSXERStripRows(out, data, dataLength, width, height, bpp);
    case 2:
        if (chunked) return OSXERDecodeKCBC(out, data, dataLength, width, height, bpp, OSXERInflate);
        raw = OSXERInflate(data, dataLength, OSXERPaddedBound(width, height, bpp), &got);
        ok = raw && OSXERStripRows(out, raw, got, width, height, bpp);
        free(raw);
        return ok;
    case 4:
        if (chunked) return OSXERDecodeKCBC(out, data, dataLength, width, height, bpp, OSXERLZFSE);
        raw = OSXERLZFSE(data, dataLength, OSXERPaddedBound(width, height, bpp), &got);
        ok = raw && OSXERStripRows(out, raw, got, width, height, bpp);
        free(raw);
        return ok;
    case 11:
        if (!OSXERDecodeDeepmap2(out, data, dataLength)) return NO;
        if (out->width != width || out->height != height || out->bytesPerPixel != bpp) { OSXERPixelsFree(out); return NO; }
        return YES;
    default:
        return NO;
    }
}

- (NSImageRep *) _repForCSI: (NSRange) range {
    const uint8_t *csi = _bytes + range.location;
    size_t tlvLength = LE32(csi + 168), bitmapCount = LE32(csi + 172);
    size_t start = 180 + 4 * bitmapCount + tlvLength;
    if (start + 12 <= range.length && memcmp(csi + start, "DWAR", 4) == 0) {
        size_t length = LE32(csi + start + 8);
        if (start + 12 + length > range.length) return nil;
        NSData *data = [NSData dataWithBytes: csi + start + 12 length: length];
        NSImage *image = [[[NSImage alloc] initWithData: data] autorelease];
        NSArray *reps = [image representations];
        return [reps count] ? [reps objectAtIndex: 0] : nil;
    }
    OSXERPixels pixels = {0};
    CGFloat scale = 1;
    if (![self _pixels: &pixels forCSI: range scale: &scale depth: 0]) return nil;
    return OSXERRepFromPixels(&pixels, scale);
}

// One representation per scale, preferring the light (or any) appearance, sRGB and the
// universal or Mac idiom.
- (NSImage *) imageNamed: (NSString *) name {
    NSNumber *identifier = [_facets objectForKey: name];
    if (!identifier) return nil;
    NSMutableDictionary *best = [NSMutableDictionary dictionary]; // scale -> entry
    NSMutableDictionary *bestScore = [NSMutableDictionary dictionary];
    for (NSData *entry in [_renditions objectForKey: identifier]) {
        NSRange csi = OSXERCSIRange(self, entry);
        uint16_t appearance = OSXERKeyValue(self, entry, 7);
        if (appearance && appearance == _darkAppearance) continue;
        uint16_t scaleKey = OSXERKeyValue(self, entry, 12);
        int score = (OSXERKeyValue(self, entry, 24) == 0 ? 4 : 0) + (appearance == 0 ? 2 : 0) +
                    (OSXERKeyValue(self, entry, 15) <= 1 ? 1 : 0);
        NSNumber *key = @(scaleKey ? scaleKey : LE32(_bytes + csi.location + 20) / 100);
        if (![bestScore objectForKey: key] || [[bestScore objectForKey: key] intValue] < score) {
            [best setObject: entry forKey: key];
            [bestScore setObject: @(score) forKey: key];
        }
    }
    NSImage *image = nil;
    for (NSNumber *scale in [[best allKeys] sortedArrayUsingSelector: @selector(compare:)]) {
        NSImageRep *rep = [self _repForCSI: OSXERCSIRange(self, [best objectForKey: scale])];
        if (!rep) continue;
        if (!image) image = [[[NSImage alloc] initWithSize: [rep size]] autorelease];
        [image addRepresentation: rep];
    }
    return image;
}

+ (OSXERAssetCatalog *) catalogForBundle: (NSBundle *) bundle {
    static NSMutableDictionary *catalogs;
    @synchronized (self) {
        if (!catalogs) catalogs = [NSMutableDictionary new];
        NSString *key = [bundle bundlePath];
        if (!key) return nil;
        id catalog = [catalogs objectForKey: key];
        if (!catalog) {
            NSString *path = [bundle pathForResource: @"Assets" ofType: @"car"];
            catalog = path ? [[[OSXERAssetCatalog alloc] initWithPath: path] autorelease] : nil;
            [catalogs setObject: catalog ? catalog : [NSNull null] forKey: key];
        }
        return catalog == [NSNull null] ? nil : catalog;
    }
}

@end

// Used by +[NSImage imageNamed:] after the bundle's image files.
NSImage *OSXERAssetCatalogImage(NSBundle *bundle, NSString *name) {
    return [[OSXERAssetCatalog catalogForBundle: bundle] imageNamed: name];
}
