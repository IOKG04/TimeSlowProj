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
