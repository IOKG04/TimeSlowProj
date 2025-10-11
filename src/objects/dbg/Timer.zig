const std = @import("std");

const GameObject = @import("../../GameObject.zig");
const parts = @import("../parts.zig");
const scene = @import("../../scene.zig");
const Vec2 = @import("../../Vec2.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Timer = @This();

game_object: GameObject,

timer: parts.Timer,

pub fn init(gpa: Allocator, interval: f32, position: Vec2) GameObject.UpdateError!*Timer {
    assert(interval > 0.0);

    const outp = try gpa.create(Timer);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .transform = .{
                .position = position,
                .scale = .{ .x = 0.5, .y = 0.5 },
            },

            .update = update,
            .deinit = deinit,

            .draw = .{ .circle = .blue },

            .metadata = .{
                .movability = .wall,
            },
        },
        .timer = .init(interval, true),
    };

    try scene.addGameObject(gpa, &outp.game_object);

    return outp;
}

fn update(go: *GameObject, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    _ = gpa;

    const timer: *Timer = @fieldParentPtr("game_object", go);

    if (timer.timer.update(dt)) {
        timer.game_object.draw.circle.g +%= 0x80;
    }
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const timer: *Timer = @fieldParentPtr("game_object", go);
    gpa.destroy(timer);
}
