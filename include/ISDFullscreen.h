#import <Foundation/Foundation.h>
@interface ISDFullscreen : NSObject
- (instancetype)initWithCanToggle:(BOOL (^)(void))canToggle;
- (BOOL)toggle;
@end
