#include "ISDPlanetariumPolicy.hpp"
#include "ISDHUDNumericFont.hpp"
#include <cassert>
#include <fstream>
#include <iostream>
#include <iterator>
#include <limits>

using namespace IsaacFixes;
static bool Near(double a,double b) { return std::abs(a-b)<.0001; }
static void U16(std::vector<uint8_t>& b,unsigned n) { b.push_back(n&255); b.push_back((n>>8)&255); }
static void U32(std::vector<uint8_t>& b,unsigned n) { U16(b,n); U16(b,n>>16); }
static void Block(std::vector<uint8_t>& b,unsigned type,const std::vector<uint8_t>& data) {
    b.push_back(type); U32(b,unsigned(data.size())); b.insert(b.end(),data.begin(),data.end());
}
static std::vector<uint8_t> Fixture() {
    std::vector<uint8_t> b={'B','M','F',3},common,chars;
    U16(common,12); U16(common,11); U16(common,128); U16(common,128); U16(common,1);
    common.resize(15); Block(b,2,common); Block(b,3,{'h','u','d','.','p','n','g',0});
    for (char c:std::string("0123456789.%?+-")) {
        U32(chars,c); U16(chars,0); U16(chars,0); U16(chars,6); U16(chars,7);
        U16(chars,0xffff); U16(chars,5); U16(chars,5); chars.push_back(0); chars.push_back(15);
    }
    Block(b,4,chars); return b;
}
int main(int argc,char **argv) {
    assert(PlanetariumUnpaused(0));
    for (int state:{-1,1,2,3,100}) assert(!PlanetariumUnpaused(state));
    PlanetariumLayout p; p.bombs=true;
    assert(Near(PlanetariumPosition(p).y,168));
    p.difficulty=1; assert(Near(PlanetariumPosition(p).y,184));
    p.achievementsDisabled=true; assert(Near(PlanetariumPosition(p).y,184)); // one shift, not two
    p.difficulty=0; assert(Near(PlanetariumPosition(p).y,184));
    p.achievementsDisabled=false; p.offset=1;
    assert(Near(PlanetariumPosition(p).x,20) && Near(PlanetariumPosition(p).y,180));
    p.offset=0; p.soulHearts=true; assert(Near(PlanetariumPosition(p).y,177));
    p.redHearts=true; p.poop=true; assert(Near(PlanetariumPosition(p).y,199));
    p={}; p.bombs=true; p.jacob=true; assert(Near(PlanetariumPosition(p).y,198));
    p.coop=true; assert(Near(PlanetariumPosition(p).y,198));
    p.jacob=false; assert(Near(PlanetariumPosition(p).y,184));
    p.duality=true; assert(Near(PlanetariumPosition(p).y,170));
    p.coop=false; assert(Near(PlanetariumPosition(p).y,156));
    p={}; p.poop=true; assert(Near(PlanetariumPosition(p).y,168));
    p.offset=std::numeric_limits<double>::quiet_NaN(); assert(Near(PlanetariumPosition(p).x,0));
    assert(Near(PlanetariumPercent(.01f,true,false),1));
    assert(Near(PlanetariumPercent(.21f,true,false),21));
    assert(Near(PlanetariumPercent(2,true,false),100));
    assert(PlanetariumPercent(-1,true,false)==0);
    assert(PlanetariumPercent(.5f,false,false)==0);
    assert(PlanetariumPercent(.5f,true,true)==0);
    assert(PlanetariumPercent(std::numeric_limits<float>::quiet_NaN(),true,false)==0);
    assert(!PlanetariumDogmaFlash(13,950,2,true,true,80.99));
    assert(PlanetariumDogmaFlash(13,950,2,true,true,81));
    assert(!PlanetariumDogmaFlash(12,950,2,true,true,81));
    assert(!PlanetariumDogmaFlash(13,950,10,true,true,81));
    assert(!PlanetariumDogmaFlash(13,950,2,false,true,81));
    assert(!PlanetariumDogmaFlash(13,950,2,true,false,81));
    PlanetariumPopup popup; popup.Change(0,21,true); assert(popup.Alpha()==0);
    popup.Change(1,21,false); assert(popup.difference==20 && popup.Alpha()==.5);
    assert(popup.Slide()<0);
    for (unsigned i=0;i<28;++i) popup.Advance();
    assert(Near(popup.Slide(),0) && popup.Alpha()==.5);
    for (unsigned i=28;i<245;++i) popup.Advance();
    assert(Near(popup.Alpha(),.45));
    for (unsigned i=245;i<400;++i) popup.Advance();
    assert(popup.Alpha()==0);
    popup.Change(21,1,false); assert(popup.difference==-20 && popup.Alpha()==.5);
    popup.Change(1,1,false); assert(popup.Alpha()==0);
    auto bytes=Fixture(); HUDNumericFont font;
    assert(font.Load(bytes.data(),bytes.size())); assert(font.lineHeight==12);
    assert(font.glyphs.at('0').dx==-1 && font.glyphs.at('0').dy==5);
    for (size_t n=0;n<bytes.size();++n) { HUDNumericFont truncated; assert(!truncated.Load(bytes.data(),n)); }
    bytes[0]=0; assert(!font.Load(bytes.data(),bytes.size()));
    if (argc==2) {
        std::ifstream file(argv[1],std::ios::binary);
        std::vector<uint8_t> real((std::istreambuf_iterator<char>(file)),{});
        assert(font.Load(real.data(),real.size()));
        assert(font.lineHeight==12 && font.width==128 && font.height==128);
        assert(font.glyphs.at('0').advance==5 && font.glyphs.at('%').advance==5);
        std::cout<<"User-owned LuaMiniOutlined atlas/metrics verified\n";
    }
    std::cout<<"Planetarium layout, clamp/eligibility, popup timing/colors, and bounded BMFont parser passed\n";
}
