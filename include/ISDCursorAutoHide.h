#import <Foundation/Foundation.h>

// Main-thread only. AppKit is resolved dynamically, so iPhone builds do not
// link AppKit or change the iOS pointer. Uses the controller's existing tick.
@interface ISDCursorAutoHide : NSObject
@property(nonatomic, readonly) BOOL installed;
- (void)tickWithHost:(id)host gameplay:(BOOL)gameplay;
- (void)suspend;
@end
