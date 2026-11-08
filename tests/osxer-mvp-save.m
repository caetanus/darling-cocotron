// OSXER MVP (regressions): run only through osxer-mvp-save.sh in Darling.
// Contracts: NSApplicationDelegate opening, NSDocument saving,
// NSAttributedString dataFromRange:/RTFFromRange:, NSSavePanel directoryURL.
// RTF syntax: Microsoft's RTF specification (escaped delimiters, signed UTF-16).
#import <AppKit/AppKit.h>
#import <CoreServices/CoreServices.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/resource.h>

static void expect(BOOL value, const char *message) {
    if (!value) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
}
static NSString *testString(void) { return @"ASCII {braces}; \\ ação\t日本語 😀\nsecond line"; }
static NSDictionary *rtfAttributes(void) { return @{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType}; }
static NSArray *opened;
static NSUInteger untitledRequests;
static volatile NSUInteger stackFrames;
__attribute__((noinline)) static void stackRecursion(unsigned depth) {
    volatile unsigned char frame[32768];
    for (NSUInteger i = 0; i < sizeof(frame); i += 4096) frame[i] = depth;
    if (depth) stackRecursion(depth - 1);
    for (NSUInteger i = 0; i < sizeof(frame); i += 4096)
        expect(frame[i] == (unsigned char)depth, "Mach-O stack survives deep recursion");
    stackFrames++;
}
static void stackTest(void) {
    size_t size = pthread_get_stacksize_np(pthread_self());
    uintptr_t top = (uintptr_t)pthread_get_stackaddr_np(pthread_self());
    uintptr_t here = (uintptr_t)&size;
    expect(size >= 8 * 1024 * 1024, "default main stack exposes at least 8 MiB");
    expect(here < top && here >= top - size, "pthread reports the real main stack bounds");
    stackRecursion(160);
    expect(stackFrames == 161, "Mach-O main thread used more than 5 MiB");
}

@interface OSXERMVPDocument : NSDocument { NSAttributedString *_text; }
@end
@implementation OSXERMVPDocument
- (id)init {
    if ((self = [super init])) _text = [[NSAttributedString alloc] initWithString:testString()];
    return self;
}
- (void)dealloc { [_text release]; [super dealloc]; }
- (void)makeWindowControllers {}
- (void)showWindows {}
- (BOOL)readFromData:(NSData *)data ofType:(NSString *)type error:(NSError **)error {
    expect([type isEqual:@"public.rtf"], "opening receives the declared UTI, not its display name");
    NSAttributedString *text = [[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL];
    if (!text) return NO;
    [_text release]; _text = text;
    return YES;
}
- (NSData *)dataOfType:(NSString *)type error:(NSError **)error {
    expect([type isEqual:@"public.rtf"], "saving receives the declared UTI, not its display name");
    return [_text dataFromRange:NSMakeRange(0, [_text length]) documentAttributes:rtfAttributes() error:error];
}
@end

@interface SingleDelegate : NSObject <NSApplicationDelegate>
@end
@implementation SingleDelegate
- (BOOL)application:(NSApplication *)app openFile:(NSString *)path {
    opened = [[(opened ?: @[]) arrayByAddingObject:path] retain];
    return NO; // Failure must not silently become an untitled launch.
}
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)app { untitledRequests++; return YES; }
@end
@interface MultiDelegate : SingleDelegate
@end
@implementation MultiDelegate
- (void)application:(NSApplication *)app openFiles:(NSArray *)files { opened = [files copy]; }
- (BOOL)application:(NSApplication *)app openFile:(NSString *)path {
    expect(NO, "plural delegate takes precedence"); return NO;
}
@end

static void launchTest(NSString *mode) {
    NSApplication *app = [NSApplication sharedApplication];
    id delegate = nil;
    if ([mode isEqual:@"single"]) delegate = [[SingleDelegate alloc] init];
    if ([mode isEqual:@"multi"]) delegate = [[MultiDelegate alloc] init];
    [app setDelegate:delegate];
    [app finishLaunching];
    NSArray *documents = [[NSDocumentController sharedDocumentController] documents];
    if (delegate) {
        NSString *expected = [[[NSProcessInfo processInfo] environment] objectForKey:@"OSXER_MVP_EXPECT"];
        expect([opened isEqual:[expected componentsSeparatedByString:@"\n"]], "delegate receives only document arguments");
        expect(untitledRequests == 0 && [documents count] == 0, "explicit request suppresses untitled even on failure");
    } else if ([mode isEqual:@"empty"]) {
        expect([documents count] == 1 && [[documents firstObject] fileURL] == nil, "no file creates one untitled document");
    } else {
        expect([documents count] == 1 && [[documents firstObject] fileURL] != nil, "controller opens launch file");
        NSData *data = [[documents firstObject] dataOfType:@"public.rtf" error:NULL];
        expect([data length] > 0, "opened document remains writable");
        if ([mode isEqual:@"ls-child"]) {
            NSString *path = [[[[documents firstObject] fileURL] path] stringByAppendingString:@".opened"];
            expect([@"opened" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL], "LS completion marker");
        }
    }
    NSUInteger count = [documents count];
    [app finishLaunching];
    expect([[[NSDocumentController sharedDocumentController] documents] count] == count, "launch is delivered once");
    [app setDelegate:nil]; [delegate release];
}

