#import <UIKit/UIKit.h>

@interface ISDPlanetarium : NSObject
- (void)tickWithWindow:(UIWindow *)window displayLink:(CADisplayLink *)link;
- (void)suspend;
@end
