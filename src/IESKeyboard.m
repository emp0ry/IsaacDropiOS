#import "IESKeyboard.h"
#import <objc/runtime.h>
#import <mach-o/loader.h>
#include <dlfcn.h>
#include <string.h>

// UIKit USB HID usages, not macOS virtual keycodes.
static const NSInteger ReturnKey = 40, SpaceKey = 44, KeypadEnter = 88;
static const NSUInteger Modified = (1UL<<17)|(1UL<<18)|(1UL<<19)|(1UL<<20)|(1UL<<23);
@protocol IESNativeKey <NSObject>
@property(nonatomic, readonly) NSInteger keyCode;
@property(nonatomic, readonly) NSUInteger modifierFlags;
@end
@protocol IESNativePress <NSObject>
@property(nonatomic, readonly) NSInteger type;
@property(nonatomic, readonly) id<IESNativeKey> key;
@end

// The verified IsaacShell handlers only read press.type, press.key.keyCode,
// and press.key.modifierFlags. Pass an immutable adapter to that handler,
// never a fabricated UIPress/UIEvent into UIKit or Catalyst.
@interface IESSpaceKey : NSObject <IESNativeKey>
@end
@implementation IESSpaceKey
- (NSInteger)keyCode { return SpaceKey; }
- (NSUInteger)modifierFlags { return 0; }
- (NSString *)characters { return @" "; }
- (NSString *)charactersIgnoringModifiers { return @" "; }
@end
@interface IESSpacePress : NSObject <IESNativePress>
@property(nonatomic) NSInteger type;
@property(nonatomic, strong) id<IESNativeKey> key;
@end
@implementation IESSpacePress @end

typedef BOOL (*KeyHandler)(id,SEL,id);
static KeyHandler OriginalDown, OriginalUp;
static __weak IESKeyboard *Keyboard;

@interface IESKeyboard ()
@property(nonatomic, copy) BOOL (^canMap)(void);
@property(nonatomic) NSUInteger held;
@property(nonatomic) NSUInteger consumed;
@property(nonatomic) NSUInteger mapped;
@property(nonatomic) BOOL physicalSpace;
@property(nonatomic) BOOL outputDown;
@property(nonatomic, weak) id shell;
@property(nonatomic, strong) IESSpacePress *spacePress;
- (BOOL)handlePress:(id<IESNativePress>)press down:(BOOL)down target:(id)target;
@end

static BOOL Down(id target, SEL selector, id press) {
    IESKeyboard *keyboard = Keyboard;
    return keyboard ? [keyboard handlePress:press down:YES target:target] : OriginalDown(target,selector,press);
}
static BOOL Up(id target, SEL selector, id press) {
    IESKeyboard *keyboard = Keyboard;
    return keyboard ? [keyboard handlePress:press down:NO target:target] : OriginalUp(target,selector,press);
}

static BOOL ValidNativeHandlers(Class shell, Method down, Method up) {
    if (!shell || !down || !up || method_getNumberOfArguments(down) != 3 ||
        method_getNumberOfArguments(up) != 3) return NO;
    char returnType[8] = {0}; method_getReturnType(down,returnType,sizeof(returnType));
    if (strcmp(returnType,@encode(BOOL))) return NO;
    method_getReturnType(up,returnType,sizeof(returnType));
    if (strcmp(returnType,@encode(BOOL))) return NO;
#if defined(IES_HOST_CHECK)
    return YES; // Host fixture only; never defined for the dylib.
#else
    Dl_info info = {0}, upInfo = {0};
    IMP downIMP = method_getImplementation(down), upIMP = method_getImplementation(up);
    if (!dladdr((const void *)downIMP,&info) || !dladdr((const void *)upIMP,&upInfo) ||
        info.dli_fbase != upInfo.dli_fbase) return NO;
    const struct mach_header_64 *header = info.dli_fbase;
    if (!header || header->magic != MH_MAGIC_64 || header->sizeofcmds > 1024*1024 || header->ncmds > 4096)
        return NO;
    BOOL uuidOK = NO;
    const uint8_t *cursor = (const uint8_t *)(header+1), *end = cursor+header->sizeofcmds;
    for (uint32_t i = 0; i < header->ncmds; ++i) {
        if (cursor > end || (size_t)(end-cursor) < sizeof(struct load_command)) return NO;
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(*command) || (size_t)(end-cursor) < command->cmdsize) return NO;
        if (command->cmd == LC_UUID && command->cmdsize >= sizeof(struct uuid_command)) {
            const struct uuid_command *uuid = (const struct uuid_command *)command;
            uuidOK = [[[[NSUUID alloc] initWithUUIDBytes:uuid->uuid] UUIDString]
                isEqualToString:@"F4357753-A25F-30EE-BACF-63709F902895"];
        }
        cursor += command->cmdsize;
    }
    // iOS 1.4 handlers translate HID 44 through the native key table and call
    // IsaacFun.pfOnKeyDown/Up. No special active-item or pause action here.
    uintptr_t base = (uintptr_t)header;
    return uuidOK && (uintptr_t)downIMP == base+0x51cc && (uintptr_t)upIMP == base+0x52bc;
