#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface ISDRestartKey : NSObject
- (instancetype)initWithHandler:(BOOL (^)(BOOL down))handler;
- (void)start;
@end
NS_ASSUME_NONNULL_END
