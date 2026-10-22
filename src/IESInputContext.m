#import "IESInputContext.h"

@protocol IESInputView <NSObject>
@property(nonatomic, readonly) BOOL isFirstResponder;
@property(nonatomic, readonly) NSArray *subviews;
@end
static BOOL Scan(id<IESInputView> view, Class gameViewClass, Protocol *keyInput,
    Protocol *textInput, NSUInteger *budget) {
    if (!view) return NO;
    if (!*budget) return YES;
    --*budget;
    BOOL gameView = gameViewClass && [view isKindOfClass:gameViewClass];
    if (!gameView && view.isFirstResponder && ([view conformsToProtocol:keyInput] ||
        [view conformsToProtocol:textInput])) return YES;
    for (id child in view.subviews) if (Scan(child,gameViewClass,keyInput,textInput,budget)) return YES;
    return NO;
}
BOOL IESHasTextInput(id root, Class gameViewClass, Protocol *keyInput, Protocol *textInput) {
    NSUInteger budget = 512;
    return Scan(root,gameViewClass,keyInput,textInput,&budget);
}
