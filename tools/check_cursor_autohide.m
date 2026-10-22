#import "ISDCursorAutoHide.h"
#import "IESInputContext.h"
#import <CoreGraphics/CoreGraphics.h>
#include <assert.h>
#include <math.h>

@interface ISDCursorAutoHide (Check)
- (void)tickWithHost:(id)host gameplay:(BOOL)gameplay time:(NSTimeInterval)now;
- (void)activityAtTime:(NSTimeInterval)now;
@end
static int Hides, Unhides, HideCount;
@interface NSCursor : NSObject @end
@implementation NSCursor
+ (void)hide { Hides++; HideCount++; }
+ (void)unhide { Unhides++; HideCount--; assert(HideCount >= 0); }
@end
@interface CursorView : NSObject
@property(nonatomic) CGRect bounds;
@end
@implementation CursorView
- (CGPoint)convertPoint:(CGPoint)point fromView:(id)view { (void)view; return point; }
@end
@interface NSWindow : NSObject
@property(nonatomic, strong) id attachedSheet;
@property(nonatomic) BOOL inLiveResize;
@property(nonatomic, strong) CursorView *contentView;
@property(nonatomic) CGRect contentLayoutRect;
@property(nonatomic) CGPoint mouseLocationOutsideOfEventStream;
@end
@implementation NSWindow @end
@interface NSApplication : NSObject
@property(nonatomic) BOOL isActive;
@property(nonatomic, strong) NSWindow *keyWindow;
@property(nonatomic, strong) id modalWindow;
@end
@implementation NSApplication
+ (id)sharedApplication { static id app; if (!app) app = [self new]; return app; }
@end
static NSUInteger Buttons, EventMask;
static NSMutableArray *Monitors;
static BOOL MonitorAvailable = YES;
@interface NSEvent : NSObject @end
@implementation NSEvent
+ (NSUInteger)pressedMouseButtons { return Buttons; }
+ (id)addLocalMonitorForEventsMatchingMask:(NSUInteger)mask handler:(id (^)(id))handler {
    if (!MonitorAvailable) return nil;
    EventMask = mask;
    if (!Monitors) Monitors = [NSMutableArray new];
    id monitor = [handler copy];
    [Monitors addObject:monitor]; return monitor;
}
+ (void)removeMonitor:(id)monitor { [Monitors removeObject:monitor]; }
@end
@interface PanelView : NSObject
// Match UIView's real Objective-C getter, not an invented -hidden method.
@property(nonatomic, getter=isHidden) BOOL hidden;
@property(nonatomic) CGFloat alpha;
@property(nonatomic) BOOL accessibilityViewIsModal;
@property(nonatomic) NSInteger tag;
@property(nonatomic, strong) NSArray *subviews;
@end
@implementation PanelView
- (instancetype)init { if ((self = [super init])) self.alpha = 1; return self; }
@end
static void MouseEvent(void) {
    id event = [NSObject new];
    for (id (^handler)(id) in Monitors) assert(handler(event) == event);
}
int main(void) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication]; app.isActive = YES;
        NSWindow *window = [NSWindow new]; window.contentView = [CursorView new];
        window.contentView.bounds = CGRectMake(0,0,640,480);
        window.contentLayoutRect = window.contentView.bounds;
        window.mouseLocationOutsideOfEventStream = CGPointMake(320,240);
        app.keyWindow = window;
        id host = [NSObject new];
        ISDCursorAutoHide *fix = nil;
        @autoreleasepool {
        fix = [ISDCursorAutoHide new];
        assert(fix.installed);
        assert(Monitors.count == 1 && (EventMask & (1UL<<5)) && (EventMask & (1UL<<22)));
        assert(!(EventMask & (1UL<<10))); // Keyboard gameplay doesn't keep revealing the cursor.
        [fix tickWithHost:host gameplay:NO time:1];
        [fix tickWithHost:host gameplay:NO time:100]; assert(Hides == 0);
        [fix tickWithHost:host gameplay:YES time:101];
        [fix tickWithHost:host gameplay:YES time:103.999]; assert(Hides == 0);
        [fix tickWithHost:host gameplay:YES time:104]; assert(Hides == 1 && HideCount == 1);
        for (int i = 0; i < 10000; ++i) [fix tickWithHost:host gameplay:YES time:104+i*.05];
        assert(Hides == 1); // One counted hide, not another hide on every tick.
        MouseEvent(); assert(Unhides == 1 && HideCount == 0);
        [fix tickWithHost:host gameplay:YES time:700];
        [fix tickWithHost:host gameplay:YES time:703]; assert(HideCount == 1);
        window.mouseLocationOutsideOfEventStream = CGPointMake(321,240);
        [fix tickWithHost:host gameplay:YES time:704]; assert(HideCount == 0); // No mouseMoved needed.
        [fix tickWithHost:host gameplay:YES time:707]; assert(HideCount == 1);
        [fix tickWithHost:host gameplay:NO time:708]; assert(HideCount == 0); // Pause/menu/panel.
        [fix tickWithHost:host gameplay:YES time:800]; assert(HideCount == 0);
        [fix tickWithHost:host gameplay:YES time:803]; assert(HideCount == 1);
        window.mouseLocationOutsideOfEventStream = CGPointMake(321,500); // Title bar/outside content.
        [fix tickWithHost:host gameplay:YES time:804]; assert(HideCount == 0);
        [fix tickWithHost:host gameplay:YES time:900]; assert(HideCount == 0);
        window.contentView.bounds = CGRectMake(0,0,640,520); // Full-size Catalyst content includes titlebar.
        [fix tickWithHost:host gameplay:YES time:900.1]; assert(HideCount == 0);
        [fix tickWithHost:host gameplay:YES time:904.1]; assert(HideCount == 0);
        window.contentView.bounds = window.contentLayoutRect;
        window.mouseLocationOutsideOfEventStream = CGPointMake(321,240);
        [fix tickWithHost:host gameplay:YES time:901];
        Buttons = 1; [fix tickWithHost:host gameplay:YES time:904]; assert(HideCount == 0);
        Buttons = 0; [fix tickWithHost:host gameplay:YES time:905];
        [fix tickWithHost:host gameplay:YES time:908]; assert(HideCount == 1);
        app.isActive = NO; [fix tickWithHost:host gameplay:YES time:909]; assert(HideCount == 0);
        app.isActive = YES;
        for (NSString *name in @[@"NSApplicationWillResignActiveNotification",
            @"NSWindowDidResignKeyNotification",@"NSWindowWillCloseNotification",
            @"NSWindowWillMiniaturizeNotification",@"NSWindowWillEnterFullScreenNotification",
            @"NSWindowWillExitFullScreenNotification"]) {
            [fix tickWithHost:host gameplay:YES time:1000];
            [fix tickWithHost:host gameplay:YES time:1003]; assert(HideCount == 1);
            [NSNotificationCenter.defaultCenter postNotificationName:name object:window];
            assert(HideCount == 0);
        }
        NSWindow *otherWindow = [NSWindow new]; otherWindow.contentView = window.contentView;
        otherWindow.mouseLocationOutsideOfEventStream = window.mouseLocationOutsideOfEventStream;
        app.keyWindow = otherWindow;
        [fix tickWithHost:host gameplay:YES time:1100];
        [fix tickWithHost:host gameplay:YES time:1104]; assert(HideCount == 0);
        app.keyWindow = window; window.attachedSheet = [NSObject new];
        [fix tickWithHost:host gameplay:YES time:1200];
        [fix tickWithHost:host gameplay:YES time:1204]; assert(HideCount == 0);
        window.attachedSheet = nil; app.modalWindow = otherWindow;
        [fix tickWithHost:host gameplay:YES time:1205]; assert(HideCount == 0);
        app.modalWindow = nil; window.inLiveResize = YES;
        [fix tickWithHost:host gameplay:YES time:1210]; assert(HideCount == 0);
        window.inLiveResize = NO;
        [fix tickWithHost:host gameplay:YES time:1300];
        [fix tickWithHost:host gameplay:YES time:1303]; assert(HideCount == 1);
        [fix tickWithHost:nil gameplay:YES time:1304]; assert(HideCount == 0);
        [fix tickWithHost:host gameplay:YES time:NAN];
        [fix tickWithHost:host gameplay:YES time:INFINITY];
        [fix tickWithHost:host gameplay:YES time:0]; assert(HideCount == 0);
        [fix tickWithHost:host gameplay:YES time:1400];
        [fix tickWithHost:host gameplay:YES time:1399];
        [fix tickWithHost:host gameplay:YES time:1401]; assert(HideCount == 0);
        [fix tickWithHost:host gameplay:YES time:1402]; assert(HideCount == 1);
        [fix suspend]; assert(HideCount == 0);
        [NSCursor hide]; // Simulate another owner; never unhide its cursor.
        [fix suspend]; assert(HideCount == 1);
        [fix tickWithHost:host gameplay:YES time:1500];
        [fix tickWithHost:host gameplay:YES time:1503]; assert(HideCount == 2);
        } // Drain temporary weak-observer loads before checking deallocation.
        __weak id lifetime = fix;
        fix = nil;
        assert(lifetime == nil && HideCount == 1 && Monitors.count == 0);
        [NSCursor unhide]; assert(HideCount == 0 && Hides == Unhides);
        MonitorAvailable = NO; fix = [ISDCursorAutoHide new];
        assert(!fix.installed);
        [fix tickWithHost:host gameplay:YES time:1600];
        [fix tickWithHost:host gameplay:YES time:1603]; assert(HideCount == 0);
        fix = nil;
        PanelView *root = [PanelView new], *panel = [PanelView new], *child = [PanelView new];
        assert([root respondsToSelector:@selector(isHidden)]);
        assert(![root respondsToSelector:NSSelectorFromString(@"hidden")]);
        root.subviews = @[panel]; panel.subviews = @[child];
        assert(!IESHasBlockingPanel(root));
        panel.tag = 0xE1D; assert(IESHasBlockingPanel(root));
        panel.hidden = YES; assert(!IESHasBlockingPanel(root)); panel.hidden = NO;
        panel.alpha = .001; assert(!IESHasBlockingPanel(root)); panel.alpha = 1;
        panel.tag = 0; child.accessibilityViewIsModal = YES; assert(IESHasBlockingPanel(root));
        root.hidden = YES; assert(!IESHasBlockingPanel(root));
        assert(IESHasBlockingPanel([NSObject new])); // Unknown host is visible-safe, not a crash.
        root.hidden = NO; root.subviews = @[[NSObject new]];
        assert(IESHasBlockingPanel(root));
        puts("Cursor checks passed: 3s idle, motion/events, pause/panels, focus/window bounds, buttons, fullscreen, balanced hides, no event consumption");
    }
}
