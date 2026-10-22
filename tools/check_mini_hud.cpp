#include "ISDMiniHUDPolicy.hpp"
#include <cassert>
#include <cstdio>
int main() {
    using namespace IsaacFixes;
    ImageSampling image{0,0,32,32,true,2};
    assert(ValidImageSampling(image));
    image.magnification = 1; assert(ValidImageSampling(image));
    image.colorFormat = 0; assert(ValidImageSampling(image));
    image.colorFormat = 1; assert(ValidImageSampling(image));
    image.colorFormat = 2;
    image.minification = 1; assert(ValidImageSampling(image));
    image.minification = 2; assert(!ValidImageSampling(image));
    image.minification = 0; image.magnification = -1; assert(!ValidImageSampling(image));
    image.magnification = 0; image.resident = false; assert(ValidImageSampling(image));
    image.resident = true; image.width = 4097; assert(!ValidImageSampling(image));
    image.width = 32; image.height = 0; assert(!ValidImageSampling(image));
    image.height = 32; image.colorFormat = 3; assert(!ValidImageSampling(image));
    assert(ValidHUDSpan(0x1000,0x1000,0x1000));
    assert(ValidHUDSpan(0x1000,0x1038,0x1070));
    assert(!ValidHUDSpan(0,0,0)); assert(!ValidHUDSpan(0x1001,0x1039,0x1071));
    assert(!ValidHUDSpan(0x1000,0xff8,0x1000));
    assert(!ValidHUDSpan(0x1000,0x1038,0x1000));
    assert(!ValidHUDSpan(0x1000,0x1037,0x1070));
    assert(!ValidHUDSpan(0x1000,0x1038,0x1000+2049*0x38));
    HUDSource source{{{0,0,32,0,0,32,32,32}},0};
    HUDQuad destination{{590,80,606,80,590,96,606,96}};
    HUDColor color{1,1,1,.5}; HUDRect rect{};
    assert(MiniDisplayRect(2,source,destination,color,640,360,1280,720,rect));
    assert(Near(rect.x,1180) && Near(rect.y,160) && Near(rect.width,32) && Near(rect.height,32));
    assert(!MiniDisplayRect(1,source,destination,color,640,360,1280,720,rect));
    assert(MiniDisplayRect(2,source,destination,color,640,360,1280,800,rect));
    assert(Near(rect.x,1180) && Near(rect.y,200)); // Letterbox, no stretched icons.
    source.flags=1; assert(!MiniDisplayRect(2,source,destination,color,640,360,1280,720,rect)); source.flags=0;
    source.quad.xy[2]=16; assert(!MiniDisplayRect(2,source,destination,color,640,360,1280,720,rect)); source.quad.xy[2]=32;
    destination.xy[2]=607; assert(!MiniDisplayRect(2,source,destination,color,640,360,1280,720,rect)); destination.xy[2]=606;
    color.r=.4; assert(!MiniDisplayRect(2,source,destination,color,640,360,1280,720,rect)); color.r=1;
    color.a=0; assert(!MiniDisplayRect(2,source,destination,color,640,360,1280,720,rect)); color.a=.5;
    assert(!MiniDisplayRect(2,source,destination,color,640,0,1280,720,rect));
    assert(!MiniDisplayRect(2,source,destination,color,640,360,NAN,720,rect));
    assert(!MiniDisplayRect(2,source,destination,color,640,360,0,720,rect));
    destination.xy[1]=NAN; assert(!MiniDisplayRect(2,source,destination,color,640,360,1280,720,rect));
    static_assert(sizeof(HUDQuad)==32 && sizeof(HUDSource)==36 && sizeof(HUDColor)==16,"Native draw ABI");
    puts("Mini HUD policy passed: native quad ABI, exact Mini-only draws, aspect-fit positioning, tint/source/fallback guards");
}
