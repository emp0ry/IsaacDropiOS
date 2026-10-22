#import "IESKeyboard.h"
#import "IESInputContext.h"
#include <assert.h>

@protocol FixtureKeyInput <NSObject> @end
@protocol FixtureTextInput <NSObject> @end
@interface View : NSObject
@property(nonatomic) BOOL isFirstResponder;
@property(nonatomic, strong) NSArray *subviews;
@end
@implementation View @end
@interface GameView : View <FixtureKeyInput> @end
@implementation GameView @end
@interface TextField : View <FixtureKeyInput,FixtureTextInput> @end
@implementation TextField @end
@interface Key : NSObject
@property(nonatomic) NSInteger keyCode;
@property(nonatomic) NSUInteger modifierFlags;
@end
@implementation Key @end
@interface Press : NSObject
@property(nonatomic) NSInteger type;
@property(nonatomic, strong) Key *key;
@end
@implementation Press @end

static NSMutableArray *Calls;
static BOOL Current[512], Previous[512], Paused, OptionsOpened;
static int Selected;
// Fixture mirrors only the verified native HID table/callback boundary, not
// the rest of Isaac. The real binary's table is checked independently.
@interface IsaacShell : NSObject
- (BOOL)onKeyDown:(Press *)press;
- (BOOL)onKeyUp:(Press *)press;
@end
static int NativeCode(NSInteger hid) { return hid == 44 ? 32 : hid == 40 ? -1 : hid == 88 ? 335 : (int)hid; }
@implementation IsaacShell
- (BOOL)onKeyDown:(Press *)press {
    if (press.type == 4 || !press.key) return NO;
    [Calls addObject:[NSString stringWithFormat:@"D%ld",(long)press.key.keyCode]];
    int code = NativeCode(press.key.keyCode); if (code >= 0 && code < 512) Current[code] = YES;
    return YES;
}
- (BOOL)onKeyUp:(Press *)press {
    if (press.type == 4 || !press.key) return NO;
    [Calls addObject:[NSString stringWithFormat:@"U%ld",(long)press.key.keyCode]];
    int code = NativeCode(press.key.keyCode); if (code >= 0 && code < 512) Current[code] = NO;
    return YES;
}
@end
static void Frame(void) {
    if (Paused && Current[32] && !Previous[32]) {
        if (Selected == 0) Paused = NO;
        if (Selected == 1) OptionsOpened = YES;
    }
    memcpy(Previous,Current,sizeof(Current));
}
static BOOL Send(IsaacShell *shell, NSInteger code, BOOL down, NSUInteger flags) {
    Press *press = [Press new]; press.key = [Key new];
    press.key.keyCode = code; press.key.modifierFlags = flags;
    return down ? [shell onKeyDown:press] : [shell onKeyUp:press];
}
static void AssertCalls(NSArray *expected) { assert([Calls isEqualToArray:expected]); [Calls removeAllObjects]; }

int main(void) {
    @autoreleasepool {
        Calls = [NSMutableArray new];
        View *root = [View new]; GameView *game = [GameView new];
        game.isFirstResponder = YES; root.subviews = @[game];
        BOOL (^typing)(void) = ^BOOL {
            return IESHasTextInput(root,GameView.class,@protocol(FixtureKeyInput),@protocol(FixtureTextInput));
        };
        assert(!typing()); // Regression: normal game view is NOT a text editor.
        TextField *field = [TextField new]; field.isFirstResponder = YES;
        game.subviews = @[field]; assert(typing());
        field.isFirstResponder = NO; assert(!typing());
        game.subviews = @[];
        __block BOOL active = YES;
        IESKeyboard *keys = [[IESKeyboard alloc] initWithCanMap:^BOOL { return active && !typing(); }];
        assert([keys start] && [keys start]);
        IsaacShell *shell = [IsaacShell new];
        // Same native Space callback for menu confirmation, not togglePause.
        Paused = YES; Selected = 0;
        assert(Send(shell,40,YES,0)); Frame(); assert(!Paused);
        Send(shell,40,NO,0); Frame(); AssertCalls((@[@"D44",@"U44"]));
        Paused = YES; Selected = 1;
        Send(shell,88,YES,1UL<<21); Frame(); assert(Paused && OptionsOpened);
        Send(shell,88,NO,1UL<<21); Frame(); AssertCalls((@[@"D44",@"U44"]));
        // Hold/repeats and Return + keypad Enter share a single Space hold.
        Send(shell,40,YES,0); Send(shell,40,YES,0); Send(shell,88,YES,0);
        Send(shell,40,NO,0); assert(Current[32]); Send(shell,88,NO,0);
        assert(!Current[32]); AssertCalls((@[@"D44",@"U44"]));
        Send(shell,44,YES,0); Send(shell,40,YES,0); Send(shell,44,NO,0);
        assert(Current[32]); Send(shell,40,NO,0); assert(!Current[32]);
        AssertCalls((@[@"D44",@"U44"]));
        Send(shell,40,YES,0); Send(shell,44,YES,0); Send(shell,40,NO,0);
        assert(Current[32]); Send(shell,44,NO,0); assert(!Current[32]);
        AssertCalls((@[@"D44",@"U44"]));
        // A real text field, including a child of the render view, keeps Enter.
        game.subviews = @[field]; field.isFirstResponder = YES;
        Send(shell,40,YES,0); field.isFirstResponder = NO;
        Send(shell,40,YES,0); Send(shell,40,NO,0);
        AssertCalls((@[@"D40",@"D40",@"U40"]));
        for (NSNumber *flag in @[@(1UL<<17),@(1UL<<18),@(1UL<<19),@(1UL<<20),@(1UL<<23)]) {
            Send(shell,40,YES,flag.unsignedIntegerValue); Send(shell,40,NO,0);
            AssertCalls((@[@"D40",@"U40"]));
        }
        // Unrelated R, Esc, grave shortcuts pass to their existing handlers.
        for (NSNumber *code in @[@21,@41,@53]) {
            Send(shell,code.intValue,YES,0); Send(shell,code.intValue,NO,0);
            AssertCalls((@[[NSString stringWithFormat:@"D%@",code],[NSString stringWithFormat:@"U%@",code]]));
        }
        // Opening a console or losing focus releases an owned Space.
        Send(shell,40,YES,0); [keys cancelMapping]; assert(!Current[32]);
        Send(shell,40,YES,0); Send(shell,40,NO,0);
        AssertCalls((@[@"D44",@"U44"]));
        Send(shell,40,YES,0); [keys suspend]; assert(!Current[32]);
        Send(shell,40,YES,0); Send(shell,40,NO,0);
        AssertCalls((@[@"D44",@"U44",@"D44",@"U44"]));
        active = NO; Send(shell,40,YES,0); Send(shell,40,NO,0);
        AssertCalls((@[@"D40",@"U40"]));
        active = YES;
        for (int i = 0; i < 100; ++i) { Send(shell,40,YES,0); Frame(); Send(shell,40,NO,0); Frame(); }
        assert(!Current[32]); assert(Calls.count == 200);
        puts("Native keyboard checks passed: pause selection, HID callbacks, game-view gate, typing, modifiers, overlaps, cancellation");
    }
    return 0;
}
