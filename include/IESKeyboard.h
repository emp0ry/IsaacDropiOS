#import <Foundation/Foundation.h>

// Aliases Enter inside Isaac's own verified keyboard handlers.
@interface IESKeyboard : NSObject
- (instancetype)initWithCanMap:(BOOL (^)(void))canMap;
- (BOOL)start;
- (void)suspend;
- (void)cancelMapping;
@end
