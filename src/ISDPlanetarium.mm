#import "ISDPlanetarium.h"
#import "ISDHost.h"
#include "ISDPlanetariumPolicy.hpp"
#include "ISDHUDNumericFont.hpp"
#include "IsaacPresentationState.hpp"
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#include <array>
#include <set>

// Independent native implementation of Planetarium Chance's Repentance HUD
// behavior. The Lua mod and its assets are not embedded. Read-only getters
// are called only on the game's main thread after the supported ABI validates.
namespace {
constexpr uintptr_t ManagerGlobal=0xac2428,GameGlobal=0xac3b90,ScreenSize=0xac24d8;
constexpr uintptr_t GetChance=0x6d03a4,IsAvailable=0x73fab0,HasCollectible=0x4eeb74;
constexpr uintptr_t AchievementsBlocked=0x88b5b0;
bool Read(uintptr_t address,void *out,size_t count) {
    vm_size_t copied=0;
    return address && out && count && vm_read_overwrite(mach_task_self(),address,count,
        reinterpret_cast<vm_address_t>(out),&copied)==KERN_SUCCESS && copied==count;
}
template<class T> bool Read(uintptr_t address,T& out) { return Read(address,&out,sizeof(out)); }
template<size_t N> bool Words(uintptr_t base,uintptr_t rva,const std::array<uint32_t,N>& expected) {
    std::array<uint32_t,N> actual{};
    return Read(base+rva,actual) && actual==expected;
}
bool Supported(const mach_header_64 *header) {
    if (!header || header->magic!=MH_MAGIC_64 || header->ncmds>4096 || header->sizeofcmds>1024*1024) return false;
    const uint8_t *at=reinterpret_cast<const uint8_t *>(header+1),*end=at+header->sizeofcmds;
    for (uint32_t i=0;i<header->ncmds;++i) {
        if (at>end || size_t(end-at)<sizeof(load_command)) return false;
        const auto *c=reinterpret_cast<const load_command *>(at);
        if (c->cmdsize<sizeof(*c) || size_t(end-at)<c->cmdsize) return false;
        if (c->cmd==LC_UUID && c->cmdsize==sizeof(uuid_command)) {
            const auto *u=reinterpret_cast<const uuid_command *>(c);
            return [[[[NSUUID alloc] initWithUUIDBytes:u->uuid] UUIDString]
                isEqualToString:@"F4357753-A25F-30EE-BACF-63709F902895"];
        }
        at+=c->cmdsize;
    }
    return false;
}
bool CodeMatches(uintptr_t base) {
    return Words(base,GetChance,std::array<uint32_t,4>{0xd10143ff,0x6d0123e9,0xa90257f6,0xa9034ff4}) &&
        Words(base,IsAvailable,std::array<uint32_t,4>{0xd10143ff,0xa9015ff8,0xa90257f6,0xa9034ff4}) &&
        Words(base,HasCollectible,std::array<uint32_t,4>{0xd10183ff,0xa90167fa,0xa9025ff8,0xa90357f6}) &&
        Words(base,AchievementsBlocked,std::array<uint32_t,4>{0xa9be4ff4,0xa9017bfd,0x910043fd,0xaa0003f3}) &&
        Words(base,0x6ed45c,std::array<uint32_t,2>{0x39574ac8,0x3400db08}) &&
        Words(base,0x6cc3b8,std::array<uint32_t,4>{0xb9006660,0xaa1403e0,0x94028d6c,0xb9006a60}) &&
        Words(base,0x890078,std::array<uint32_t,4>{0x91523408,0x91310100,0xaa0203e1,0x140023f2}) &&
        Words(base,0x89906c,std::array<uint32_t,5>{0x52804049,0x52821a0a,0x11000508,0x12002108,0x9baa4d00}) &&
        Words(base,0x89ebc4,std::array<uint32_t,4>{0xf9401c08,0xb4000088,0xbd405000,0x1e300000});
}
UIView *RenderView(UIView *view,NSUInteger& budget) {
    if (!view || !budget || view.hidden) return nil;
    --budget;
    if ([view isKindOfClass:NSClassFromString(@"AAPLOpenGLView")]) return view;
    for (UIView *child in view.subviews) { UIView *found=RenderView(child,budget); if (found) return found; }
    return nil;
}
NSString *Asset(NSString *relative) {
    for (NSString *root in @[@"repentance-resources",@"afterbirthplus-resources",@"afterbirth-resources",@"rebirth-resources"]) {
        NSString *path=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@/data/%@",root,relative]];
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) return path;
    }
    return nil;
}
void Draw(CGContextRef context,CGImageRef image,CGRect rect) {
    CGContextSaveGState(context);
    CGContextSetInterpolationQuality(context,kCGInterpolationNone);
    CGContextSetShouldAntialias(context,false);
    CGContextTranslateCTM(context,rect.origin.x,rect.origin.y+rect.size.height);
    CGContextScaleCTM(context,1,-1);
    CGContextDrawImage(context,CGRectMake(0,0,rect.size.width,rect.size.height),image);
    CGContextRestoreGState(context);
}
bool NoHUD(uintptr_t game) {
    uintptr_t node=0;
    if (!Read(game+0x25da0,node)) return true;
    // Read-only lower-bound lookup; no seed or RNG routine is invoked.
    for (unsigned depth=0;node && depth<64;++depth) {
        int key=-1; uintptr_t next=0;
        if (!Read(node+0x1c,key) || key<0 || key>200) return true;
        if (key==10) return true; // SEED_NO_HUD
        if (!Read(node+(key<10?8:0),next) || next==node) return true;
        node=next;
    }
    return node!=0;
}
bool TelescopeAvailable(uintptr_t base,uintptr_t manager,bool& available) {
    std::array<uintptr_t,3> span{};
    if (!Read(manager+0x55f30+0x18,span) || !span[0] || (span[0]&7) || span[1]<span[0] ||
        span[2]<span[1] || span[2]-span[0]>4096*8 || (span[1]-span[0])%8 ||
        span[1]-span[0]<=152*8) return false;
    uintptr_t config=0; int id=0,achievement=-3; uint8_t hidden=2;
    if (!Read(span[0]+152*8,config) || !config || !Read(config+4,id) || id!=152 ||
        !Read(config+0x50,achievement) || achievement!=406 || !Read(config+0xb7,hidden) || hidden>1) return false;
    // Same verified availability flags as the game's Spindown lookup.
    // Bit 8 (arbitrary registered callbacks) is intentionally not included.
    available=reinterpret_cast<bool (*)(uintptr_t,uint32_t)>(base+IsAvailable)(config,3);
    return true;
}
bool TreasureRooms(uintptr_t game,bool& found) {
    int count=0; found=false;
    if (!Read(game+0x21510,count) || count<1 || count>512) return false;
    for (int i=0;i<count;++i) {
        uintptr_t data=0; int type=0;
        if (!Read(game+0x18+i*0x100+0x10,data) || !data || !Read(data+8,type) || type<1 || type>29) return false;
        if (type==4) { found=true; break; }
    }
    return true;
}
bool Layout(uintptr_t base,uintptr_t game,uintptr_t manager,IsaacFixes::PlanetariumLayout& layout) {
    std::array<uintptr_t,3> span{};
    if (!Read(game+0x25c50,span) || !span[0] || (span[0]&7) || span[1]<=span[0] ||
        span[2]<span[1] || span[2]-span[0]>16*8 || (span[1]-span[0])%8) return false;
    float offset=0; int challenge=0,daily=0;
    if (!Read(manager+0x55f0c,offset) || !std::isfinite(offset) || offset<0 || offset>1 ||
        !Read(game+0x24f9d8,layout.difficulty) || layout.difficulty<0 || layout.difficulty>3 ||
        !Read(game+0x1cf438,challenge) || !Read(game+0x1cf4c0,daily)) return false;
    layout.offset=offset;
    // Native HUD's seeded/achievement-blocked predicate, plus challenge/daily
    // markers. Unlike the Lua compatibility probe, no machine is spawned.
    layout.achievementsDisabled=challenge!=0 || daily!=0 ||
        reinterpret_cast<bool (*)(uintptr_t)>(base+AchievementsBlocked)(game);
    std::set<uint32_t> controllers;
    for (uintptr_t at=span[0];at<span[1];at+=8) {
        uintptr_t player=0; int entity=0,variant=-1,type=-2; uint32_t controller=0;
        if (!Read(at,player) || !player || !Read(player+0x38,entity) || entity!=1 ||
            !Read(player+0x3c,variant) || variant<0 || variant>1 || !Read(player+0x1738,type) || type<0 || type>40 ||
            !Read(player+0x19ec,controller)) return false;
        if (at==span[0]) layout.jacob=type==19;
        if (variant==0) {
            layout.bombs|=type!=25;
            controllers.insert(controller); // Twins/Strawman share their owner's controller.
        }
        layout.poop|=type==25; layout.redHearts|=type==36; layout.soulHearts|=type==18;
        layout.duality|=reinterpret_cast<bool (*)(uintptr_t,int,bool)>(base+HasCollectible)(player,498,false);
    }
    layout.coop=controllers.size()>1;
    return true;
}
// Stable generation identity, independent of player position, opened doors,
// treasure-room visits, newly created red rooms, ASLR and frame-local RNG.
// The first room's generation seed is initialized by RoomDescriptor's seed
// constructor at 0x6cc398. Read it, never advance its RNG. This distinguishes
// same-stage regenerations (Forget Me Now / R Key) without following visits.
uint64_t FloorIdentity(uintptr_t game,int stage,int stageType,bool ascent) {
    uintptr_t config=0; std::array<uint32_t,3> room{}; int grid=-1; uint32_t generation=0;
    if (!Read(game+0x18+0x10,config) || !config || !Read(config,room) ||
        !Read(game+0x18,grid) || !Read(game+0x18+0x64,generation) || !generation) return 0;
    uint64_t hash=1469598103934665603ull;
    for (uint32_t value:{uint32_t(stage),uint32_t(stageType),uint32_t(ascent),room[0],room[1],room[2],uint32_t(grid),generation})
        hash=(hash^value)*1099511628211ull;
    return hash;
}
NSString *SaveSlot(uintptr_t manager) {
    std::array<uint8_t,24> bytes{};
    if (!Read(manager+0x204d0+0x10,bytes)) return nil;
    std::array<char,256> name{};
    if (bytes[23]&0x80) {
        uintptr_t address=0; uint64_t count=0;
        memcpy(&address,bytes.data(),8); memcpy(&count,bytes.data()+8,8);
        if (!count || count>=name.size() || !Read(address,name.data(),size_t(count))) return nil;
    } else {
        unsigned count=bytes[23]; if (!count || count>=23) return nil;
        memcpy(name.data(),bytes.data(),count);
    }
    NSString *file=[NSString stringWithUTF8String:name.data()].lastPathComponent;
    for (unsigned slot=1;slot<=3;++slot)
        if ([file isEqualToString:[NSString stringWithFormat:@"rep_persistentgamedata%u.dat",slot]]) return file;
    return nil;
}
bool DogmaEntity(uintptr_t entity,bool& flash) {
    std::array<uint8_t,0x1c8> object{};
    if (!Read(entity,object)) return false;
    int type=0,variant=-1; memcpy(&type,object.data()+0x38,4); memcpy(&variant,object.data()+0x3c,4);
    if (type!=950 || variant<0 || variant>2 || !object[0x1c0]) return false;
    uintptr_t animation=0; float frame=0;
    memcpy(&animation,object.data()+0x88,8); memcpy(&frame,object.data()+0xa0,4);
    std::array<uint8_t,24> name{};
    // ANM2::Animation starts with its std::string name. "Death" is a short
    // string, so no unbounded C-string dereference or native call is needed.
    bool death=animation && Read(animation,name) && name[23]==5 && !memcmp(name.data(),"Death",5);
    flash=IsaacFixes::PlanetariumDogmaFlash(13,type,variant,true,death,frame);
    return true;
}
}

