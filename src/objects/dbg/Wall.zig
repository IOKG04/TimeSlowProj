const std = @import("std");
const Vec2 = @import("Vec2");

const GameObject = @import("../../GameObject.zig");
const scene = @import("../../scene.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Wall = @This();

game_object: GameObject,

pub fn init(gpa: Allocator, position: Vec2, shape: Shape) GameObject.UpdateError!*Wall {
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

            .update = null,
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
            .onCollision = null,

            .metadata = .{
                .movability = .wall,
            },
        },
    };

    try scene.addGameObject(gpa, &outp.game_object);
    errdefer scene.removeGameObject(*outp.game_object);

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
