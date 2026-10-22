#pragma once
#include <cstdint>
#include <cmath>

namespace IsaacFixes {
struct ImageSampling {
    int minification, magnification;
    unsigned width, height;
    bool resident;
    unsigned colorFormat;
};
inline bool ValidImageSampling(const ImageSampling& image) {
    // Observation only. Nearest is 0 and linear is 1; neither is changed.
    return image.width > 0 && image.width <= 4096 && image.height > 0 && image.height <= 4096 &&
        image.colorFormat <= 2 && (image.minification == 0 || image.minification == 1) &&
        (image.magnification == 0 || image.magnification == 1);
}
inline bool ValidHUDSpan(uintptr_t begin, uintptr_t end, uintptr_t capacity) {
    return begin && !(begin & 7) && end >= begin && capacity >= end &&
        capacity-begin <= 2048*0x38 && !((end-begin)%0x38) && !((capacity-begin)%0x38);
}

struct HUDQuad { float xy[8]; };
struct HUDSource { HUDQuad quad; uint32_t flags; };
struct HUDColor { float r,g,b,a; };
struct HUDRect { double x,y,width,height; };
inline bool Near(double a, double b) { return std::isfinite(a) && std::abs(a-b) < .01; }
inline bool AxisAligned(const HUDQuad& q, double width, double height) {
    for (float value : q.xy) if (!std::isfinite(value)) return false;
    // KAGE Rect is TL, TR, BL, BR, not a perimeter-ordered quad.
    return Near(q.xy[2]-q.xy[0],width) && Near(q.xy[3],q.xy[1]) &&
        Near(q.xy[4],q.xy[0]) && Near(q.xy[5]-q.xy[1],height) &&
        Near(q.xy[6],q.xy[2]) && Near(q.xy[7],q.xy[5]);
}
inline bool MiniDisplayRect(int mode, const HUDSource& source, const HUDQuad& destination,
                            const HUDColor& color, double screenW, double screenH,
                            double viewW, double viewH, HUDRect& out) {
    // Only the known native Mini draw is replaceable, never other 16px art.
    if (mode != 2 || source.flags || !Near(source.quad.xy[0],0) || !Near(source.quad.xy[1],0) ||
        !AxisAligned(source.quad,32,32) || !AxisAligned(destination,16,16) ||
        !Near(color.r,1) || !Near(color.g,1) || !Near(color.b,1) ||
        !std::isfinite(color.a) || color.a <= 0 || color.a > 1 ||
        !std::isfinite(screenW) || !std::isfinite(screenH) || screenW < 320 || screenW > 4096 ||
        screenH < 200 || screenH > 4096 || !std::isfinite(viewW) || !std::isfinite(viewH) ||
        viewW <= 0 || viewH <= 0) return false;
    double x = destination.xy[0], y = destination.xy[1];
    if (x < 0 || y < 0 || x+16 > screenW || y+16 > screenH) return false;
    double scale = std::fmin(viewW/screenW,viewH/screenH);
    // Below 32 physical pixels this cannot recover all 32 source texels.
    // Density is checked separately against the actual window screen.
    out = {(viewW-screenW*scale)*.5+x*scale,(viewH-screenH*scale)*.5+y*scale,16*scale,16*scale};
    return true;
}
}