@interface ISDPlanetariumFont : NSObject
- (UIImage *)string:(NSString *)text color:(unsigned)color;
@end
@implementation ISDPlanetariumFont {
    IsaacFixes::HUDNumericFont _font;
    NSArray<UIImage *> *_pages;
    NSMutableDictionary<NSString *,UIImage *> *_glyphs;
    NSCache<NSString *,UIImage *> *_strings;
}
- (instancetype)init {
    if (!(self=[super init])) return nil;
    NSString *path=Asset(@"font/luaminioutlined.fnt");
    NSData *data=path?[NSData dataWithContentsOfFile:path]:nil;
    if (!_font.Load(static_cast<const uint8_t *>(data.bytes),data.length)) return nil;
    NSMutableArray *pages=[NSMutableArray array];
    for (const auto& page:_font.pages) {
        NSString *name=[NSString stringWithUTF8String:page.c_str()];
        NSString *file=[path.stringByDeletingLastPathComponent stringByAppendingPathComponent:name.lowercaseString];
        UIImage *image=[UIImage imageWithContentsOfFile:file];
        if (!image.CGImage || CGImageGetWidth(image.CGImage)!=_font.width || CGImageGetHeight(image.CGImage)!=_font.height) return nil;
        [pages addObject:image];
    }
    _pages=pages.copy; _glyphs=[NSMutableDictionary dictionary]; _strings=[NSCache new]; _strings.countLimit=128;
    return self;
}
- (UIImage *)string:(NSString *)text color:(unsigned)color {
    if (!text.length || text.length>16 || color>2) return nil;
    NSString *key=[NSString stringWithFormat:@"%u:%@",color,text]; UIImage *cached=[_strings objectForKey:key];
    if (cached) return cached;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(80,16),NO,1);
    CGContextRef context=UIGraphicsGetCurrentContext(); int x=2; uint32_t previous=0;
    for (NSUInteger i=0;i<text.length;++i) {
        uint32_t code=[text characterAtIndex:i]; auto it=_font.glyphs.find(code);
        if (it==_font.glyphs.end()) continue;
        const auto& g=it->second; x+=_font.Kerning(previous,code); previous=code;
        if (g.w && g.h) {
            NSString *glyphKey=[NSString stringWithFormat:@"%u:%u",color,code]; UIImage *glyph=_glyphs[glyphKey];
            if (!glyph) {
                CGImageRef crop=CGImageCreateWithImageInRect(_pages[g.page].CGImage,CGRectMake(g.x,g.y,g.w,g.h));
                std::vector<uint8_t> pixels(size_t(g.w)*g.h*4,0);
                CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
                CGContextRef bitmap=CGBitmapContextCreate(pixels.data(),g.w,g.h,8,g.w*4,space,
                    kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big); CGColorSpaceRelease(space);
                if (crop && bitmap) {
                    CGContextDrawImage(bitmap,CGRectMake(0,0,g.w,g.h),crop);
                    // Keep the atlas's black outline; tint RGB, not its alpha mask.
                    for (size_t p=0;p<pixels.size();p+=4) {
                        if (color==1) pixels[p]=pixels[p+2]=0;
                        if (color==2) pixels[p+1]=pixels[p+2]=0;
                    }
                    CGImageRef raster=CGBitmapContextCreateImage(bitmap);
                    glyph=[UIImage imageWithCGImage:raster]; CGImageRelease(raster);
                    if (glyph) _glyphs[glyphKey]=glyph;
                }
                if (bitmap) CGContextRelease(bitmap);
                if (crop) CGImageRelease(crop);
            }
            if (glyph) Draw(context,glyph.CGImage,CGRectMake(x+g.dx,g.dy,g.w,g.h));
        }
        x+=g.advance;
    }
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    if (image) [_strings setObject:image forKey:key];
    return image;
}
@end

