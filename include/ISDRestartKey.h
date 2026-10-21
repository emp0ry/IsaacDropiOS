#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface ISDRestartKey : NSObject
- (instancetype)initWithHandler:(BOOL (^)(BOOL down))handler;
- (instancetype)initWithHandler:(BOOL (^)(BOOL down))handler escapeHandler:(BOOL (^)(void))escapeHandler;
- (void)start;
@end
NS_ASSUME_NONNULL_END
