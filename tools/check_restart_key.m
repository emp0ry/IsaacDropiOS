#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "ISDRestartKey.h"
#include <assert.h>

NSString *const UIApplicationWillResignActiveNotification = @"CheckSuspend";
@implementation UIKey @end
@implementation UIPress @end
@implementation UIEvent @end
@implementation UIPressesEvent @end
@implementation UIApplication
+ (UIApplication *)sharedApplication { static UIApplication *app; if (!app) app = [UIApplication new]; return app; }
- (void)sendEvent:(UIEvent *)event { (void)event; self.forwarded++; }
@end
void ISDLog(NSString *format, ...) { (void)format; }
static NSMutableArray *Monitors;
@interface NSApplication : NSObject @end
@implementation NSApplication @end
@interface NSEvent : NSObject
@property(nonatomic) unsigned short keyCode;
@property(nonatomic) NSUInteger modifierFlags;
@property(nonatomic) NSInteger type;
@property(nonatomic) BOOL isARepeat;
@end
@implementation NSEvent
+ (id)addLocalMonitorForEventsMatchingMask:(NSUInteger)mask handler:(id (^)(id))handler {
    assert(mask & (1UL<<10)); if (!Monitors) Monitors = [NSMutableArray new];
    [Monitors addObject:[handler copy]]; return handler;
}
+ (void)removeMonitor:(id)monitor { [Monitors removeObject:monitor]; }
@end

