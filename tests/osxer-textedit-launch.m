// OSXER TEXTEDIT (regression): generic declared-UTI document creation.
// Contract: LSItemContentTypes supplies the programmatic document type.
// https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/DocBasedAppProgrammingGuideForOSX/ApplicationCreationProcess/ApplicationCreationProcess.html
// OSXER LOG (regression): opt-in mirrors, newline/UTF-8 formatting and flushing.
#import <AppKit/AppKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFLogUtilities.h>
#import <os/log.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void expect(BOOL condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

@interface OSXERUTIDocument : NSDocument {
@public
    BOOL madeControllers;
    BOOL showedWindows;
}
@end
@implementation OSXERUTIDocument
- (void)makeWindowControllers { madeControllers = YES; }
- (void)showWindows { showedWindows = YES; }
@end

@interface OSXERUTIController : NSDocumentController
@end
@implementation OSXERUTIController
- (NSString *)defaultType { return @"org.osxer.test.rich"; }
@end

static void documentTests(void) {
    OSXERUTIController *controller = [[OSXERUTIController alloc] init];
    expect([controller documentClassForType:@"org.osxer.test.rich"] == [OSXERUTIDocument class], "declared UTI resolves");
    expect([controller documentClassForType:@"org.osxer.test.alias"] == [OSXERUTIDocument class], "second UTI in array resolves");
    expect([controller documentClassForType:@"Legacy Document"] == [OSXERUTIDocument class], "legacy bundle type resolves");
    expect([controller documentClassForType:@"org.osxer.test.unknown"] == Nil, "unknown type returns Nil");
    expect([controller documentClassForType:nil] == Nil, "nil type returns Nil");
    expect([controller documentClassForType:@"org.osxer.test.missing-class"] == Nil, "unavailable class returns Nil");
    expect([[controller displayNameForType:@"org.osxer.test.alias"] isEqual:@"Rich Document"], "UTI display name uses same declaration");
    expect([[controller fileExtensionsFromType:@"org.osxer.test.rich"] containsObject:@"osxerrich"], "UTI extensions use same declaration");
    NSError *error = nil;
    OSXERUTIDocument *document = [controller openUntitledDocumentAndDisplay:YES error:&error];
    expect(document != nil && error == nil, "untitled document created from UTI default");
    expect([[document fileType] isEqual:@"org.osxer.test.rich"], "UTI reaches document initialization");
    expect(document->madeControllers && document->showedWindows, "creation reaches window callbacks");
    expect([[controller documents] containsObject:document], "created document registered");
    [controller removeDocument:document];
    document = [controller openUntitledDocumentAndDisplay:NO error:NULL];
    expect(document != nil && document->madeControllers && !document->showedWindows, "display:NO does not show windows");
    [controller removeDocument:document];
    [controller release];
}

static void logTests(BOOL immediateExit) {
    // Full buffering and _exit detect missing fflush, even for redirected stderr.
    static char stderrBuffer[16384];
    setvbuf(stderr, stderrBuffer, _IOFBF, sizeof(stderrBuffer));
    NSLog(@"OSXER-NS-ONE %@ %d", @"ação", 17);
    NSLog(@"OSXER-NS-NL\n");
    CFLog(kCFLogLevelWarning, CFSTR("OSXER-CF-ONE %@ %d"), CFSTR("ação"), 23);
    CFLog(kCFLogLevelWarning, CFSTR("OSXER-CF-NL\n"));
    NSLog(@"");
    CFLog(kCFLogLevelWarning, CFSTR(""));
    os_log(OS_LOG_DEFAULT, "OSXER-OS-ONE");
    if (immediateExit) _exit(0);
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc == 2 && strcmp(argv[1], "logs") == 0) {
            logTests(YES);
        } else if (argc == 2 && strcmp(argv[1], "logs-normal-exit") == 0) {
            logTests(NO);
        } else if (argc == 2 && strcmp(argv[1], "exception") == 0) {
            NSApplication *application = [NSApplication sharedApplication];
            @try {
                [NSException raise:@"OSXERException" format:@"OSXER exception reason"];
            } @catch (NSException *exception) {
                [application reportException:exception];
            }
            _exit(0);
        } else {
            documentTests();
        }
    }
    return 0;
}
