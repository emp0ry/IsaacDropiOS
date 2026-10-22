#import "ISDFullscreen.h"
#include <assert.h>
@interface NSWindow : NSObject
@property(nonatomic, strong) id attachedSheet;
@property(nonatomic) int calls;
@property(nonatomic) BOOL fullscreen;
@end
@implementation NSWindow
- (void)toggleFullScreen:(id)sender {
    (void)sender; self.calls++;
    NSString *name = self.fullscreen ? @"NSWindowWillExitFullScreenNotification" : @"NSWindowWillEnterFullScreenNotification";
    [NSNotificationCenter.defaultCenter postNotificationName:name object:self];
}
@end
@interface NSApplication : NSObject
@property(nonatomic) BOOL isActive;
@property(nonatomic, strong) NSWindow *keyWindow;
@end
@implementation NSApplication
+ (id)sharedApplication { static id app; if (!app) app = [self new]; return app; }
@end
static void Complete(NSWindow *window, BOOL fullscreen) {
    window.fullscreen = fullscreen;
    [NSNotificationCenter.defaultCenter postNotificationName:fullscreen ?
        @"NSWindowDidEnterFullScreenNotification" : @"NSWindowDidExitFullScreenNotification" object:window];
}
int main(void) {
    @autoreleasepool {
        __block BOOL allowed = YES;
        ISDFullscreen *fix = [[ISDFullscreen alloc] initWithCanToggle:^BOOL { return allowed; }];
        NSApplication *app = [NSApplication sharedApplication];
        NSWindow *window = [NSWindow new]; app.keyWindow = window;
        assert(![fix toggle] && window.calls == 0);
        app.isActive = YES; allowed = NO; assert(![fix toggle]);
        allowed = YES; window.attachedSheet = [NSObject new]; assert(![fix toggle]); window.attachedSheet = nil;
        assert([fix toggle] && window.calls == 1);
        assert([fix toggle] && window.calls == 1); // Don't queue toggles mid-animation.
        Complete(window,YES);
        assert([fix toggle] && window.calls == 2); Complete(window,NO);
        [NSNotificationCenter.defaultCenter postNotificationName:@"NSWindowWillEnterFullScreenNotification" object:window];
        assert([fix toggle] && window.calls == 2); Complete(window,YES);
        assert([fix toggle] && window.calls == 3);
        // AppKit has delegate failure callbacks, but no public failure
        // notification. Exercise the bounded watchdog without a real wait.
        [[fix valueForKey:@"transitionTimer"] fire];
        assert([fix toggle] && window.calls == 4); Complete(window,NO);
        assert([fix toggle] && window.calls == 5);
        [NSNotificationCenter.defaultCenter postNotificationName:@"NSWindowWillCloseNotification" object:window];
        assert([fix valueForKey:@"transitionTimer"] == nil);
        app.keyWindow = nil; assert(![fix toggle]);
        puts("Fullscreen checks passed: native enter/exit, focus, text/modal gate, transition guard, failure recovery");
    }
    return 0;
}
