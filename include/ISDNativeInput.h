#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN
@interface ISDNativeInput : NSObject
@property(nonatomic, readonly) BOOL supported;
@property(nonatomic, readonly) BOOL installed;
- (BOOL)installWithDisplayLink:(CADisplayLink *)link;
- (BOOL)gameplayAvailable;
- (void)setAvailable:(BOOL)available;
- (void)press;
- (void)releasePress;
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
