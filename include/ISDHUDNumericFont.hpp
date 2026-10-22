#pragma once
#include <cstdint>
#include <cstring>
#include <map>
#include <string>
#include <vector>

namespace IsaacFixes {
// The game's BMFont v3 atlas. Only ASCII HUD characters are rendered.
struct HUDGlyph {
    uint16_t x,y,w,h;
    int16_t dx,dy,advance;
    uint8_t page;
};
struct HUDNumericFont {
    uint16_t width=0,height=0,lineHeight=0;
    std::vector<std::string> pages;
    std::map<uint32_t,HUDGlyph> glyphs;
    std::map<uint64_t,int16_t> kerning;
    static uint16_t U16(const uint8_t *p) { return p[0]|uint16_t(p[1])<<8; }
    static uint32_t U32(const uint8_t *p) { return U16(p)|uint32_t(U16(p+2))<<16; }
    bool Load(const uint8_t *p,size_t count) {
        *this={};
        if (!p || count<4 || memcmp(p,"BMF\3",4)) return false;
        unsigned pageCount=0; bool common=false,chars=false;
        for (size_t at=4;at<count;) {
            if (count-at<5) return false;
            uint8_t type=p[at]; size_t n=U32(p+at+1); at+=5;
            if (n>count-at) return false;
            const uint8_t *b=p+at; at+=n;
            if (type==2) {
                if (common || n!=15 || (b[10]&0x80)) return false;
                common=true; lineHeight=U16(b); width=U16(b+4); height=U16(b+6); pageCount=U16(b+8);
                if (!lineHeight || lineHeight>128 || !width || width>4096 || !height || height>4096 || !pageCount || pageCount>4) return false;
            } else if (type==3) {
                if (!pages.empty()) return false;
                for (size_t i=0;i<n;) {
                    size_t end=i; while (end<n && b[end]) ++end;
                    if (end==n || end==i) return false;
                    std::string name(reinterpret_cast<const char *>(b+i),end-i);
                    if (name.find('/')!=std::string::npos || name.find('\\')!=std::string::npos || name.find("..")!=std::string::npos) return false;
                    pages.push_back(name); i=end+1;
                }
            } else if (type==4) {
                if (chars || n%20 || n/20>65536) return false;
                chars=true;
                for (size_t i=0;i<n;i+=20) {
                    uint32_t id=U32(b+i);
                    HUDGlyph g{U16(b+i+4),U16(b+i+6),U16(b+i+8),U16(b+i+10),
                        int16_t(U16(b+i+12)),int16_t(U16(b+i+14)),int16_t(U16(b+i+16)),b[i+18]};
                    if (!glyphs.emplace(id,g).second) return false;
                }
            } else if (type==5) {
                if (n%10) return false;
                for (size_t i=0;i<n;i+=10) kerning[(uint64_t(U32(b+i))<<32)|U32(b+i+4)]=int16_t(U16(b+i+8));
            }
        }
        if (!common || !chars || pageCount!=pages.size()) return false;
        for (const auto& entry:glyphs) {
            const auto& g=entry.second;
            if (g.page>=pageCount || unsigned(g.x)+g.w>width || unsigned(g.y)+g.h>height || g.advance<0 || g.advance>128) return false;
        }
        for (char c:std::string("0123456789.%?+-")) if (!glyphs.count(c)) return false;
        return true;
    }
    int Kerning(uint32_t before,uint32_t after) const {
        auto it=kerning.find((uint64_t(before)<<32)|after); return it==kerning.end()?0:it->second;
    }
};
}
