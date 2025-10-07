const std = @import("std");

const GameObject = @import("../../GameObject.zig");
const Vec2 = @import("../../Vec2.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const WallCircle = @This();

game_object: GameObject,

pub fn init(gpa: Allocator, position: Vec2, radius: f32) Allocator.Error!*WallCircle {
    assert(radius > 0.0);

    const outp = try gpa.create(WallCircle);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .transform = .{
                .position = position,
                .scale = .{ .x = radius, .y = radius },
            },

            .update = GameObject.noop.update,
            .deinit = deinit,

            .draw = .{ .circle = .dark_brown },

            .collider = .{ .circle = .{} },
            .collision_layer = .{
                .movement = true,
                .projectiles = true,
            },
            .onCollision = GameObject.noop.onCollision,

            .metadata = .{
                .movability = .wall,
            },
        },
    };

    return outp;
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const wall_circle: *WallCircle = @fieldParentPtr("game_object", go);
    gpa.destroy(wall_circle);
}
