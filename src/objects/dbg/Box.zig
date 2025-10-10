const std = @import("std");

const GameObject = @import("../../GameObject.zig");
const Vec2 = @import("../../Vec2.zig");

const Allocator = std.mem.Allocator;

const Box = @This();

game_object: GameObject,

pub fn init(gpa: Allocator, position: Vec2) Allocator.Error!*Box {
    const outp = try gpa.create(Box);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .transform = .{
                .position = position,
            },

            .update = GameObject.noop.update,
            .deinit = deinit,

            .draw = .{ .rectangle = .yellow },

            .collider = .{ .rectangle = .{} },
            .collision_layer = .{
                .movement = true,
            },
            .onCollision = GameObject.useful.on_collision.physics,

            .metadata = .{
                .movability = .normal,
            },
        },
    };

    return outp;
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const box: *Box = @fieldParentPtr("game_object", go);
    gpa.destroy(box);
}
