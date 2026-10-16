#import "ISDHost.h"
#import <objc/runtime.h>
#include <cmath>

void ISDLog(NSString *format, ...) {
    va_list args; va_start(args,format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[IsaacDrop] %@",message);
    static NSString *path;
    if (!path) {
        NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:
            @"Library/Application Support/IsaacDrop"];
        [NSFileManager.defaultManager createDirectoryAtPath:directory
            withIntermediateDirectories:YES attributes:nil error:nil];
        path = [directory stringByAppendingPathComponent:@"drop.log"];
    }
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if ([attributes[NSFileSize] unsignedLongLongValue] > 128*1024)
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
    if (![NSFileManager.defaultManager fileExistsAtPath:path])
        [NSFileManager.defaultManager createFileAtPath:path contents:nil attributes:nil];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    [handle seekToEndOfFile];
    [handle writeData:[[NSString stringWithFormat:@"%@ [IsaacDrop] %@\n",NSDate.date,message]
        dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

static UIView *RenderView(UIView *root, Class renderClass, NSUInteger& budget) {
    if (!root || !budget || root.hidden || root.alpha <= .01) return nil;
    --budget;
    if ([root isKindOfClass:renderClass]) return root;
    for (UIView *child in root.subviews) {
        UIView *found = RenderView(child,renderClass,budget);
        if (found) return found;
    }
    return nil;
}

UIWindow *ISDReadyWindow(CADisplayLink **linkOut) {
    static __weak UIWindow *observedWindow;
    static __weak CADisplayLink *observedLink;
    static double firstTimestamp;
    if (linkOut) *linkOut = nil;
    if (!NSThread.isMainThread || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        observedWindow = nil; observedLink = nil; firstTimestamp = 0;
        return nil;
    }
    Class renderClass = NSClassFromString(@"AAPLOpenGLView");
    Class controllerClass = NSClassFromString(@"AAPLOpenGLViewController");
    if (!renderClass || !controllerClass) return nil;
    NSMutableArray<UIWindow *> *windows = [NSMutableArray array];
    UIApplication *app = UIApplication.sharedApplication;
    if ([app.delegate respondsToSelector:@selector(window)] && app.delegate.window)
        [windows addObject:app.delegate.window];
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows)
            if (![windows containsObject:window]) [windows addObject:window];
    }
    for (UIWindow *window in windows) {
        if (window.hidden || window.alpha <= .01 || window.windowLevel != UIWindowLevelNormal ||
            CGRectIsEmpty(window.bounds)) continue;
        NSUInteger budget = 256;
        UIView *render = RenderView(window.rootViewController.viewIfLoaded,renderClass,budget);
        if (!render || render.window != window || render.bounds.size.width <= render.bounds.size.height) continue;
        UIResponder *controller = render.nextResponder;
        for (NSUInteger depth = 0; controller && depth < 32; ++depth) {
            if ([controller isKindOfClass:controllerClass]) break;
            controller = controller.nextResponder;
        }
        if (![controller isKindOfClass:controllerClass]) continue;
        Ivar ivar = class_getInstanceVariable(controllerClass,"_displayLink");
        const char *type = ivar ? ivar_getTypeEncoding(ivar) : nullptr;
        if (!type || type[0] != '@') continue;
        id object = object_getIvar(controller,ivar);
        if (![object isKindOfClass:CADisplayLink.class]) continue;
        CADisplayLink *link = object;
        double timestamp = link.timestamp;
        if (!std::isfinite(timestamp) || timestamp <= 0 || CACurrentMediaTime()-timestamp > 1) continue;
        if (window != observedWindow || link != observedLink || timestamp < firstTimestamp) {
            observedWindow = window; observedLink = link; firstTimestamp = timestamp;
            return nil;
        }
        if (timestamp <= firstTimestamp) return nil;
        if (linkOut) *linkOut = link;
        return window;
    }
    observedWindow = nil; observedLink = nil; firstTimestamp = 0;
    return nil;
}
