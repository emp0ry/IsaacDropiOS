#import "ISDNativeInput.h"
#import "ISDHost.h"
#import "ISDRestartKey.h"
#import "ISDFullscreen.h"
#import "IESKeyboard.h"
#import "IESInputContext.h"
#import <UIKit/UIKit.h>

@interface ISDZone : UIControl
@property(nonatomic, strong) ISDNativeInput *input;
@property(nonatomic) BOOL restart;
@end
@implementation ISDZone
- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    // Alpha zero/hidden would disable UIKit hit testing. Clear drawing keeps
    // the active zone invisible while still receiving its own touch.
    self.alpha = 1;
    self.exclusiveTouch = NO;
    self.accessibilityLabel = @"Drop (Ctrl)";
    self.accessibilityHint = @"Tap to switch; hold to drop pocket items and trinkets";
    self.isAccessibilityElement = YES;
    [self addTarget:self action:@selector(down) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(up) forControlEvents:UIControlEventTouchUpInside];
    [self addTarget:self action:@selector(cancel) forControlEvents:
        UIControlEventTouchCancel|UIControlEventTouchUpOutside|UIControlEventTouchDragExit];
    return self;
}
- (void)down { if (self.restart) [self.input restartDown:1]; else [self.input press]; }
- (void)up { if (self.restart) [self.input restartUp:1]; else [self.input releasePress]; }
- (void)cancel { if (self.restart) [self.input restartUp:1]; else [self.input cancel]; }
@end

static BOOL EditingText(UIView *view) {
    return IESHasTextInput(view,NSClassFromString(@"AAPLOpenGLView"),
        @protocol(UIKeyInput),@protocol(UITextInput));
}

