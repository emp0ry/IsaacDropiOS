#include "ISDRestartPolicy.hpp"
#include <cassert>
#include <cstdio>
using IsaacDrop::RestartHold;
static bool Advance(RestartHold& hold, double from, double to, uintptr_t run = 7,
                    bool ready = true, bool context = true) {
    bool fired = false;
    for (double now = from; now < to; now += .05) fired |= hold.Poll(now,run,ready,context);
    return fired;
}
int main() {
    RestartHold h;
    assert(h.Down(1,1,7,true));
    assert(!Advance(h,1.05,1.95));
    assert(h.Poll(2,7,true));
    assert(!Advance(h,2.05,5)); // not queued: no automatic retry
    assert(!h.Down(1,5,7,true));
    h.Up(1);
    assert(h.Down(1,6,7,true));
    h.Up(1);
    assert(!Advance(h,6.05,8));
    assert(h.Down(2,9,7,true));
    h.Cancel();
    assert(!Advance(h,9.05,11));
    assert(!h.Down(2,11,7,true));
    h.Up(2);
    assert(!h.Down(2,12,7,false));
    assert(!h.Down(2,13,7,true));
    h.Up(2);
    assert(h.Down(2,14,7,true));
    assert(!Advance(h,14.05,16,8)); // new run
    h.Up(2);
    assert(h.Down(1,17,7,true));
    assert(!h.Poll(19,7,true)); // stalled UI thread
    h.Up(1);
    assert(h.Down(1,20,7,true));
    assert(!h.Down(2,20.5,7,true));
    assert(!Advance(h,20.55,23)); // mixed sources never inherit a hold
    h.Up(1); h.Up(2);
    assert(h.Down(2,24,7,true));
    assert(!h.Poll(24.05,7,false));
    assert(!Advance(h,24.1,27));
    h.Up(2);

    // One physical key-down produces repeated requests across new seeds.
    assert(h.Down(2,30,7,true));
    assert(!Advance(h,30.05,30.95));
    assert(h.Poll(31,7,true)); h.Queued(31);
    assert(h.TransitionPending());
    assert(!Advance(h,31.05,31.2,0,false));
    assert(!h.Poll(31.2,8,true)); // new run ready before the next deadline
    assert(!h.TransitionPending());
    assert(!Advance(h,31.25,31.95,8));
    assert(h.Poll(32,8,true)); h.Queued(32);
    assert(!Advance(h,32.05,32.95,8,false));
    assert(h.Poll(33,9,true)); h.Queued(33);
    // A seeded run can restart with an unchanged identity.
    assert(!Advance(h,33.05,33.2,0,false));
    assert(!h.Poll(33.2,9,true));
    assert(!Advance(h,33.25,33.95,9));
    assert(h.Poll(34,9,true)); h.Queued(34);
    h.Up(2);
    assert(!Advance(h,34.05,37,10)); // release stops pending repetition

    // Native loading stalls are tolerated only after our own queued restart.
    assert(h.Down(1,40,10,true));
    assert(!Advance(h,40.05,40.95,10));
    assert(h.Poll(41,10,true)); h.Queued(41);
    assert(!h.Poll(44,0,false));
    assert(h.Poll(44.1,11,true)); h.Queued(44.1);
    assert(!h.Poll(44.1,11,true)); // no catch-up burst after a long load
    assert(!Advance(h,44.15,45,11));
    assert(h.Poll(45.1,11,true)); h.Queued(45.1);
    assert(!h.Poll(45.15,0,false,false)); // pause/dialog cancels even during load
    assert(!Advance(h,45.2,48,12));
    h.Up(1);

    assert(h.Down(2,50,12,true));
    assert(!Advance(h,50.05,50.95,12));
    assert(h.Poll(51,12,true)); h.Queued(51);
    assert(!h.Poll(61.1,13,true)); // timeout cannot become a delayed reset
    assert(!Advance(h,61.15,64,13));
    std::puts("Restart hold policy passed: 1-second repeats, native transitions, release, pause, no duplicates/backlog");
}