static void rtfTests(NSString *directory) {
    NSDocumentController *controller = [NSDocumentController sharedDocumentController];
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    expect([[controller defaultType] isEqual:@"public.rtf"], "UTI-only declaration supplies default type");
    expect([[workspace preferredFilenameExtensionForType:@"public.rtf"] isEqual:@"rtf"], "workspace uses LS extension registry");
    expect([workspace filenameExtension:@"RTF" isValidForType:@"public.rtf"], "workspace validates uppercase extension");
    expect(UTTypeConformsTo(CFSTR("public.rtf"), CFSTR("public.rtf")) &&
           [workspace type:@"public.rtf" conformsToType:@"public.rtf"], "identity conformance at both layers");
    expect(UTTypeConformsTo(CFSTR("public.rtf"), CFSTR("public.data")) &&
           [workspace type:@"public.rtf" conformsToType:@"public.data"], "transitive conformance at both layers");
    expect(![workspace type:@"public.rtf" conformsToType:@"public.image"], "unrelated types do not conform");
    NSAttributedString *text = [[[NSAttributedString alloc] initWithString:testString()] autorelease];
    NSRange all = NSMakeRange(0, [text length]);
    NSError *error = nil;
    NSData *data = [text dataFromRange:all documentAttributes:rtfAttributes() error:&error];
    expect(data != nil && error == nil, "RTF data API works");
    expect([data isEqual:[text RTFFromRange:all documentAttributes:rtfAttributes()]], "RTF APIs share the writer");
    NSFileWrapper *wrapper = [text fileWrapperFromRange:all documentAttributes:rtfAttributes() error:&error];
    expect([[wrapper regularFileContents] isEqual:data], "file wrapper API shares data API");
    NSString *rtf = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
    expect([rtf containsString:@"\\{braces\\}"] && [rtf containsString:@"\\u-10179?\\u-8704?"], "RTF braces and signed surrogate units");
    NSAttributedString *roundtrip = [[[NSAttributedString alloc] initWithRTF:data documentAttributes:NULL] autorelease];
    expect([[roundtrip string] isEqual:testString()], "Unicode/escaping RTF round trip with NULL attributes");
    NSAttributedString *empty = [[[NSAttributedString alloc] initWithString:@""] autorelease];
    expect([[empty dataFromRange:NSMakeRange(0, 0) documentAttributes:rtfAttributes() error:NULL] length] > 0, "empty RTF is valid");
    NSAttributedString *longText = [[[NSAttributedString alloc] initWithString:[@"A" stringByPaddingToLength:1048576 withString:@"A" startingAtIndex:0]] autorelease];
    expect([[longText RTFFromRange:NSMakeRange(0, [longText length]) documentAttributes:rtfAttributes()] length] > 1048576, "large ASCII run uses bounded stack");
    expect([text dataFromRange:all documentAttributes:@{} error:&error] == nil && error != nil, "unsupported type reports error");
    expect([text dataFromRange:all documentAttributes:@{} error:NULL] == nil, "NULL error is allowed");
    BOOL threw = NO;
    @try { [text dataFromRange:NSMakeRange(NSUIntegerMax, 2) documentAttributes:rtfAttributes() error:NULL]; }
    @catch (NSException *exception) { threw = [[exception name] isEqual:NSRangeException]; }
    expect(threw, "overflowing range raises NSRangeException");

    OSXERMVPDocument *doc = [[[OSXERMVPDocument alloc] init] autorelease];
    NSURL *url = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"direct.rtf"]];
    [doc updateChangeCount:NSChangeDone];
    error = nil;
    expect([doc saveToURL:url ofType:@"public.rtf" forSaveOperation:NSSaveAsOperation error:&error], "document save traverses file wrapper and writer");
    expect(error == nil && [[doc fileURL] isEqual:url] && ![doc isDocumentEdited], "successful save updates document state");
    expect([[NSData dataWithContentsOfURL:url] isEqual:data], "saved bytes match RTF data");
    expect([[controller typeForContentsOfURL:url error:NULL] isEqual:@"public.rtf"], "content type lookup returns UTI");
    NSMutableAttributedString *loaded = [[[NSMutableAttributedString alloc] init] autorelease];
    expect([loaded readFromURL:url options:@{} documentAttributes:NULL error:NULL] &&
           [[loaded string] isEqual:testString()], "mutable attributed string reads saved RTF through URL API");
    NSURL *missing = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"absent/no.rtf"]];
    error = nil;
    expect(![doc saveToURL:missing ofType:@"public.rtf" forSaveOperation:NSSaveAsOperation error:&error] && error != nil, "save failure supplies filesystem error");
    expect([[doc fileURL] isEqual:url], "failed save preserves original URL");
    expect(![doc saveToURL:nil ofType:@"public.rtf" forSaveOperation:NSSaveAsOperation error:NULL], "nil URL is rejected");
}

