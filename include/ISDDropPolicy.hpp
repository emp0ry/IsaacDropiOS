#pragma once
#include <cmath>
#include <cstdint>

namespace IsaacDrop {
struct Sample { bool pressed = false; bool triggered = false; };

// Repentance's native D Infinity mode is a signed 16-bit index, not an
// arbitrary collectible ID. Reject unexpected state rather than normalizing it.
inline bool NextDInfinityMode(int16_t current, int16_t& next) {
    if (current < 0 || current >= 10) return false;
    next = static_cast<int16_t>((current+1)%10);
    return true;
}

// One logical press per gesture, visible consistently to every input query in
// the same native display frame. A sub-frame tap survives until sampled.
class Press {
    bool down_ = false, sampled_ = false;
    unsigned pending_ = 0;
    double began_ = 0, frame_ = 0;
    Sample current_{};
public:
    void Cancel() { *this = Press{}; }
    bool Begin(double now) {
        if (down_ || !std::isfinite(now) || now <= 0) return false;
        down_ = true; began_ = now;
        if (pending_ < 8) ++pending_;
        return true;
    }
    void End() { down_ = false; }
    Sample Read(double frame, double now, bool enabled) {
        if (!enabled || !std::isfinite(frame) || frame <= 0 ||
            !std::isfinite(now) || now <= 0 ||
            (down_ && (now < began_ || now-began_ > 10))) {
            Cancel(); return {};
        }
        if (sampled_ && frame == frame_) return current_;
        if (sampled_ && frame < frame_) { Cancel(); return {}; }
        sampled_ = true; frame_ = frame;
        // A new press needs a released frame between gestures. Otherwise a
        // rapid second tap would look like continuous holding to the engine.
        if (pending_ && !current_.pressed) {
            --pending_; current_ = {true,true};
        } else if (pending_) {
            current_ = {};
        } else {
            current_ = {down_,false};
        }
        return current_;
    }
};
}