@interface ISDController : NSObject
@property(nonatomic, strong) ISDNativeInput *input;
@property(nonatomic, strong) ISDZone *zone;
@property(nonatomic, strong) ISDZone *restartZone;
@property(nonatomic, strong) ISDRestartKey *restartKey;
@property(nonatomic, strong) IESKeyboard *enterKey;
@property(nonatomic, strong) ISDFullscreen *fullscreen;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) BOOL loggedStartup;
@end
@implementation ISDController
- (void)tick {
    CADisplayLink *link = nil;
    UIWindow *window = ISDReadyWindow(&link);
    if (!window) {
        self.zone.hidden = YES;
        UIWindow *previousWindow = self.restartZone.window;
        if (previousWindow && [self.input restartTransitionPending] &&
            !previousWindow.hidden && !previousWindow.rootViewController.presentedViewController &&
            !EditingText(previousWindow) && [self.input restartContextAvailable]) {
            // Keep an existing touch captured through our own native load.
            // Hiding/disabling its UIControl here would cancel the held finger.
            [self.input setAvailable:NO];
            [self.input pollRestart];
        } else {
            self.restartZone.hidden = YES; [self.input cancel];
        }
        return;
    }
    if (!self.input) self.input = [ISDNativeInput new];
    if (!self.input.supported) { self.zone.hidden = YES; self.restartZone.hidden = YES; return; }
    if (![self.input installWithDisplayLink:link]) {
        self.zone.hidden = YES; self.restartZone.hidden = YES; [self.input cancel]; return;
    }
    if (!self.zone) {
        self.zone = [[ISDZone alloc] initWithFrame:CGRectZero];
        self.zone.input = self.input;
        self.restartZone = [[ISDZone alloc] initWithFrame:CGRectZero];
        self.restartZone.input = self.input;
        self.restartZone.restart = YES;
        self.restartZone.accessibilityLabel = @"Restart (R)";
        self.restartZone.accessibilityHint = @"Hold to restart every second; release to stop";
    }
    if (self.zone.superview != window) {
        [self.input cancel];
        [self.zone removeFromSuperview];
        [window addSubview:self.zone];
        [self.restartZone removeFromSuperview];
        [window addSubview:self.restartZone];
    }
    CGRect bounds = window.bounds;
    self.zone.frame = CGRectMake(CGRectGetMinX(bounds),CGRectGetMaxY(bounds)-64,72,64);
    self.restartZone.frame = CGRectMake(CGRectGetMidX(bounds)-36,CGRectGetMinY(bounds),72,64);
    BOOL available = [self.input gameplayAvailable] &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        !window.rootViewController.presentedViewController;
    self.zone.hidden = !available;
    self.zone.userInteractionEnabled = available;
    [self.input setAvailable:available];
    BOOL restartAvailable = UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        !window.rootViewController.presentedViewController && !EditingText(window) &&
        ([self.input restartAvailable] ||
            ([self.input restartTransitionPending] && [self.input restartContextAvailable]));
    self.restartZone.hidden = !restartAvailable;
    self.restartZone.userInteractionEnabled = restartAvailable;
    if (restartAvailable) [self.input pollRestart]; else [self.input cancelRestart];
    // Existing full-screen overlays return nil outside their controls. Do not
    // reorder them: settings/console dialogs must keep their established input.
    if (!self.loggedStartup) {
        self.loggedStartup = YES;
        ISDLog(@"IsaacFixes 0.2.0 ready; Drop, R restart, Esc pause, Enter/Space, F fullscreen");
    }
}
- (BOOL)keyboardAvailable {
    UIWindow *window = ISDReadyWindow(NULL);
    return window && !window.hidden && !window.rootViewController.presentedViewController && !EditingText(window);
}
- (void)suspend {
    self.zone.hidden = YES; self.restartZone.hidden = YES;
    [self.input cancel]; [self.enterKey suspend];
}
- (void)start {
    __weak ISDController *weakSelf = self;
    self.fullscreen = [[ISDFullscreen alloc] initWithCanToggle:^BOOL {
        ISDController *target = weakSelf;
        UIWindow *window = ISDReadyWindow(NULL);
        return target && window.isKeyWindow && [target keyboardAvailable];
    }];
    if (NSClassFromString(@"NSApplication")) {
        self.enterKey = [[IESKeyboard alloc] initWithCanMap:^BOOL { return [weakSelf keyboardAvailable]; }];
        ISDLog(@"native Enter/Space alias %@",[self.enterKey start] ? @"installed" : @"rejected");
    }
    self.restartKey = [[ISDRestartKey alloc] initWithHandler:^BOOL(BOOL down) {
        ISDController *target = weakSelf;
        if (!down) { [target.input restartUp:2]; return YES; }
        if (!target || !target.restartZone || target.restartZone.hidden ||
            EditingText(target.restartZone.window)) return NO;
        return [target.input restartDown:2];
    } escapeHandler:^BOOL {
        ISDController *target = weakSelf;
        UIWindow *window = target.zone.window;
        if (!target || !window || window.hidden || window.rootViewController.presentedViewController ||
            EditingText(window)) return NO;
        return [target.input togglePause];
    } fullscreenHandler:^BOOL { return [weakSelf.fullscreen toggle]; }];
    [self.restartKey start];
    self.timer = [NSTimer timerWithTimeInterval:.05 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(suspend)
        name:UIApplicationWillResignActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(suspend)
        name:UIApplicationDidEnterBackgroundNotification object:nil];
    if (self.enterKey) {
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        for (NSString *name in @[@"NSApplicationWillResignActiveNotification",@"NSWindowDidResignKeyNotification"])
            [center addObserver:self.enterKey selector:@selector(suspend) name:name object:nil];
        for (NSString *name in @[UITextFieldTextDidBeginEditingNotification,UITextViewTextDidBeginEditingNotification])
            [center addObserver:self.enterKey selector:@selector(cancelMapping) name:name object:nil];
    }
}
@end

static ISDController *Controller;
__attribute__((constructor)) static void StartIsaacDrop(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            Controller = [ISDController new];
            [Controller start];
        });
    }
}
