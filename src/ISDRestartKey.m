#import "ISDRestartKey.h"
#import "ISDHost.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Public AppKit selectors are resolved only inside PlayCover/Catalyst. The
// iPhone dylib has no AppKit dependency and never monitors another app's keys.
@protocol ISDDesktopKeyEvent <NSObject>
@property(nonatomic, readonly) unsigned short keyCode;
@property(nonatomic, readonly) NSUInteger modifierFlags;
@property(nonatomic, readonly) NSInteger type;
@property(nonatomic, readonly) BOOL isARepeat;
@end
@protocol ISDDesktopEventMonitoring <NSObject>
+ (id)addLocalMonitorForEventsMatchingMask:(NSUInteger)mask handler:(id _Nullable (^)(id event))handler;
+ (void)removeMonitor:(id)monitor;
@end
@interface ISDRestartKey ()
@property(nonatomic, copy) BOOL (^handler)(BOOL down);
@property(nonatomic, copy) BOOL (^escapeHandler)(void);
@property(nonatomic, copy) BOOL (^fullscreenHandler)(void);
@property(nonatomic, strong) id desktopMonitor;
@property(nonatomic) BOOL keyHeld;
@property(nonatomic) BOOL consumed;
@property(nonatomic) BOOL escapeHeld;
@property(nonatomic) BOOL escapeConsumed;
@property(nonatomic) BOOL fullscreenHeld;
@property(nonatomic) BOOL fullscreenConsumed;
- (BOOL)handleEvent:(UIEvent *)event;
@end
static __weak ISDRestartKey *Key;
static void (*OriginalSendEvent)(id, SEL, UIEvent *);
static void SendEvent(id app, SEL selector, UIEvent *event) {
    if ([Key handleEvent:event]) return;
    OriginalSendEvent(app,selector,event);
}
@implementation ISDRestartKey
- (instancetype)initWithHandler:(BOOL (^)(BOOL))handler {
    if ((self = [super init])) _handler = [handler copy];
    return self;
}
- (instancetype)initWithHandler:(BOOL (^)(BOOL))handler escapeHandler:(BOOL (^)(void))escapeHandler {
    if ((self = [self initWithHandler:handler])) _escapeHandler = [escapeHandler copy];
    return self;
}
- (instancetype)initWithHandler:(BOOL (^)(BOOL))handler escapeHandler:(BOOL (^)(void))escapeHandler
    fullscreenHandler:(BOOL (^)(void))fullscreenHandler {
    if ((self = [self initWithHandler:handler escapeHandler:escapeHandler])) _fullscreenHandler = [fullscreenHandler copy];
    return self;
}
- (BOOL)fullscreenDown:(BOOL)down repeat:(BOOL)repeat modified:(BOOL)modified {
    if (!down) {
        BOOL handled = self.fullscreenConsumed;
        self.fullscreenHeld = NO; self.fullscreenConsumed = NO;
        return handled;
    }
    if (self.fullscreenHeld) return self.fullscreenConsumed;
    self.fullscreenHeld = YES;
    self.fullscreenConsumed = !repeat && !modified &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        self.fullscreenHandler && self.fullscreenHandler();
    return self.fullscreenConsumed;
}
- (BOOL)escapeDown:(BOOL)down repeat:(BOOL)repeat modified:(BOOL)modified {
    if (!down) {
        BOOL handled = self.escapeConsumed;
        self.escapeHeld = NO; self.escapeConsumed = NO;
        return handled;
    }
    if (self.escapeHeld) return self.escapeConsumed;
    self.escapeHeld = YES;
    self.escapeConsumed = !repeat && !modified &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        self.escapeHandler && self.escapeHandler();
    return self.escapeConsumed;
}
- (BOOL)down:(BOOL)down repeat:(BOOL)repeat modified:(BOOL)modified {
    if (!down) {
        BOOL handled = self.consumed;
        if (self.keyHeld && self.handler) self.handler(NO);
        self.keyHeld = NO; self.consumed = NO;
        return handled;
    }
    if (self.keyHeld) {
        if (modified && self.handler) self.handler(NO);
        return self.consumed;
    }
    // Latch even an ignored initial down. Autorepeat may not start a hold
    // after closing a dialog, returning to the game, or releasing a modifier.
    self.keyHeld = YES;
    self.consumed = !repeat && !modified &&
        UIApplication.sharedApplication.applicationState == UIApplicationStateActive &&
        self.handler && self.handler(YES);
    return self.consumed;
}
- (BOOL)handleEvent:(UIEvent *)event {
    if (event.type != UIEventTypePresses || ![event isKindOfClass:UIPressesEvent.class]) return NO;
    BOOL allHandled = ((UIPressesEvent *)event).allPresses.count > 0;
    for (UIPress *press in ((UIPressesEvent *)event).allPresses) {
        UIKey *key = press.key;
        BOOL escape = key && key.keyCode == UIKeyboardHIDUsageKeyboardEscape;
        BOOL fullscreen = key && key.keyCode == UIKeyboardHIDUsageKeyboardF;
        if (!key || (!escape && !fullscreen && key.keyCode != UIKeyboardHIDUsageKeyboardR)) { allHandled = NO; continue; }
        BOOL up = press.phase == UIPressPhaseEnded || press.phase == UIPressPhaseCancelled;
        UIKeyModifierFlags mask = UIKeyModifierShift|UIKeyModifierControl|UIKeyModifierAlternate|UIKeyModifierCommand;
        BOOL handled = fullscreen ? self.fullscreenConsumed : escape ? self.escapeConsumed : self.consumed;
        if (press.phase == UIPressPhaseBegan || up) {
            handled = fullscreen ? [self fullscreenDown:!up repeat:NO modified:!up && (key.modifierFlags & mask)]
                : escape ? [self escapeDown:!up repeat:NO modified:!up && (key.modifierFlags & mask)]
                : [self down:!up repeat:NO modified:!up && (key.modifierFlags & mask)];
        }
        if (!handled) allHandled = NO;
    }
    return allHandled;
}
- (void)suspend {
    if (self.keyHeld && self.handler) self.handler(NO);
    // Keep keyHeld until release: returning after focus loss must not restart.
}
- (void)start {
    NSAssert(NSThread.isMainThread,@"Install restart keys on the main thread");
    Key = self;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class app = object_getClass(UIApplication.sharedApplication);
        Method method = class_getInstanceMethod(app,@selector(sendEvent:));
        if (!method) return;
        OriginalSendEvent = (void (*)(id,SEL,UIEvent *))method_getImplementation(method);
        // Chain existing handlers, including Debug Console and PlayTools.
        if (!class_addMethod(app,@selector(sendEvent:),(IMP)SendEvent,method_getTypeEncoding(method)))
            method_setImplementation(method,(IMP)SendEvent);
    });
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(suspend)
        name:UIApplicationWillResignActiveNotification object:nil];
    Class<ISDDesktopEventMonitoring> events = (Class)NSClassFromString(@"NSEvent");
    if (NSClassFromString(@"NSApplication") && [events respondsToSelector:
            @selector(addLocalMonitorForEventsMatchingMask:handler:)]) {
        __weak ISDRestartKey *weakSelf = self;
        self.desktopMonitor = [events addLocalMonitorForEventsMatchingMask:(1UL<<10)|(1UL<<11)|(1UL<<12)
            handler:^id(id<ISDDesktopKeyEvent> event) {
                ISDRestartKey *target = weakSelf;
                NSUInteger mask = (1UL<<17)|(1UL<<18)|(1UL<<19)|(1UL<<20);
                if (event.type == 12) { if (event.modifierFlags & mask) [target suspend]; return event; }
                if (!target || (event.keyCode != 15 && event.keyCode != 53 && event.keyCode != 3)) return event;
                if (event.keyCode == 3) return [target fullscreenDown:event.type != 11 repeat:event.isARepeat
                    modified:(event.modifierFlags & mask) != 0] ? nil : event;
                if (event.keyCode == 53) return [target escapeDown:event.type != 11 repeat:event.isARepeat
                    modified:(event.modifierFlags & mask) != 0] ? nil : event;
                return [target down:event.type != 11 repeat:event.isARepeat
                    modified:(event.modifierFlags & mask) != 0] ? nil : event;
            }];
    }
    ISDLog(@"R, Escape and F input installed (%@)",self.desktopMonitor ? @"UIKit + PlayCover" : @"UIKit");
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    Class<ISDDesktopEventMonitoring> events = (Class)NSClassFromString(@"NSEvent");
    if (_desktopMonitor && [events respondsToSelector:@selector(removeMonitor:)]) [events removeMonitor:_desktopMonitor];
}
@end
