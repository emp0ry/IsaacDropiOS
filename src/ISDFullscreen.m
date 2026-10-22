#import "ISDFullscreen.h"

// Public AppKit API, resolved only inside PlayCover. No AppKit dependency in
// the iPhone build, and no synthesized system-wide keyboard event.
@protocol ISDFullscreenWindow <NSObject>
@property(nonatomic, readonly) id attachedSheet;
- (void)toggleFullScreen:(id)sender;
@end
@protocol ISDFullscreenApplication <NSObject>
+ (id)sharedApplication;
@property(nonatomic, readonly) BOOL isActive;
@property(nonatomic, readonly) id<ISDFullscreenWindow> keyWindow;
@end
@interface ISDFullscreen ()
@property(nonatomic, copy) BOOL (^canToggle)(void);
@property(nonatomic, strong) id transitionWindow;
@property(nonatomic, strong) NSTimer *transitionTimer;
@end
@implementation ISDFullscreen
- (instancetype)initWithCanToggle:(BOOL (^)(void))canToggle {
    if (!(self = [super init])) return nil;
    _canToggle = [canToggle copy];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSString *name in @[@"NSWindowWillEnterFullScreenNotification",@"NSWindowWillExitFullScreenNotification"])
        [center addObserver:self selector:@selector(willChange:) name:name object:nil];
    for (NSString *name in @[@"NSWindowDidEnterFullScreenNotification",@"NSWindowDidExitFullScreenNotification",
        @"NSWindowWillCloseNotification"])
        [center addObserver:self selector:@selector(didChange:) name:name object:nil];
    return self;
}
- (void)beginTransition:(id)window {
    [self.transitionTimer invalidate];
    self.transitionWindow = window;
    // AppKit exposes failure callbacks on the existing window delegate, not
    // failure notifications. Do not replace that delegate. A bounded watchdog
    // recovers if toggleFullScreen: does nothing or the animation fails.
    __weak ISDFullscreen *weakSelf = self;
    self.transitionTimer = [NSTimer timerWithTimeInterval:5 repeats:NO block:^(NSTimer *timer) {
        ISDFullscreen *target = weakSelf;
        if (target.transitionTimer != timer) return;
        target.transitionWindow = nil;
        target.transitionTimer = nil;
    }];
    [NSRunLoop.mainRunLoop addTimer:self.transitionTimer forMode:NSRunLoopCommonModes];
}
- (void)willChange:(NSNotification *)notification {
    Class<ISDFullscreenApplication> type = (Class)NSClassFromString(@"NSApplication");
    if (notification.object == [(id<ISDFullscreenApplication>)[type sharedApplication] keyWindow])
        [self beginTransition:notification.object];
}
- (void)didChange:(NSNotification *)notification {
    if (self.transitionWindow == notification.object) {
        [self.transitionTimer invalidate]; self.transitionTimer = nil;
        self.transitionWindow = nil;
    }
}
- (BOOL)toggle {
    if (!NSThread.isMainThread || !self.canToggle || !self.canToggle()) return NO;
    Class<ISDFullscreenApplication> type = (Class)NSClassFromString(@"NSApplication");
    if (![type respondsToSelector:@selector(sharedApplication)]) return NO;
    id<ISDFullscreenApplication> app = [type sharedApplication];
    id<ISDFullscreenWindow> window = app.keyWindow;
    if (!app.isActive || !window || window.attachedSheet ||
        ![window respondsToSelector:@selector(toggleFullScreen:)]) return NO;
    // Consume a second F during the native animation, without queuing a second
    // toggle. Also handles transitions started with the green window button.
    if (self.transitionWindow) return YES;
    [self beginTransition:window];
    [window toggleFullScreen:nil];
    return YES;
}
- (void)dealloc {
    [self.transitionTimer invalidate];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
@end
