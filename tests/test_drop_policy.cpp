#include "ISDDropPolicy.hpp"
#include <cassert>
#include <limits>
#include <initializer_list>
#include <cstdio>

int main() {
    using IsaacDrop::Press;
    for (int16_t mode = 0; mode < 10; ++mode) {
        int16_t next = -1;
        assert(IsaacDrop::NextDInfinityMode(mode,next));
        assert(next == (mode+1)%10);
    }
    for (int16_t mode : {-1,10,32767}) {
        int16_t next = -1;
        assert(!IsaacDrop::NextDInfinityMode(mode,next) && next == -1);
    }
    Press p;
    assert(!p.Read(1,1,true).pressed);
    p.Begin(1.01); p.End();
    auto tap = p.Read(2,1.02,true);
    assert(tap.pressed && tap.triggered); // Even a sub-frame tap is retained.
    for (int i = 0; i < 10; ++i) {
        auto repeated = p.Read(2,1.025,true);
        assert(repeated.pressed && repeated.triggered);
    }
    assert(!p.Read(3,1.03,true).pressed);
    p.Begin(1.04);
    assert(p.Read(4,1.05,true).triggered);
    for (int frame = 5; frame < 120; ++frame) {
        auto hold = p.Read(frame,1.05+frame/60.,true);
        assert(hold.pressed && !hold.triggered);
    }
    p.End();
    assert(!p.Read(120,3.1,true).pressed);
    p.Cancel();
    assert(p.Begin(4));
    assert(!p.Begin(4.01)); // Duplicate TouchDown must not switch or enqueue repeats.
    assert(p.Read(1,4.02,true).triggered);
    assert(!p.Read(2,4.03,true).triggered);
    p.End(); p.Begin(4.04); p.End();
    assert(!p.Read(3,4.05,true).pressed); // One released frame between taps.
    assert(p.Read(4,4.06,true).triggered);
    assert(!p.Read(5,4.07,true).pressed);
    p.Cancel(); p.Begin(5); p.End(); p.Begin(5.01); p.End();
    assert(p.Read(1,5.02,true).triggered);
    assert(!p.Read(2,5.03,true).pressed);
    assert(p.Read(3,5.04,true).triggered);
    assert(!p.Read(4,5.05,true).pressed);
    p.Begin(6);
    assert(!p.Read(5,6.01,false).pressed); // Pause/background clears queued input.
    assert(!p.Read(6,6.02,true).pressed);
    p.Begin(7);
    assert(p.Read(7,7.01,true).pressed);
    assert(!p.Read(8,17.1,true).pressed); // Lost-end watchdog.
    p.Begin(20);
    assert(p.Read(20,20.01,true).pressed);
    assert(!p.Read(19,20.02,true).pressed); // Native clock replacement/reset.
    p.Begin(21);
    assert(!p.Read(std::numeric_limits<double>::quiet_NaN(),21.01,true).pressed);
    p.Begin(-1);
    assert(!p.Read(22,22,true).pressed);
    std::puts("Drop policy passed: tap, hold, repeated queries, quick taps, cancel, watchdog");
}