#endif
}

@implementation IESKeyboard
- (instancetype)initWithCanMap:(BOOL (^)(void))canMap {
    if ((self = [super init])) _canMap = [canMap copy];
    return self;
}
- (BOOL)start {
    NSAssert(NSThread.isMainThread,@"Install native keyboard alias on the main thread");
    if (Keyboard == self) return YES;
    if (Keyboard) return NO;
    Class shell = NSClassFromString(@"IsaacShell");
    Method down = class_getInstanceMethod(shell,@selector(onKeyDown:));
    Method up = class_getInstanceMethod(shell,@selector(onKeyUp:));
    if (!ValidNativeHandlers(shell,down,up)) return NO;
    OriginalDown = (KeyHandler)method_getImplementation(down);
    OriginalUp = (KeyHandler)method_getImplementation(up);
    Keyboard = self;
    method_setImplementation(down,(IMP)Down);
    method_setImplementation(up,(IMP)Up);
    return YES;
}
- (void)cancelMapping {
    BOOL owned = self.mapped != 0;
    self.mapped = 0;
    if (owned && self.outputDown && !self.physicalSpace) {
        id shell = self.shell;
        if (shell && self.spacePress) OriginalUp(shell,@selector(onKeyUp:),self.spacePress);
        self.outputDown = NO;
    }
}
- (void)suspend {
    self.physicalSpace = NO;
    [self cancelMapping];
    self.outputDown = NO;
    self.held = 0; self.consumed = 0;
}
- (BOOL)handlePress:(id<IESNativePress>)press down:(BOOL)down target:(id)target {
    KeyHandler original = down ? OriginalDown : OriginalUp;
    SEL selector = down ? @selector(onKeyDown:) : @selector(onKeyUp:);
    if (!NSThread.isMainThread || press.type == 4 || !press.key) return original(target,selector,press);
    NSInteger code = press.key.keyCode;
    if (code != ReturnKey && code != KeypadEnter && code != SpaceKey) return original(target,selector,press);
    BOOL allowed = self.canMap && self.canMap();
    if (self.mapped && (!allowed || (press.key.modifierFlags & Modified) || self.shell != target))
        [self cancelMapping];
    if (code == SpaceKey) {
        self.physicalSpace = down;
        if (self.mapped && self.outputDown) return YES;
        self.outputDown = down;
        return original(target,selector,press);
    }
    NSUInteger bit = code == ReturnKey ? 1 : 2;
    if (!down) {
        BOOL consumed = (self.consumed & bit) != 0;
        self.held &= ~bit; self.consumed &= ~bit; self.mapped &= ~bit;
        if (!consumed) return original(target,selector,press);
        if (self.mapped || self.physicalSpace || !self.outputDown) return YES;
        self.outputDown = NO;
        id shell = self.shell;
        return shell ? OriginalUp(shell,selector,self.spacePress) : YES;
    }
    if (self.held & bit) return (self.consumed & bit) ? YES : original(target,selector,press);
    self.held |= bit;
    if (!allowed || (press.key.modifierFlags & Modified)) return original(target,selector,press);
    IESSpacePress *mapped = [IESSpacePress new]; mapped.type = press.type; mapped.key = [IESSpaceKey new];
    if (!self.outputDown && !OriginalDown(target,selector,mapped)) return original(target,selector,press);
    self.shell = target; self.spacePress = mapped;
    self.consumed |= bit; self.mapped |= bit; self.outputDown = YES;
    static BOOL loggedAlias;
    if (!loggedAlias) { loggedAlias = YES; NSLog(@"[IsaacFixes] Enter -> native Space (HID 44)"); }
    return YES;
}
@end
