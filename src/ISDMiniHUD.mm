#import "ISDMiniHUD.h"
#import "ISDHost.h"
#include "ISDMiniHUDPolicy.hpp"
#include "IsaacPresentationState.hpp"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#include <array>
#include <cstring>
#include <map>
#include <memory>
#include <vector>

// Mini normally rasterizes a 32px icon into 16 game pixels, then enlarges
// those 16 pixels with the rest of the scene. Sampling cannot recover the
// discarded texels. Route only that exact native call to a display-density
// layer, using the unmodified PNG from the user's own game installation.
namespace {
constexpr uintptr_t ManagerGlobal=0xac2428, GameGlobal=0xac3b90;
constexpr uintptr_t ExtraHUD=0x55f08, Inventory=0x10dcc8, ScreenSize=0xac24d8;
constexpr uintptr_t NativeDraw=0x8b49d4, MiniReturn=0x6ef998;
constexpr uintptr_t CopyImageRef=0x16b0c, ReleaseImageRef=0x145cc;
using IsaacFixes::HUDQuad; using IsaacFixes::HUDSource; using IsaacFixes::HUDColor;
struct ImageRef { uintptr_t image=0, owner=0; };
struct HUDImage { ImageRef ref; int id=0; };
using CopyRef=void (*)(ImageRef *,uintptr_t,uintptr_t,bool);
using ReleaseRef=void (*)(ImageRef *);
using Draw=void *(*)(uintptr_t,const HUDSource *,const HUDQuad *,const HUDColor *);
struct Hook {
    ImageRef ref;
    uintptr_t original=0;
    // Itanium ABI: offset-to-top, RTTI, and all 38 verified image methods.
    std::array<uintptr_t,40> table{};
    __strong UIImage *icon=nil;
    uintptr_t address() const { return reinterpret_cast<uintptr_t>(table.data()+2); }
};
uintptr_t Base=0;

bool Read(uintptr_t address,void *out,size_t count) {
    vm_size_t copied=0;
    return address && out && count && vm_read_overwrite(mach_task_self(),address,count,
        reinterpret_cast<vm_address_t>(out),&copied)==KERN_SUCCESS && copied==count;
}
bool Writable(uintptr_t address,size_t count) {
    vm_address_t region=address; vm_size_t length=0;
    vm_region_basic_info_data_64_t info{};
    mach_msg_type_number_t size=VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object=MACH_PORT_NULL;
    auto result=vm_region_64(mach_task_self(),&region,&length,VM_REGION_BASIC_INFO_64,
        reinterpret_cast<vm_region_info_t>(&info),&size,&object);
    if (object!=MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),object);
    return result==KERN_SUCCESS && region<=address && address-region<=length &&
        count<=length-(address-region) && (info.protection&VM_PROT_WRITE) && !(info.protection&VM_PROT_EXECUTE);
}
template<size_t N> bool Words(uintptr_t base,uintptr_t rva,const std::array<uint32_t,N>& expected) {
    std::array<uint32_t,N> actual{};
    return Read(base+rva,actual.data(),sizeof(actual)) && actual==expected;
}
bool Supported(const mach_header_64 *header) {
    if (!header || header->magic!=MH_MAGIC_64 || header->ncmds>4096 || header->sizeofcmds>1024*1024) return false;
    const uint8_t *cursor=reinterpret_cast<const uint8_t *>(header+1), *end=cursor+header->sizeofcmds;
    for (uint32_t i=0;i<header->ncmds;++i) {
        if (cursor>end || size_t(end-cursor)<sizeof(load_command)) return false;
        auto *cmd=reinterpret_cast<const load_command *>(cursor);
        if (cmd->cmdsize<sizeof(*cmd) || size_t(end-cursor)<cmd->cmdsize) return false;
        if (cmd->cmd==LC_UUID && cmd->cmdsize==sizeof(uuid_command)) {
            auto *uuid=reinterpret_cast<const uuid_command *>(cmd);
            return [[[[NSUUID alloc] initWithUUIDBytes:uuid->uuid] UUIDString]
                    isEqualToString:@"F4357753-A25F-30EE-BACF-63709F902895"];
        }
        cursor+=cmd->cmdsize;
    }
    return false;
}
bool CodeMatches(uintptr_t base) {
    return Words(base,0x6ed674,std::array<uint32_t,5>{0x71000a7f,0x1a9f17e2,0x910943e1,0xaa1403e0,0x940007ec}) &&
        Words(base,0x6ef928,std::array<uint32_t,4>{0x9100c3e0,0x1e261000,0x1e261001,0x14000009}) &&
        Words(base,0x6ef980,std::array<uint32_t,7>{0xf9400008,0xf9402108,0x910203e1,0x910183e2,0xd10243a3,0xd63f0100,0xb4000220}) &&
        Words(base,NativeDraw,std::array<uint32_t,7>{0xf9400008,0xf9402507,0xaa0303e4,0xaa0303e5,0xaa0303e6,0xd61f00e0,0xd101c3ff}) &&
        Words(base,CopyImageRef,std::array<uint32_t,4>{0xa9bd57f6,0xa9014ff4,0xa9027bfd,0x910083fd}) &&
        Words(base,ReleaseImageRef,std::array<uint32_t,4>{0xa9be4ff4,0xa9017bfd,0x910043fd,0xaa0003f3});
}
bool NativeTable(uintptr_t table) {
    return table==Base+0xa915d0 || table==Base+0xa92350 || table==Base+0xa93030;
}
bool Resident32(uintptr_t image,uintptr_t table) {
    std::array<uint8_t,0xd0> bytes{};
    if (!NativeTable(table) || !Read(image,bytes.data(),bytes.size())) return false;
    uint32_t texture=0; memcpy(&texture,bytes.data()+0xb8,4);
    unsigned width=0,height=0;
    if (table==Base+0xa915d0) {
        uint16_t w=0,h=0; memcpy(&w,bytes.data()+0xc0,2); memcpy(&h,bytes.data()+0xc2,2);
        width=w; height=h;
    } else { memcpy(&width,bytes.data()+0xc0,4); memcpy(&height,bytes.data()+0xc4,4); }
    return (bytes[0x10]&1) && texture && width==32 && height==32;
}
bool Images(uintptr_t game,std::map<uintptr_t,HUDImage>& images) {
    for (unsigned player=0;player<2;++player) {
        std::array<uintptr_t,3> span{};
        if (!Read(game+Inventory+player*0x28+0x10,span.data(),sizeof(span))) return false;
        if (!span[0] && !span[1] && !span[2]) continue;
        if (!IsaacFixes::ValidHUDSpan(span[0],span[1],span[2])) return false;
        for (uintptr_t at=span[0];at<span[1];at+=0x38) {
            HUDImage record;
            if (!Read(at,&record.id,4) || !Read(at+8,&record.ref,sizeof(record.ref))) return false;
            // Procedural/glitched art and special native shader IDs retain
            // their complete native rendering; never substitute a guessed PNG.
            if (record.id>0 && record.id<=732 && record.id!=633 && record.ref.image && record.ref.owner)
                images.emplace(record.ref.image,record);
        }
    }
    return true;
}
UIView *RenderView(UIView *root,NSUInteger& budget) {
    if (!root || !budget || root.hidden) return nil;
    --budget;
    if ([root isKindOfClass:NSClassFromString(@"AAPLOpenGLView")]) return root;
    for (UIView *child in root.subviews) { UIView *found=RenderView(child,budget); if (found) return found; }
    return nil;
}
}

