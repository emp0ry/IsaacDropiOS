#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface ISDRestartKey : NSObject
- (instancetype)initWithHandler:(BOOL (^)(BOOL down))handler;
- (instancetype)initWithHandler:(BOOL (^)(BOOL down))handler escapeHandler:(BOOL (^)(void))escapeHandler;
- (instancetype)initWithHandler:(BOOL (^)(BOOL down))handler escapeHandler:(BOOL (^)(void))escapeHandler
    fullscreenHandler:(BOOL (^)(void))fullscreenHandler;
- (void)start;
@end
NS_ASSUME_NONNULL_END
