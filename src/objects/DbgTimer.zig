const std = @import("std");

const GameObject = @import("../GameObject.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const DbgTimer = @This();

game_object: GameObject,

timer: f32 = 0.0,
interval: f32,

pub fn init(gpa: Allocator, interval: f32) Allocator.Error!*DbgTimer {
    assert(interval > 0.0);

    const outp = try gpa.create(DbgTimer);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .update = update,
            .deinit = deinit,
            .draw = .{ .circle = .blue },
            .transform = .{
                .scale = .{ .x = 0.5, .y = 0.5 },
            },
        },
        .interval = interval,
    };

    return outp;
}

fn update(go: *GameObject, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    _ = gpa;

    const dbg_timer: *DbgTimer = @fieldParentPtr("game_object", go);

    dbg_timer.timer += dt;
    if (dbg_timer.timer >= dbg_timer.interval) {
        dbg_timer.timer = 0.0;
        dbg_timer.game_object.draw.circle.g +%= 0x80;
    }
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const dbg_timer: *DbgTimer = @fieldParentPtr("game_object", go);
    gpa.destroy(dbg_timer);
}
