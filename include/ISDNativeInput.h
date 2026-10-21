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
- (BOOL)restartAvailable;
- (BOOL)restartContextAvailable;
- (BOOL)restartTransitionPending;
- (BOOL)restartDown:(unsigned)source;
- (void)restartUp:(unsigned)source;
- (void)pollRestart;
- (void)cancelRestart;
@end
NS_ASSUME_NONNULL_END