@interface ISDHUDCatalog : NSObject <NSXMLParserDelegate>
@property(nonatomic,strong) NSMutableDictionary<NSNumber *,NSString *> *filenames;
- (UIImage *)icon:(int)item;
@end
@implementation ISDHUDCatalog
- (instancetype)init {
    if (!(self=[super init])) return nil;
    _filenames=[NSMutableDictionary dictionary];
    for (NSString *root in @[@"rebirth-resources",@"afterbirth-resources",@"afterbirthplus-resources",@"repentance-resources"]) {
        NSURL *url=[NSURL fileURLWithPath:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
            [root stringByAppendingPathComponent:@"data/items.xml"]]];
        NSXMLParser *parser=[[NSXMLParser alloc] initWithContentsOfURL:url];
        parser.delegate=self; parser.shouldResolveExternalEntities=NO; [parser parse];
    }
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name namespaceURI:(NSString *)uri
 qualifiedName:(NSString *)qualified attributes:(NSDictionary<NSString *,NSString *> *)attributes {
    (void)parser; (void)uri; (void)qualified;
    if (![@[@"active",@"passive",@"familiar"] containsObject:name]) return;
    NSInteger item=attributes[@"id"].integerValue;
    NSString *gfx=attributes[@"gfx"].lowercaseString;
    if (item>0 && item<=732 && gfx.length && [gfx.lastPathComponent isEqualToString:gfx])
        self.filenames[@(item)]=gfx;
}
- (UIImage *)icon:(int)item {
    NSString *filename=self.filenames[@(item)]; if (!filename) return nil;
    for (NSString *root in @[@"repentance-resources",@"afterbirthplus-resources",@"afterbirth-resources",@"rebirth-resources"]) {
        NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@/data/gfx/items/collectibles/%@",root,filename]];
        UIImage *icon=[UIImage imageWithContentsOfFile:path];
        if (icon.CGImage && CGImageGetWidth(icon.CGImage)==32 && CGImageGetHeight(icon.CGImage)==32) return icon;
    }
    return nil;
}
@end