@implementation ISDPlanetarium {
    uintptr_t _base;
    __weak UIWindow *_window;
    __weak UIView *_render;
    __weak CADisplayLink *_nativeLink;
    CADisplayLink *_display;
    CALayer *_surface,*_icon,*_value,*_delta;
    ISDPlanetariumFont *_font;
    uint32_t _runSeed;
    uint64_t _floor;
    bool _available,_canSpawn,_initialized;
    double _chance;
    CFTimeInterval _lastSnapshot,_lastNativeFrame;
    IsaacFixes::PlanetariumPopup _popup;
    IsaacPresentation::Visibility _presentationVisibility;
    NSString *_slot,*_cacheKey;
    NSMutableDictionary *_cache;
    bool _dogmaEnded;
    std::vector<uintptr_t> _dogma;
    CFTimeInterval _dogmaScan;
}
- (instancetype)init {
    if (!(self=[super init])) return nil;
    for (uint32_t i=0;i<_dyld_image_count();++i) {
        const auto *h=reinterpret_cast<const mach_header_64 *>(_dyld_get_image_header(i));
        if (!Supported(h)) continue;
        uintptr_t base=reinterpret_cast<uintptr_t>(h);
        if (CodeMatches(base) && IsaacPresentation::Validate(base,[](uintptr_t a,void *p,size_t n){ return Read(a,p,n); })) _base=base;
        break;
    }
    ISDLog(@"Planetarium native getter/HUD ABI validation %@",_base?@"passed":@"rejected");
    if (!_base) return self;
    _font=[ISDPlanetariumFont new];
    NSString *sheetPath=Asset(@"gfx/ui/hudstats2.png");
    UIImage *sheet=sheetPath?[UIImage imageWithContentsOfFile:sheetPath]:nil;
    if (!_font || !sheet.CGImage || CGImageGetWidth(sheet.CGImage)<16 || CGImageGetHeight(sheet.CGImage)<48) {
        ISDLog(@"Planetarium HUD disabled: original game font/sprite unavailable"); _base=0; return self;
    }
    _surface=[CALayer layer]; _surface.hidden=YES; _surface.masksToBounds=YES;
    for (unsigned i=0;i<3;++i) {
        CALayer *layer=[CALayer layer]; layer.minificationFilter=kCAFilterNearest; layer.magnificationFilter=kCAFilterNearest;
        layer.contentsGravity=kCAGravityResize; layer.opacity=.5;
        if (i==0) _icon=layer; else if (i==1) _value=layer; else _delta=layer;
        [_surface addSublayer:layer];
    }
    // hudstats2.anm2: Idle frame 8 is (0,32,16,16), pivot (0,0).
    CGImageRef icon=CGImageCreateWithImageInRect(sheet.CGImage,CGRectMake(0,32,16,16));
    _icon.contents=(__bridge id)icon; CGImageRelease(icon);
    NSDictionary *saved=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"IsaacFixes.Planetarium.v1"];
    _cache=saved?saved.mutableCopy:[NSMutableDictionary dictionary];
    if (_cache.count>24) [_cache removeAllObjects];
    _display=[CADisplayLink displayLinkWithTarget:self selector:@selector(frame:)];
    [_display addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    return self;
}
- (void)suspend {
    [CATransaction begin]; [CATransaction setDisableActions:YES]; _surface.hidden=YES; [CATransaction commit];
    _window=nil;
}
- (void)remember {
    if (!_cacheKey) return;
    if (_cache.count>=24 && !_cache[_cacheKey]) [_cache removeAllObjects];
    _cache[_cacheKey]=@{@"chance":@(_chance),@"available":@(_available),@"canSpawn":@(_canSpawn)};
    // Mod-only cache, never Isaac save/options files or Steam Cloud data.
    [NSUserDefaults.standardUserDefaults setObject:_cache forKey:@"IsaacFixes.Planetarium.v1"];
}
- (BOOL)snapshot:(uintptr_t)game manager:(uintptr_t)manager seed:(uint32_t)seed {
    int stage=0,type=0; uint64_t flags=0;
    if (!Read(game,stage) || stage<1 || stage>13 || !Read(game+4,type) || type<0 || type>5 || !Read(game+0x1cf400,flags)) return NO;
    bool ascent=flags&(1ull<<48); uint64_t floor=FloorIdentity(game,stage,type,ascent);
    if (!floor) return NO;
    NSString *slot=SaveSlot(manager);
    bool initial=!_initialized || _runSeed!=seed || !(slot==_slot || [_slot isEqual:slot]);
    if (!initial && _floor==floor) return YES;
    bool available=false;
    if (!TelescopeAvailable(_base,manager,available)) return NO;
    NSString *key=slot?[NSString stringWithFormat:@"%@:%08x:%016llx",slot,seed,(unsigned long long)floor]:nil;
    NSDictionary *saved=initial && key?_cache[key]:nil;
    if (![saved isKindOfClass:NSDictionary.class]) saved=nil;
    // The original rechecks the unlock on init as well as on a new floor.
    bool newlyAvailable=saved && [saved[@"available"] isKindOfClass:NSNumber.class] &&
        ![saved[@"available"] boolValue] && available;
    if (newlyAvailable) saved=nil;
    double before=_chance;
    if (initial || stage==1) { _dogmaEnded=false; _dogma.clear(); _dogmaScan=0; }
    if (saved && [saved[@"chance"] isKindOfClass:NSNumber.class] &&
        [saved[@"available"] isKindOfClass:NSNumber.class] && [saved[@"canSpawn"] isKindOfClass:NSNumber.class] &&
        std::isfinite([saved[@"chance"] doubleValue]) && [saved[@"chance"] doubleValue]>=0 && [saved[@"chance"] doubleValue]<=100) {
        _chance=[saved[@"chance"] doubleValue]; _available=[saved[@"available"] boolValue]; _canSpawn=[saved[@"canSpawn"] boolValue];
    } else {
        if (initial) {
            bool treasure=false;
            if (!TreasureRooms(game,treasure)) return NO;
            _available=available; _canSpawn=available && treasure;
            // Installing during a later floor is equivalent to original mod's
            // Continue fallback; the run's initial Treasure floor isn't known.
            if (stage>1) _canSpawn=available;
            if (newlyAvailable) _canSpawn=true;
        } else if (!_available && available) { _available=true; _canSpawn=true; }
        float chance=reinterpret_cast<float (*)(uintptr_t)>(_base+GetChance)(game);
        if (!std::isfinite(chance)) return NO;
        _chance=IsaacFixes::PlanetariumPercent(chance,_canSpawn,ascent);
    }
    _popup.Change(before,_chance,initial); _floor=floor; _runSeed=seed; _initialized=true; _slot=slot; _cacheKey=key;
    [self remember];
    ISDLog(@"Planetarium floor snapshot: stage=%d type=%d ascent=%d chance=%.1f%% available=%d canSpawn=%d cache=%d",
        stage,type,ascent,_chance,_available,_canSpawn,saved!=nil);
    return YES;
}
- (BOOL)dogmaFlash:(uintptr_t)game now:(CFTimeInterval)now {
    if (_dogmaEnded) return YES;
    int stage=0;
    if (!Read(game,stage) || stage!=13) return NO;
    if (now-_dogmaScan>=.25) {
        _dogmaScan=now; _dogma.clear(); uintptr_t entities=0;
        if (Read(game+0x1cf430,entities) && entities) {
            // Native EntityManager's fixed NPC arena: 512 x 0x10d0, at
            // +0x48dc40 (allocation branch 0x890078, bounds 0x89906c).
            // Only inspect live Dogma boss variants. No allocator is called.
            for (unsigned i=0;i<512;++i) {
                uintptr_t npc=entities+0x48dc40+i*0x10d0;
                bool flash=false;
                if (DogmaEntity(npc,flash)) {
                    _dogma.push_back(npc);
                    if (flash) _dogmaEnded=true;
                }
            }
        }
    }
    for (uintptr_t npc:_dogma) {
        bool flash=false;
        if (DogmaEntity(npc,flash) && flash) _dogmaEnded=true;
    }
    return _dogmaEnded;
}
- (void)frame:(CADisplayLink *)link {
    (void)link;
    if (!_base || !_window || _window.hidden || !_render.window || !_nativeLink ||
        CACurrentMediaTime()-_nativeLink.timestamp>.1 || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) {
        _surface.hidden=YES; return;
    }
    uintptr_t manager=0,game=0,room=0,descriptor=0,config=0; uint32_t state=0,seed=0;
    uint8_t pending=1,hud=0,found=0; float fade=1; int pause=-1,roomStage=0,roomType=0;
    if (!Read(_base+ManagerGlobal,manager) || !manager || !Read(manager+0x204c0,state) ||
        !Read(_base+GameGlobal,game) || !game) { _surface.hidden=YES; return; }
    IsaacPresentation::State presentation;
    bool captured=IsaacPresentation::Capture(_base,[](uintptr_t a,void *p,size_t n){ return Read(a,p,n); },presentation);
    bool visible=_presentationVisibility.Observe(presentation,captured,false,false,CACurrentMediaTime());
    if (state!=2) { _initialized=false; _surface.hidden=YES; return; }
    if (!visible) { _surface.hidden=YES; return; }
    if (!Read(manager+0x1f6b40,pending) || pending || !Read(game+0x1cf444,fade) || !std::isfinite(fade) || fade!=0 ||
        !Read(game+0x21550,room) || !room || !Read(game+0x25d44,seed) || !seed ||
        !Read(game+0x10dfd8,pause) || !IsaacFixes::PlanetariumUnpaused(pause)) { _surface.hidden=YES; return; }
    // Check pause before the native-frame guard, even if rendering stops in a
    // menu. Keep the floor snapshot and freeze any delta popup until resume.
    if (_lastNativeFrame==_nativeLink.timestamp) return;
    _lastNativeFrame=_nativeLink.timestamp;
    CFTimeInterval now=CACurrentMediaTime();
    if (now-_lastSnapshot>=.05) {
        _lastSnapshot=now;
        if (![self snapshot:game manager:manager seed:seed]) { _surface.hidden=YES; return; }
    }
    BOOL dogmaFlash=[self dogmaFlash:game now:now];
    std::array<float,2> screen{},shake{}; IsaacFixes::PlanetariumLayout layout;
    if (!_initialized || !Read(manager+0x55f02,found) || !found || !Read(game+0x10d45a,hud) || !hud || NoHUD(game) ||
        !Read(room+8,descriptor) || !descriptor || !Read(descriptor+0x10,config) || !config ||
        !Read(config,roomStage) || !Read(config+8,roomType) || (roomType==16 && roomStage==35) || dogmaFlash ||
        !Layout(_base,game,manager,layout) || !Read(_base+ScreenSize,screen) || !Read(game+0x1af360,shake) ||
        !std::isfinite(screen[0]) || !std::isfinite(screen[1]) || screen[0]<320 || screen[0]>4096 || screen[1]<200 || screen[1]>4096 ||
        !std::isfinite(shake[0]) || !std::isfinite(shake[1]) || std::abs(shake[0])>100 || std::abs(shake[1])>100) {
        _surface.hidden=YES; return;
    }
    CGSize view=_render.bounds.size; CGFloat scale=std::min(view.width/screen[0],view.height/screen[1]);
    if (!std::isfinite(scale) || scale<=0) { _surface.hidden=YES; return; }
    auto origin=IsaacFixes::PlanetariumPosition(layout);
    CGFloat x=(view.width-screen[0]*scale)*.5+origin.x*scale;
    CGFloat y=(view.height-screen[1]*scale)*.5+origin.y*scale;
    [CATransaction begin]; [CATransaction setDisableActions:YES];
    _surface.frame=_render.bounds; _surface.hidden=NO;
    _icon.frame=CGRectMake(x,y,16*scale,16*scale);
    _value.frame=CGRectMake(x+(16-2+shake[0])*scale,y+(1+shake[1])*scale,80*scale,16*scale);
    _value.contents=(__bridge id)[_font string:[NSString stringWithFormat:@"%.1f%%",_chance] color:0].CGImage;
    _delta.hidden=_popup.Alpha()<=0 || _popup.difference==0;
    if (!_delta.hidden) {
        _delta.opacity=_popup.Alpha();
        _delta.frame=CGRectMake(x+(46-2+shake[0]+_popup.Slide())*scale,y+(1+shake[1])*scale,80*scale,16*scale);
        _delta.contents=(__bridge id)[_font string:[NSString stringWithFormat:@"%+.1f%%",_popup.difference]
            color:_popup.difference>0?1:2].CGImage;
        _popup.Advance();
    }
    [CATransaction commit];
}
- (void)tickWithWindow:(UIWindow *)window displayLink:(CADisplayLink *)link {
    if (!_base || !NSThread.isMainThread) return;
    _window=window; _nativeLink=link;
    if (_render.window!=window) {
        NSUInteger budget=256; _render=RenderView(window.rootViewController.viewIfLoaded,budget);
        [_surface removeFromSuperlayer]; if (_render) [_render.layer addSublayer:_surface];
    }
}
@end
