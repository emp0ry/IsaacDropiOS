#pragma once
#include <cmath>
#include <cstdint>

namespace IsaacDrop {
// Repeat a continuous hold through only the native restarts that it requested.
// Pauses, external run changes, lost focus and mixed sources still cancel it.
class RestartHold {
    unsigned held_ = 0;
    bool armed_ = false, transition_ = false;
    double next_ = 0, last_ = 0, queued_ = 0;
    uintptr_t run_ = 0;
public:
    static constexpr double Seconds = 1.0;
    void Cancel() { armed_ = false; transition_ = false; }
    bool TransitionPending() const { return armed_ && transition_; }
    bool Down(unsigned source, double now, uintptr_t run, bool available) {
        if (!source || (held_ & source)) return false;
        if (held_) Cancel();
        held_ |= source;
        if (held_ != source || !available || !run || !std::isfinite(now) || now <= 0) return false;
        last_ = now; next_ = now+Seconds; run_ = run; armed_ = true;
        return true;
    }
    void Up(unsigned source) {
        held_ &= ~source;
        // Releasing either source cancels instead of inheriting another hold.
        Cancel();
    }
    void Reset() { *this = RestartHold{}; }
    // Call only after the native restart queue actually accepted a request.
    // A failed validation must not silently become a repeating operation.
    void Queued(double now) {
        if (!held_ || !std::isfinite(now) || now < last_) { Cancel(); return; }
        last_ = queued_ = now; next_ = now+Seconds;
        armed_ = transition_ = true;
    }
    bool Poll(double now, uintptr_t run, bool ready, bool context = true) {
        if (!armed_) return false;
        if (!context || !held_ || !std::isfinite(now) || now < last_) { Cancel(); return false; }
        // Native loading may stall the main loop or briefly remove the room.
        // Wait for it, never enqueue a second restart into a pending one.
        if (transition_) {
            if (now-queued_ > 10) { Cancel(); return false; }
            last_ = now;
            if (!ready || !run) return false;
            transition_ = false; run_ = run;
        } else if (!ready || !run || run != run_ || now-last_ > .3) {
            Cancel(); return false;
        }
        last_ = now;
        if (now < next_) return false;
        armed_ = false;
        return true;
    }
};
}
