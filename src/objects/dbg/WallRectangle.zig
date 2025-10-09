const std = @import("std");

const GameObject = @import("../../GameObject.zig");
const Vec2 = @import("../../Vec2.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const WallRectangle = @This();

game_object: GameObject,

pub fn init(gpa: Allocator, position: Vec2, size: Vec2) Allocator.Error!*WallRectangle {
    assert(size.x >= 0.0 and size.y >= 0.0);

    const outp = try gpa.create(WallRectangle);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .transform = .{
                .position = position,
                .scale = size,
            },

            .update = GameObject.noop.update,
            .deinit = deinit,

            .draw = .{ .rectangle = .dark_brown },

            .collider = .{ .rectangle = .{} },
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
    const wall_circle: *WallRectangle = @fieldParentPtr("game_object", go);
    gpa.destroy(wall_circle);
}