@interface ISDMiniHUD ()
- (BOOL)prepareImage:(uintptr_t)image source:(const HUDSource *)source destination:(const HUDQuad *)dest color:(const HUDColor *)color;
@end
static __weak ISDMiniHUD *Adapter;
static void *MiniDraw(uintptr_t image,const HUDSource *source,const HUDQuad *dest,const HUDColor *color) {
    auto original=reinterpret_cast<Draw>(Base+NativeDraw);
    // Other draws of the same cached image (pedestals, EID, normal HUD,
    // pause menus, etc.) remain byte-for-byte on the original native path.
    uintptr_t caller=reinterpret_cast<uintptr_t>(__builtin_return_address(0));
    ISDMiniHUD *adapter=Adapter;
    if (caller==Base+MiniReturn && NSThread.isMainThread && adapter &&
        [adapter prepareImage:image source:source destination:dest color:color]) {
        HUDColor transparent=*color; transparent.a=0;
        return original(image,source,dest,&transparent);
    }
    return original(image,source,dest,color);
}

@implementation ISDMiniHUD {
    std::map<uintptr_t,std::unique_ptr<Hook>> _hooks;
    // Keep unknown third-party vptr chains alive instead of freeing tables
    // that another adapter might still reference. Normal removals restore first.
    std::vector<std::unique_ptr<Hook>> _quarantine;
    ISDHUDCatalog *_catalog;
    NSCache<NSNumber *,UIImage *> *_icons;
    NSMutableSet<NSNumber *> *_missing;
    NSMutableArray<CALayer *> *_layers;
    NSMutableArray<NSNumber *> *_seen;
    CALayer *_surface;
    __weak UIView *_render;
    __weak UIWindow *_window;
    __weak CADisplayLink *_nativeLink;
    CADisplayLink *_cleanup;
    CFTimeInterval _lastPoll,_frame;
    std::array<float,2> _screen;
    NSUInteger _drawCount;
    BOOL _logged;
    IsaacPresentation::Visibility _presentationVisibility;
}
- (instancetype)init {
    if (!(self=[super init])) return nil;
    for (uint32_t i=0;i<_dyld_image_count();++i) {
        const auto *header=reinterpret_cast<const mach_header_64 *>(_dyld_get_image_header(i));
        if (!Supported(header)) continue;
        uintptr_t base=reinterpret_cast<uintptr_t>(header);
        if (CodeMatches(base) && IsaacPresentation::Validate(base,[](uintptr_t a,void *p,size_t n){ return Read(a,p,n); })) Base=base;
        break;
    }
    ISDLog(@"Mini HUD display-density adapter validation %@; no sampler changes",Base?@"passed":@"rejected");
    if (Base) {
        Adapter=self; _icons=[NSCache new]; _icons.countLimit=256;
        _missing=[NSMutableSet set]; _layers=[NSMutableArray array]; _seen=[NSMutableArray array];
        _cleanup=[CADisplayLink displayLinkWithTarget:self selector:@selector(cleanupFrame:)];
        [_cleanup addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
    return self;
}
- (void)suspend {
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _surface.hidden=YES; [CATransaction commit];
}
- (BOOL)context:(uintptr_t *)gameOut {
    IsaacPresentation::State presentation;
    bool captured=IsaacPresentation::Capture(Base,[](uintptr_t a,void *p,size_t n){ return Read(a,p,n); },presentation);
    if (!_presentationVisibility.Observe(presentation,captured,false,false,CACurrentMediaTime())) return NO;
    uintptr_t manager=0,game=0,room=0; int mode=-1,pause=-1; uint32_t seed=0;
    uint32_t state=0; uint8_t pending=1; float fade=1;
    if (!Read(Base+ManagerGlobal,&manager,8) || !manager || !Read(manager+ExtraHUD,&mode,4) || mode!=2 ||
        !Read(Base+GameGlobal,&game,8) || !game || !Read(game+0x21550,&room,8) || !room ||
        !Read(game+0x25d44,&seed,4) || !seed || !Read(game+0x10dfd8,&pause,4) || pause!=0 ||
        !Read(manager+0x204c0,&state,4) || state!=2 ||
        !Read(manager+0x1f6b40,&pending,1) || pending ||
        !Read(game+0x1cf444,&fade,4) || !std::isfinite(fade) || fade!=0 ||
        UIApplication.sharedApplication.applicationState!=UIApplicationStateActive ||
        !_window || _window.hidden || _window.rootViewController.presentedViewController) return NO;
    if (gameOut) *gameOut=game;
    return YES;
}
- (void)cleanupFrame:(CADisplayLink *)link {
    (void)link;
    if (![self context:nullptr] || !_nativeLink || CACurrentMediaTime()-_nativeLink.timestamp>.1) { [self suspend]; return; }
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    for (NSUInteger i=0;i<_layers.count;++i)
        if (_seen[i].doubleValue!=_nativeLink.timestamp) _layers[i].hidden=YES;
    [CATransaction commit];
}
- (BOOL)prepareImage:(uintptr_t)image source:(const HUDSource *)source destination:(const HUDQuad *)dest color:(const HUDColor *)color {
    auto found=_hooks.find(image);
    UIView *render=_render; CADisplayLink *link=_nativeLink;
    if (found==_hooks.end() || !render.window || !link) return NO;
    if (_frame!=link.timestamp) {
        if (![self context:nullptr] || !Read(Base+ScreenSize,_screen.data(),sizeof(_screen))) return NO;
        _frame=link.timestamp; _drawCount=0;
    }
    // These are the verified native caller's live stack arguments. Copy them
    // locally; do not perform per-icon Mach syscalls or mutate that stack.
    HUDSource src{}; HUDQuad dst{}; HUDColor rgba{};
    memcpy(&src,source,sizeof(src)); memcpy(&dst,dest,sizeof(dst)); memcpy(&rgba,color,sizeof(rgba));
    IsaacFixes::HUDRect rect{};
    if (!IsaacFixes::MiniDisplayRect(2,src,dst,rgba,_screen[0],_screen[1],
        render.bounds.size.width,render.bounds.size.height,rect)) return NO;
    CGFloat density=render.window.screen.scale;
    if (!std::isfinite(density) || rect.width*density<32) return NO;
    if (_drawCount>=512) return NO;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    _surface.frame=render.bounds; _surface.hidden=NO;
    NSUInteger index=_drawCount++;
    if (index==_layers.count) {
        CALayer *layer=[CALayer layer]; layer.magnificationFilter=kCAFilterNearest;
        layer.minificationFilter=kCAFilterNearest; layer.contentsGravity=kCAGravityResize;
        layer.contentsScale=density; layer.actions=@{@"contents":NSNull.null};
        [_surface addSublayer:layer]; [_layers addObject:layer]; [_seen addObject:@0];
    }
    CALayer *layer=_layers[index];
    layer.contents=(__bridge id)found->second->icon.CGImage;
    layer.frame=CGRectMake(rect.x,rect.y,rect.width,rect.height);
    layer.opacity=rgba.a; layer.hidden=NO; _seen[index]=@(_frame);
    [CATransaction commit];
    if (!_logged) {
        _logged=YES;
        ISDLog(@"Mini HUD full-source draw active: 32x32 PNG -> %.1fx%.1f display pixels; native %.0fx%.0f view %.0fx%.0f",
            rect.width*density,rect.height*density,_screen[0],_screen[1],render.bounds.size.width,render.bounds.size.height);
    }
    return YES;
}
- (void)removeHook:(Hook&)hook {
    uintptr_t expected=hook.address();
    if (Writable(hook.ref.image,8) && __atomic_compare_exchange_n(reinterpret_cast<uintptr_t *>(hook.ref.image),
        &expected,hook.original,false,__ATOMIC_RELEASE,__ATOMIC_RELAXED)) {
        reinterpret_cast<ReleaseRef>(Base+ReleaseImageRef)(&hook.ref); hook.ref={};
    }
}
- (void)tickWithWindow:(UIWindow *)window displayLink:(CADisplayLink *)link {
    if (!Base || !NSThread.isMainThread) return;
    _window=window; _nativeLink=link;
    if (_render.window!=window) {
        NSUInteger budget=256; _render=RenderView(window.rootViewController.viewIfLoaded,budget);
        [_surface removeFromSuperlayer]; _surface=[CALayer layer]; _surface.masksToBounds=YES;
        _surface.actions=@{@"hidden":NSNull.null,@"bounds":NSNull.null,@"position":NSNull.null};
        [_render.layer addSublayer:_surface]; [_layers removeAllObjects]; [_seen removeAllObjects]; _frame=0;
    }
    CFTimeInterval now=CACurrentMediaTime(); if (now-_lastPoll<.2) return; _lastPoll=now;
    uintptr_t game=0; std::map<uintptr_t,HUDImage> current;
    if ([self context:&game] && !Images(game,current)) { [self suspend]; return; }
    for (auto it=_hooks.begin();it!=_hooks.end();) {
        if (current.count(it->first)) { ++it; continue; }
        [self removeHook:*it->second];
        if (it->second->ref.image) _quarantine.push_back(std::move(it->second));
        it=_hooks.erase(it);
    }
    if (current.empty()) { [self suspend]; return; }
    if (!_catalog) _catalog=[ISDHUDCatalog new];
    size_t attached=0;
    for (const auto& entry:current) {
        if (_hooks.count(entry.first) || _hooks.size()+_quarantine.size()>=1024) continue;
        const HUDImage& candidate=entry.second;
        uintptr_t table=0;
        if (!Read(candidate.ref.image,&table,8) || !Resident32(candidate.ref.image,table) || !Writable(candidate.ref.image,8)) continue;
        NSNumber *key=@(candidate.id);
        if ([_missing containsObject:key]) continue;
        UIImage *icon=[_icons objectForKey:key];
        if (!icon) { icon=[_catalog icon:candidate.id]; if (icon) [_icons setObject:icon forKey:key]; }
        if (!icon) { [_missing addObject:key]; continue; }
        auto hook=std::make_unique<Hook>(); hook->original=table; hook->icon=icon;
        if (!Read(table-16,hook->table.data(),sizeof(hook->table)) || hook->table[0] || !hook->table[1] ||
            hook->table[2+8]!=Base+NativeDraw) continue;
        bool valid=true;
        for (size_t i=2;i<hook->table.size();++i)
            if (hook->table[i]<Base+0x4000 || hook->table[i]>=Base+0x904000) valid=false;
        if (!valid) continue;
        reinterpret_cast<CopyRef>(Base+CopyImageRef)(&hook->ref,candidate.ref.image,candidate.ref.owner,false);
        if (hook->ref.image!=candidate.ref.image || hook->ref.owner!=candidate.ref.owner) continue;
        hook->table[2+8]=reinterpret_cast<uintptr_t>(&MiniDraw);
        uintptr_t expected=table;
        if (!__atomic_compare_exchange_n(reinterpret_cast<uintptr_t *>(candidate.ref.image),&expected,
            hook->address(),false,__ATOMIC_RELEASE,__ATOMIC_RELAXED)) {
            reinterpret_cast<ReleaseRef>(Base+ReleaseImageRef)(&hook->ref); continue;
        }
        _hooks.emplace(candidate.ref.image,std::move(hook));
        ++attached;
    }
    if (attached) ISDLog(@"Mini HUD individual-image adapters attached: %zu; missing PNG fallbacks: %lu",
        attached,(unsigned long)_missing.count);
}
@end
