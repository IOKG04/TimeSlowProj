const std = @import("std");

const GameObject = @import("../../GameObject.zig");
const Vec2 = @import("../../Vec2.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Wall = @This();

game_object: GameObject,

pub fn init(gpa: Allocator, position: Vec2, shape: Shape) Allocator.Error!*Wall {
    switch (shape) {
        .circle => |r| assert(r > 0.0),
        .rectangle => |size| assert(size.x > 0.0 and size.y > 0.0),
    }

    const outp = try gpa.create(Wall);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .transform = .{
                .position = position,
                .scale = switch (shape) {
                    .circle => |r| .{ .x = r, .y = r },
                    .rectangle => |size| size,
                },
            },

            .update = GameObject.noop.update,
            .deinit = deinit,

            .draw = switch (shape) {
                .circle => .{ .circle = .dark_brown },
                .rectangle => .{ .rectangle = .dark_brown },
            },

            .collider = switch (shape) {
                .circle => .{ .circle = .{} },
                .rectangle => .{ .rectangle = .{} },
            },
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
    const wall: *Wall = @fieldParentPtr("game_object", go);
    gpa.destroy(wall);
}

pub const Shape = union (enum) {
    circle: f32,
    rectangle: Vec2,
};
