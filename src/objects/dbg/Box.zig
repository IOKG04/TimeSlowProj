const std = @import("std");
const Vec2 = @import("Vec2");
const options = @import("options");

const game = @import("../../game.zig");
const GameObject = @import("../../GameObject.zig");
const scene = @import("../../scene.zig");

const Allocator = std.mem.Allocator;

const Box = @This();

game_object: GameObject,

pub fn init(gpa: Allocator, position: Vec2) GameObject.UpdateError!*Box {
    const outp = try gpa.create(Box);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .transform = .{
                .position = position,
            },

            .update = GameObject.noop.update,
            .deinit = deinit,

            .draw = .{ .texture = try game.texture_manager.load(gpa, "box") },

            .collider = .{ .rounded_rectangle = .{
                .radius = options.units_per_pixel * 4.0,
            } },
            .collision_layer = .{
                .movement = true,
                .projectiles = true,
            },
            .onCollision = GameObject.useful.on_collision.physics,

            .metadata = .{
                .movability = .normal,
            },
        },
    };

    try scene.addGameObject(gpa, &outp.game_object);
    errdefer scene.removeGameObject(*outp.game_object);

    return outp;
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const box: *Box = @fieldParentPtr("game_object", go);
    gpa.destroy(box);
}