@interface PanelDriver : NSObject { @public BOOL saved; NSUInteger ticks; }
- (void)tick:(NSTimer *)timer;
- (void)document:(NSDocument *)document didSave:(BOOL)success contextInfo:(void *)context;
@end
@implementation PanelDriver
- (void)tick:(NSTimer *)timer {
    if (++ticks > 1) { [NSApp abortModal]; expect(NO, "Return did not complete save panel"); }
    NSSavePanel *panel = (NSSavePanel *)[NSApp modalWindow];
    expect([panel isKindOfClass:[NSSavePanel class]], "document presents save panel");
    id editor = [panel firstResponder];
    expect([editor isKindOfClass:[NSTextView class]], "name field initially owns keyboard focus");
    [editor selectAll:nil];
    [editor insertText:@"return-save"];
    // The command generated by the Return key, through the live field editor.
    [editor doCommandBySelector:@selector(insertNewline:)];
}
- (void)document:(NSDocument *)document didSave:(BOOL)success contextInfo:(void *)context { saved = success; }
@end

static void panelTests(NSString *directory) {
    [NSApplication sharedApplication];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setVolatileDomain:@{@"NSNavLastRootDirectory": @""} forName:NSArgumentDomain];
    NSString *documents = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    expect([[[NSSavePanel savePanel] directoryURL].path isEqual:documents], "save panel defaults to Documents");
    expect([[[NSOpenPanel openPanel] directoryURL].path isEqual:documents], "open panel defaults to Documents");
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setDirectoryURL:nil];
    expect([[[openPanel directoryURL] path] isEqual:documents], "nil open directory preserves safe default");
    expect([[[NSDocumentController sharedDocumentController] currentDirectory] isEqual:documents], "document controller uses same default");
    [defaults setVolatileDomain:@{@"NSNavLastRootDirectory": NSHomeDirectory()} forName:NSArgumentDomain];
    expect([[[NSSavePanel savePanel] directory] isEqual:documents], "cached home is not an automatic default");
    [defaults setVolatileDomain:@{@"NSNavLastRootDirectory": directory} forName:NSArgumentDomain];
    expect([[[NSSavePanel savePanel] directory] isEqual:directory], "valid last folder is retained");
    OSXERMVPDocument *doc = [[[OSXERMVPDocument alloc] initWithType:@"public.rtf" error:NULL] autorelease];
    PanelDriver *driver = [[[PanelDriver alloc] init] autorelease];
    NSTimer *timer = [NSTimer timerWithTimeInterval:2 target:driver selector:@selector(tick:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
    [doc runModalSavePanelForSaveOperation:NSSaveAsOperation delegate:driver didSaveSelector:@selector(document:didSave:contextInfo:) contextInfo:NULL];
    [timer invalidate];
    expect(driver->saved, "name plus Return saves successfully");
    expect([[[doc fileURL] path] isEqual:[directory stringByAppendingPathComponent:@"return-save.rtf"]], "panel appends .rtf in selected folder");
    expect([[NSData dataWithContentsOfURL:[doc fileURL]] length] > 0, "Return wrote the RTF file");
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        NSDictionary *environment = [[NSProcessInfo processInfo] environment];
        NSString *mode = [environment objectForKey:@"OSXER_MVP_MODE"] ?: @"ls-child";
        NSString *directory = [environment objectForKey:@"OSXER_MVP_DIR"];
        if ([mode isEqual:@"stack"]) stackTest();
        else if ([mode isEqual:@"save"]) { rtfTests(directory); panelTests(directory); }
        else if ([mode isEqual:@"ls"] && argc == 3) {
            LSLaunchURLSpec spec = {0};
            spec.appURL = (CFURLRef)[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
            spec.itemURLs = (CFArrayRef)@[[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[2]]]];
            expect(LSOpenFromURLSpec(NULL, NULL) == paramErr, "null launch specification rejected");
            expect(LSOpenFromURLSpec(&spec, NULL) == noErr, "LaunchServices launches app with document");
        } else launchTest([mode isEqual:@"ls"] ? @"ls-child" : mode);
        puts("PASS: MVP regression mode");
    }
    return 0;
}
