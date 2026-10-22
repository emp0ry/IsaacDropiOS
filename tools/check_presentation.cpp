#include "IsaacPresentationState.hpp"
#include <cassert>
#include <cstring>
#include <map>
#include <vector>
#include <limits>
#include <iostream>

struct Memory {
    std::map<uintptr_t,std::vector<uint8_t>> bytes;
    template<class T> void Set(uintptr_t a,T value) {
        auto& b=bytes[a]; b.resize(sizeof(value)); memcpy(b.data(),&value,sizeof(value));
    }
    bool operator()(uintptr_t a,void *p,size_t n) const {
        auto it=bytes.find(a); if (it==bytes.end() || it->second.size()!=n) return false;
        memcpy(p,it->second.data(),n); return true;
    }
};
int main() {
    using IsaacPresentation::State;
    State s; assert(!s.RunVisible(true) && !s.OverlayVisible());
    s.manager=10; s.game=20; s.room=30; s.roomDescriptor=31; s.mode=2; s.seed=40; s.hud=1; s.pending=0;
    s.pause=0; s.roomTransition=s.fadeState=s.bossIntro=s.deathScreen=s.cutscene=s.rewardScreen=0; s.fade=s.whiteFade=0;
    assert(s.RunVisible(false) && s.RunVisible(true));
    s.pause=1; assert(!s.RunVisible(false) && s.RunVisible(true) && s.OverlayVisible());
    s.pause=2; assert(!s.RunVisible(true)); s.pause=0;
    int *fields[]={&s.roomTransition,&s.fadeState,&s.bossIntro,&s.deathScreen,&s.cutscene};
    for (int *field:fields) { *field=1; assert(!s.RunVisible(true)); *field=0; }
    s.pending=1; assert(!s.RunVisible(true)); s.pending=0;
    s.hud=0; assert(!s.RunVisible(true)); s.hud=1;
    s.rewardScreen=1; assert(s.RunVisible(true));
    s.rewardScreen=2; assert(!s.RunVisible(true)); s.rewardScreen=0;
    s.entryTimer=1; assert(!s.RunVisible(true)); s.entryTimer=0;
    s.overlayTimer=1; assert(!s.RunVisible(true)); s.overlayTimer=0;
    s.fullscreenPlaying=1; assert(!s.RunVisible(true)); s.fullscreenPlaying=0;
    s.whiteFade=.1f; assert(!s.RunVisible(true)); s.whiteFade=0;
    s.whiteFade=-1; assert(s.RunVisible(true)); s.whiteFade=0;
    s.transitionKind=0;
    for (int phase=1;phase<=4;++phase) for (int direction=0;direction<4;++direction) {
        s.roomTransition=phase; s.transitionDirection=direction;
        assert(s.DoorSlide() && !s.RunVisible(false)); // Console mutation gate stays strict.
        assert(s.RunVisible(false,true) && s.OverlayVisible());
    }
    for (int kind:{1,2,3,11,16,17,18,19,20}) {
        s.transitionKind=kind; assert(!s.RunVisible(false,true) && !s.OverlayVisible());
    }
    s.transitionKind=0; s.transitionDirection=-1; assert(!s.RunVisible(false,true));
    s.transitionDirection=0;
    s.rewardScreen=2; assert(!s.RunVisible(false,true)); s.rewardScreen=0;
    s.fullscreenPlaying=1; assert(!s.RunVisible(false,true)); s.fullscreenPlaying=0;
    s.entryTimer=1; assert(!s.RunVisible(false,true)); s.entryTimer=0;
    s.fadeState=2; assert(!s.RunVisible(false,true)); s.fadeState=0;
    s.roomTransition=0;
    IsaacPresentation::Visibility visibility;
    assert(!visibility.Observe(s,true,false,false,1));
    assert(visibility.Observe(s,true,false,false,1.11));
    s.rewardScreen=2; assert(!visibility.Observe(s,true,false,false,1.12));
    s.rewardScreen=0; assert(!visibility.Observe(s,true,false,false,1.13));
    assert(!visibility.Observe(s,true,false,false,1.2));
    assert(visibility.Observe(s,true,false,false,1.24));
    s.roomTransition=2; assert(visibility.Observe(s,true,false,false,1.25));
    s.roomDescriptor++; assert(visibility.Observe(s,true,false,false,1.26));
    s.roomTransition=3; assert(visibility.Observe(s,true,false,false,1.27));
    s.roomTransition=0; assert(visibility.Observe(s,true,false,false,1.28));
    s.seed++; assert(!visibility.Observe(s,true,false,false,1.29));
    assert(!visibility.Observe(s,false,false,false,1.5));
    assert(!visibility.Observe(s,true,false,false,1.51));
    assert(visibility.Observe(s,true,false,false,1.62));
    s.fade=.1f; assert(!s.RunVisible(true));
    s.fade=std::numeric_limits<float>::quiet_NaN(); assert(!s.RunVisible(true)); s.fade=0;
    s.mode=1; assert(s.OverlayVisible() && !s.RunVisible(true));
    for (unsigned mode:{0,3,4,5,6}) { s.mode=mode; assert(!s.OverlayVisible()); }
    Memory memory; constexpr uintptr_t base=0x100000000,manager=0x200000000,game=0x300000000;
    memory.Set(base+0xac2428,manager); memory.Set(manager+0x204c0,uint32_t(1));
    assert(IsaacPresentation::Capture(base,memory,s) && s.OverlayVisible());
    memory.Set(manager+0x204c0,uint32_t(2)); assert(!IsaacPresentation::Capture(base,memory,s));
    memory.Set(base+0xac3b90,game); memory.Set(manager+0x1f6b40,uint8_t(0));
    memory.Set(game+0x21550,uintptr_t(0x400000000)); memory.Set(0x400000008,uintptr_t(0x500000000));
    memory.Set(game+0x25d44,uint32_t(123));
    memory.Set(game+0x10dfd8,int32_t(0)); memory.Set(game+0x10d45a,uint8_t(1));
    for (uintptr_t offset:{0x25810,0x25c00,0x27390,0x27630,0x47d04,0x25db0,0x1cf3d8,0x1cf3e8}) memory.Set(game+offset,int32_t(0));
    memory.Set(game+0x25810+0x1c,int32_t(0)); memory.Set(game+0x25810+0x10,int32_t(0));
    memory.Set(game+0x1cf440,float(0)); memory.Set(game+0x1cf444,float(0));
    memory.Set(game+0x1cf708+0x38,uintptr_t(123)); memory.Set(game+0x1cf708+0x54,uint8_t(0));
    assert(IsaacPresentation::Capture(base,memory,s) && s.RunVisible(false));
    memory.Set(game+0x25810,int32_t(2));
    assert(IsaacPresentation::Capture(base,memory,s) && !s.RunVisible(false) && s.RunVisible(false,true));
    memory.Set(game+0x25810+0x1c,int32_t(1));
    assert(IsaacPresentation::Capture(base,memory,s) && !s.RunVisible(false,true));
    memory.Set(game+0x25810,int32_t(0)); memory.Set(game+0x25810+0x1c,int32_t(0));
    memory.Set(game+0x1cf708+0x54,uint8_t(1));
    assert(IsaacPresentation::Capture(base,memory,s) && !s.RunVisible(true));
    memory.Set(game+0x1cf708+0x54,uint8_t(0));
    memory.Set(game+0x27390,int32_t(2));
    assert(IsaacPresentation::Capture(base,memory,s) && !s.RunVisible(true));
    memory.bytes.erase(game+0x27390); assert(!IsaacPresentation::Capture(base,memory,s));
    std::cout<<"Presentation gate passed: door slides stay visible, console mutation remains blocked, floor/boss/cinematics stay hidden, scene re-entry and invalid reads\n";
}
