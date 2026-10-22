#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace IsaacFixes {
// Repentance layout, not the different Repentance+ base position.
struct PlanetariumLayout {
    bool bombs=false,poop=false,redHearts=false,soulHearts=false;
    bool jacob=false,coop=false,duality=false,achievementsDisabled=false;
    int difficulty=0;
    double offset=0;
};
struct PlanetariumPoint { double x,y; };
inline bool PlanetariumUnpaused(int pauseState) { return pauseState==0; }
inline PlanetariumPoint PlanetariumPosition(const PlanetariumLayout& p) {
    double y=168;
    int extra=int(p.bombs)+int(p.poop)+int(p.redHearts)+int(p.soulHearts)-1;
    if (extra>0) y+=11*extra-2;
    if (p.jacob) y+=30;
    else if (p.coop) y+=16-(p.duality?2:0);
    if (p.duality) y-=12;
    if (p.difficulty!=0 || p.achievementsDisabled) y+=16;
    double offset=std::isfinite(p.offset)?std::max(0.,std::min(p.offset,1.)):0;
    return {20*offset,y+12*offset};
}
inline double PlanetariumPercent(float chance,bool canSpawn,bool ascent) {
    return std::isfinite(chance) && canSpawn && !ascent ? std::max(0.,std::min(double(chance),1.))*100 : 0;
}
inline bool PlanetariumDogmaFlash(int stage,int npcType,int variant,bool alive,bool death,double frame) {
    return stage==13 && npcType==950 && variant>=0 && variant<=2 && alive && death &&
        std::isfinite(frame) && std::floor(frame)>80;
}
struct PlanetariumPopup {
    double difference=0;
    unsigned rendered=290;
    void Change(double before,double after,bool initial) {
        difference=initial?0:after-before; rendered=difference==0?290:0;
    }
    double Alpha() const { return std::max(0.,std::min(2.9-.01*rendered,.5)); }
    double Slide() const {
        double t=.5*rendered-14;
        return t>0?0:-(15.1/(13*13))*t*t;
    }
    void Advance() { if (rendered<290) ++rendered; }
};
}
