#import <UIKit/UIKit.h>

@interface ISDMiniHUD : NSObject
// Native Mini draw adapter. Never changes textures or sampler/GL state.
- (void)tickWithWindow:(UIWindow *)window displayLink:(CADisplayLink *)link;
- (void)suspend;
@end
