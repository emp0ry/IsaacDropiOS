#import "ISDCursorAutoHide.h"
#import <CoreGraphics/CoreGraphics.h>
#include <math.h>

@protocol ISDCursorAPI <NSObject>
+ (void)hide;
+ (void)unhide;
@end
@protocol ISDCursorView <NSObject>
@property(nonatomic, readonly) CGRect bounds;
- (CGPoint)convertPoint:(CGPoint)point fromView:(id)view;
@end
@protocol ISDCursorWindow <NSObject>
@property(nonatomic, readonly) id attachedSheet;
@property(nonatomic, readonly) BOOL inLiveResize;
@property(nonatomic, readonly) id<ISDCursorView> contentView;
@property(nonatomic, readonly) CGRect contentLayoutRect;
@property(nonatomic, readonly) CGPoint mouseLocationOutsideOfEventStream;
@end
@protocol ISDCursorApplication <NSObject>
+ (id)sharedApplication;
@property(nonatomic, readonly) BOOL isActive;
@property(nonatomic, readonly) id<ISDCursorWindow> keyWindow;
@property(nonatomic, readonly) id modalWindow;
@end
@protocol ISDCursorEvents <NSObject>
+ (NSUInteger)pressedMouseButtons;
+ (id)addLocalMonitorForEventsMatchingMask:(NSUInteger)mask handler:(id (^)(id))handler;
+ (void)removeMonitor:(id)monitor;
@end

static const NSTimeInterval CursorIdleSeconds = 3.0;

@interface ISDCursorAutoHide ()
@property(nonatomic) Class<ISDCursorAPI> cursorClass;
@property(nonatomic) Class<ISDCursorApplication> applicationClass;
@property(nonatomic) Class<ISDCursorEvents> eventsClass;
@property(nonatomic, strong) id monitor;
@property(nonatomic, weak) id host;
@property(nonatomic, weak) id<ISDCursorWindow> window;
@property(nonatomic) BOOL hiddenByUs;
@property(nonatomic) BOOL hasPoint;
@property(nonatomic) CGPoint lastPoint;
@property(nonatomic) NSTimeInterval lastActivity;
- (void)activityAtTime:(NSTimeInterval)now;
- (void)tickWithHost:(id)host gameplay:(BOOL)gameplay time:(NSTimeInterval)now;
@end

@implementation ISDCursorAutoHide
- (BOOL)installed { return self.monitor != nil; }
- (instancetype)init {
    if (!(self = [super init])) return nil;
    Class<ISDCursorAPI> cursor = (Class)NSClassFromString(@"NSCursor");
    Class<ISDCursorApplication> application = (Class)NSClassFromString(@"NSApplication");
    Class<ISDCursorEvents> events = (Class)NSClassFromString(@"NSEvent");
    if (!NSThread.isMainThread || ![cursor respondsToSelector:@selector(hide)] ||
        ![cursor respondsToSelector:@selector(unhide)] ||
        ![application respondsToSelector:@selector(sharedApplication)] ||
        ![events respondsToSelector:@selector(pressedMouseButtons)] ||
        ![events respondsToSelector:@selector(addLocalMonitorForEventsMatchingMask:handler:)]) return self;
    self.cursorClass = cursor; self.applicationClass = application; self.eventsClass = events;
    __weak ISDCursorAutoHide *weakSelf = self;
    // Only this application's mouse events. No global event tap, key logging,
    // event synthesis, or modifications to the game's mouse-moved setting.
    NSUInteger mask = (1UL<<1)|(1UL<<2)|(1UL<<3)|(1UL<<4)|(1UL<<5)|(1UL<<6)|
        (1UL<<7)|(1UL<<8)|(1UL<<9)|(1UL<<22)|(1UL<<25)|(1UL<<26)|(1UL<<27);
    self.monitor = [events addLocalMonitorForEventsMatchingMask:mask handler:^id(id event) {
        [weakSelf activityAtTime:NSProcessInfo.processInfo.systemUptime];
        return event; // Never consume, rewrite or repost a mouse event.
    }];
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSString *name in @[@"NSApplicationWillResignActiveNotification",
        @"NSWindowDidResignKeyNotification",@"NSWindowWillCloseNotification",
        @"NSWindowWillMiniaturizeNotification",@"NSWindowWillEnterFullScreenNotification",
        @"NSWindowWillExitFullScreenNotification"])
        [center addObserver:self selector:@selector(suspend) name:name object:nil];
    return self;
}
- (void)showOwnedCursor {
    if (!self.hiddenByUs) return;
    // NSCursor is counted. Balance exactly our own single hide, never undo a
    // hide belonging to PlayTools/the game, and never force the cursor shape.
    self.hiddenByUs = NO;
    [self.cursorClass unhide];
}
- (void)suspend {
    [self showOwnedCursor];
    self.hasPoint = NO;
    self.lastActivity = 0;
}
- (void)activityAtTime:(NSTimeInterval)now {
    [self showOwnedCursor];
    self.lastActivity = isfinite(now) && now > 0 ? now : 0;
}
- (void)tickWithHost:(id)host gameplay:(BOOL)gameplay {
    [self tickWithHost:host gameplay:gameplay time:NSProcessInfo.processInfo.systemUptime];
}
- (void)tickWithHost:(id)host gameplay:(BOOL)gameplay time:(NSTimeInterval)now {
    if (!NSThread.isMainThread) return;
    id<ISDCursorApplication> app = [self.applicationClass sharedApplication];
    id<ISDCursorWindow> window = app.keyWindow;
    if (!self.monitor || !gameplay || !host || !isfinite(now) || now <= 0 ||
        !app.isActive || !window || app.modalWindow || window.attachedSheet || window.inLiveResize ||
        ![window respondsToSelector:@selector(contentView)] ||
        ![window respondsToSelector:@selector(contentLayoutRect)] ||
        ![window respondsToSelector:@selector(mouseLocationOutsideOfEventStream)]) {
        [self suspend]; return;
    }
    if (host != self.host) {
        [self suspend]; self.host = host; self.window = window;
    }
    // A different Mac window becoming key must not inherit the game's cursor
    // hiding, even if Catalyst still reports the old UIKit window as key.
    if (window != self.window) { [self suspend]; return; }
    id<ISDCursorView> content = window.contentView;
    if (!content || ![content respondsToSelector:@selector(convertPoint:fromView:)] ||
        ![content respondsToSelector:@selector(bounds)]) { [self suspend]; return; }
    CGPoint windowPoint = window.mouseLocationOutsideOfEventStream;
    CGPoint point = [content convertPoint:windowPoint fromView:nil];
    if (!isfinite(point.x) || !isfinite(point.y) || CGRectIsEmpty(window.contentLayoutRect) ||
        !CGRectContainsPoint(window.contentLayoutRect,windowPoint) || CGRectIsEmpty(content.bounds) ||
        !CGRectContainsPoint(content.bounds,point) || [self.eventsClass pressedMouseButtons]) {
        [self suspend]; return;
    }
    // Poll the owning window as a fallback: mouseMoved delivery may be disabled
    // by the host. This also detects leaving the content area/title bar.
    if (!self.hasPoint || !CGPointEqualToPoint(point,self.lastPoint) ||
        !self.lastActivity || now < self.lastActivity) [self activityAtTime:now];
    self.hasPoint = YES; self.lastPoint = point;
    if (!self.hiddenByUs && now-self.lastActivity >= CursorIdleSeconds) {
        [self.cursorClass hide]; self.hiddenByUs = YES;
    }
}
- (void)dealloc {
    [self showOwnedCursor];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if (_monitor) [_eventsClass removeMonitor:_monitor];
}
@end
