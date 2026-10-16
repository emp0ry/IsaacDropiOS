#import "ISDNativeInput.h"
#import "ISDHost.h"
#import <UIKit/UIKit.h>

@interface ISDZone : UIControl
@property(nonatomic, strong) ISDNativeInput *input;
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
- (void)down { [self.input press]; }
- (void)up { [self.input releasePress]; }
- (void)cancel { [self.input cancel]; }
@end

@interface ISDController : NSObject
@property(nonatomic, strong) ISDNativeInput *input;
@property(nonatomic, strong) ISDZone *zone;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) BOOL loggedStartup;
@end
@implementation ISDController
- (void)tick {
    CADisplayLink *link = nil;
    UIWindow *window = ISDReadyWindow(&link);
    if (!window) {
        self.zone.hidden = YES; [self.input cancel]; return;
    }
    if (!self.input) self.input = [ISDNativeInput new];
    if (!self.input.supported) { self.zone.hidden = YES; return; }
    if (![self.input installWithDisplayLink:link]) {
        self.zone.hidden = YES; [self.input cancel]; return;
    }
    if (!self.zone) {
        self.zone = [[ISDZone alloc] initWithFrame:CGRectZero];
        self.zone.input = self.input;
    }
    if (self.zone.superview != window) {
        [self.input cancel];
        [self.zone removeFromSuperview];
        [window addSubview:self.zone];
    }
    CGRect bounds = window.bounds;
    self.zone.frame = CGRectMake(CGRectGetMinX(bounds),CGRectGetMaxY(bounds)-64,72,64);
    BOOL available = [self.input gameplayAvailable] &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        !window.rootViewController.presentedViewController;
    self.zone.hidden = !available;
    self.zone.userInteractionEnabled = available;
    [self.input setAvailable:available];
    // Existing full-screen overlays return nil outside their controls. Do not
    // reorder them: settings/console dialogs must keep their established input.
    if (!self.loggedStartup) {
        self.loggedStartup = YES;
        ISDLog(@"IsaacDrop 0.1.1 ready; invisible bottom-left zone 72x64 points; independent of EID");
    }
}
- (void)suspend { self.zone.hidden = YES; [self.input cancel]; }
- (void)start {
    self.timer = [NSTimer timerWithTimeInterval:.1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(suspend)
        name:UIApplicationWillResignActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(suspend)
        name:UIApplicationDidEnterBackgroundNotification object:nil];
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
