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

@protocol IESPanelView <NSObject>
@property(nonatomic, readonly, getter=isHidden) BOOL hidden;
@property(nonatomic, readonly) CGFloat alpha;
@property(nonatomic, readonly) BOOL accessibilityViewIsModal;
@property(nonatomic, readonly) NSInteger tag;
@property(nonatomic, readonly) NSArray *subviews;
@end
static BOOL Panel(id<IESPanelView> view, NSUInteger *budget) {
    if (!view) return NO;
    if (!*budget) return YES;
    --*budget;
    // Match UIView's actual getter. An unfamiliar host/proxy must keep the
    // cursor visible rather than raising an unrecognized-selector exception.
    SEL required[] = {@selector(isHidden),@selector(alpha),@selector(accessibilityViewIsModal),
        @selector(tag),@selector(subviews)};
    for (NSUInteger i = 0; i < sizeof(required)/sizeof(required[0]); ++i)
        if (![view respondsToSelector:required[i]]) return YES;
    if (view.hidden || view.alpha <= .01) return NO;
    if (view.accessibilityViewIsModal || view.tag == 0xE1D) return YES;
    for (id child in view.subviews) if (Panel(child,budget)) return YES;
    return NO;
}
BOOL IESHasBlockingPanel(id root) {
    NSUInteger budget = 512;
    return Panel(root,&budget);
}
