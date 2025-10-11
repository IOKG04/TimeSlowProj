const std = @import("std");

const assert = std.debug.assert;

const Timer = @This();

timer: f32 = 0.0,
interval: f32,
looping: bool,

pub fn init(interval: f32, looping: bool) Timer {
    assert(interval > 0.0);
    return .{
        .interval = interval,
        .looping = looping,
    };
}

/// Returns `true` if the interval was reached.
pub fn update(timer: *Timer, dt: f32) bool {
    timer.timer += dt;
    if (timer.timer >= timer.interval) {
        if (timer.looping) {
            while (timer.timer >= timer.interval) : (timer.timer -= timer.interval) {}
        }
        return true;
    } else return false;
}
/// Clamped to `[0.0 ; 1.0]`.
pub fn progress(timer: Timer) f32 {
    return std.math.clamp(timer.timer / timer.interval, 0.0, 1.0);
}

test "Timer" {
    // Comments are what `timer.timer` should be after the operation.
    const expect = std.testing.expect;

    { // looping
        var timer: Timer = .init(1.0, true);

        try expect(!timer.update(0.0)); // 0.0
        try expect(timer.progress() == 0.0);
        try expect(timer.update(1.0)); // 0.0
        try expect(timer.update(1.5)); // 0.5
        try expect(timer.progress() == 0.5);
        try expect(timer.update(0.5)); // 0.0
        try expect(timer.update(2.0)); // 0.0
        try expect(timer.progress() == 0.0);
        try expect(!timer.update(0.5)); // 0.5
    }
    { // non-looping
        var timer: Timer = .init(1.0, false);

        try expect(!timer.update(0.0)); // 0.0
        try expect(timer.progress() == 0.0);
        try expect(!timer.update(0.5)); // 0.5
        try expect(timer.progress() == 0.5);
        try expect(timer.update(0.5)); // 1.0
        try expect(timer.progress() == 1.0);
        try expect(timer.update(0.5)); // 1.5
        try expect(timer.progress() == 1.0);

        timer.timer = 0.0;

        try expect(!timer.update(0.0)); // 0.0
        try expect(timer.progress() == 0.0);
        try expect(timer.update(2.0)); // 2.0
        try expect(timer.progress() == 1.0);
        try expect(timer.update(0.0)); // 2.0
        try expect(timer.progress() == 1.0);
    }
}
