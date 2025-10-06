const std = @import("std");

const GameObject = @import("../GameObject.zig");
const parts = @import("parts.zig");
const Vec2 = @import("../Vec2.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const DbgTimer = @This();

game_object: GameObject,

timer: parts.Timer,

pub fn init(gpa: Allocator, interval: f32, position: Vec2) Allocator.Error!*DbgTimer {
    assert(interval > 0.0);

    const outp = try gpa.create(DbgTimer);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .update = update,
            .deinit = deinit,
            .draw = .{ .circle = .blue },
            .transform = .{
                .position = position,
                .scale = .{ .x = 0.5, .y = 0.5 },
            },
        },
        .timer = .init(interval, true),
    };

    return outp;
}

fn update(go: *GameObject, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    _ = gpa;

    const dbg_timer: *DbgTimer = @fieldParentPtr("game_object", go);

    if (dbg_timer.timer.update(dt)) {
        dbg_timer.game_object.draw.circle.g +%= 0x80;
    }
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const dbg_timer: *DbgTimer = @fieldParentPtr("game_object", go);
    gpa.destroy(dbg_timer);
}