// Simulate another mod's grave shortcut in both installation orders. This is
// deliberately independent of that other repository and any extracted game.
static int OtherShortcut;
static void (*OtherOriginalSendEvent)(id,SEL,UIEvent *);
static void OtherSendEvent(id app, SEL selector, UIEvent *event) {
    if ([event isKindOfClass:UIPressesEvent.class] && ((UIPressesEvent *)event).allPresses.count == 1) {
        UIPress *press = ((UIPressesEvent *)event).allPresses.anyObject;
        if (press.key.keyCode == 0x35) {
            if (press.phase == UIPressPhaseBegan) OtherShortcut++;
            return;
        }
    }
    OtherOriginalSendEvent(app,selector,event);
}
static void InstallOtherShortcut(void) {
    Method method = class_getInstanceMethod(UIApplication.class,@selector(sendEvent:));
    OtherOriginalSendEvent = (void (*)(id,SEL,UIEvent *))method_setImplementation(method,(IMP)OtherSendEvent);
    [NSEvent addLocalMonitorForEventsMatchingMask:(1UL<<10)|(1UL<<11) handler:^id(NSEvent *event) {
        if (event.keyCode != 50) return event;
        if (event.type == 10) OtherShortcut++;
        return nil;
    }];
}
static void UIKitEvent(NSInteger code, UIPressPhase phase, UIKeyModifierFlags flags) {
    UIKey *key = [UIKey new]; key.keyCode = code; key.modifierFlags = flags;
    UIPress *press = [UIPress new]; press.key = key; press.phase = phase;
    UIPressesEvent *event = [UIPressesEvent new]; event.type = UIEventTypePresses;
    event.allPresses = [NSSet setWithObject:press];
    [UIApplication.sharedApplication sendEvent:event];
}
static void MacEvent(NSInteger code, NSInteger type, BOOL repeat, NSUInteger flags) {
    NSEvent *event = [NSEvent new]; event.keyCode = code; event.type = type;
    event.isARepeat = repeat; event.modifierFlags = flags;
    id current = event;
    for (id (^handler)(id) in Monitors) { if (!current) break; current = handler(current); }
}
int main(int argc, char **argv) {
    (void)argv;
    @autoreleasepool {
        __block int downs = 0, ups = 0, pauses = 0, fullscreen = 0;
        __block BOOL allowed = YES;
        ISDRestartKey *restart = [[ISDRestartKey alloc] initWithHandler:^BOOL(BOOL down) {
            if (!down) { ups++; return YES; }
            if (!allowed) return NO; downs++; return YES;
        } escapeHandler:^BOOL {
            if (!allowed) return NO;
            pauses++; return YES;
        } fullscreenHandler:^BOOL {
            if (!allowed) return NO;
            fullscreen++; return YES;
        }];
        if (argc > 1) { [restart start]; InstallOtherShortcut(); }
        else { InstallOtherShortcut(); [restart start]; }
        UIApplication *app = UIApplication.sharedApplication;
        UIKitEvent(0x35,UIPressPhaseBegan,0); UIKitEvent(0x35,UIPressPhaseEnded,0);
        assert(OtherShortcut == 1 && downs == 0 && app.forwarded == 0);
        UIKitEvent(0x15,UIPressPhaseBegan,0); UIKitEvent(0x15,UIPressPhaseBegan,0);
        assert(downs == 1 && app.forwarded == 0);
        UIKitEvent(0x15,UIPressPhaseEnded,0); assert(ups == 1);
        allowed = NO;
        UIKitEvent(0x15,UIPressPhaseBegan,0); allowed = YES;
        UIKitEvent(0x15,UIPressPhaseBegan,0); assert(downs == 1);
        UIKitEvent(0x15,UIPressPhaseEnded,0);
        UIKitEvent(0x15,UIPressPhaseBegan,UIKeyModifierCommand);
        UIKitEvent(0x15,UIPressPhaseBegan,0); assert(downs == 1);
        UIKitEvent(0x15,UIPressPhaseCancelled,0);
        MacEvent(15,10,NO,0); MacEvent(15,10,YES,0); assert(downs == 2);
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
        MacEvent(15,10,YES,0); assert(downs == 2);
        MacEvent(15,11,NO,0); MacEvent(15,10,NO,0); assert(downs == 3);
        MacEvent(0,12,NO,1UL<<20); MacEvent(15,10,YES,0); assert(downs == 3);
        MacEvent(15,11,NO,0);
        MacEvent(15,10,YES,0); MacEvent(15,10,YES,0); assert(downs == 3);
        MacEvent(15,11,NO,0);
        MacEvent(50,10,NO,0); MacEvent(50,11,NO,0); assert(OtherShortcut == 2);
        UIKitEvent(0x29,UIPressPhaseBegan,0); UIKitEvent(0x29,UIPressPhaseBegan,0);
        assert(pauses == 1);
        UIKitEvent(0x29,UIPressPhaseEnded,0);
        MacEvent(53,10,NO,0); MacEvent(53,10,YES,0); assert(pauses == 2);
        MacEvent(53,11,NO,0);
        allowed = NO; MacEvent(53,10,NO,0); allowed = YES;
        MacEvent(53,10,YES,0); assert(pauses == 2);
        MacEvent(53,11,NO,0);
        MacEvent(53,10,NO,1UL<<20); MacEvent(53,10,YES,0); assert(pauses == 2);
        MacEvent(53,11,NO,0);
        UIKitEvent(4,UIPressPhaseBegan,0); [app sendEvent:[UIEvent new]];
        assert(app.forwarded >= 6);
        MacEvent(3,10,NO,0); MacEvent(3,10,YES,0); assert(fullscreen == 1);
        MacEvent(3,11,NO,0); MacEvent(3,10,NO,0); assert(fullscreen == 2);
        MacEvent(3,11,NO,0);
        MacEvent(3,10,NO,1UL<<20); MacEvent(3,10,YES,0); assert(fullscreen == 2);
        MacEvent(3,11,NO,0);
        allowed = NO; MacEvent(3,10,NO,0); allowed = YES;
        MacEvent(3,10,YES,0); assert(fullscreen == 2); MacEvent(3,11,NO,0);
        UIKitEvent(9,UIPressPhaseBegan,0); UIKitEvent(9,UIPressPhaseBegan,0);
        assert(fullscreen == 3); UIKitEvent(9,UIPressPhaseEnded,0);
        puts("Keyboard checks passed: R, Esc, F, UIKit, PlayCover, chaining, repeats, focus, modifiers, ignored holds");
    }
}
