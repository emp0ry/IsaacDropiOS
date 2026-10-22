#import <Foundation/Foundation.h>

// No dependency on Debug Console: with no listener the native Esc path wins.
// Request closure synchronously so two independently installed key monitors
// cannot close the console and toggle native pause again for the same key-down.
static inline BOOL ISDConsoleClosesForEscape(void) {
    NSMutableDictionary *request=[NSMutableDictionary dictionary];
    [NSNotificationCenter.defaultCenter postNotificationName:@"com.emp0ry.isaacconsole.closeForEscape" object:request];
    return [request[@"handled"] boolValue];
}
