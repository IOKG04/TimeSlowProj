const std = @import("std");
const math = std.math;

const game = @import("../game.zig");
const GameObject = @import("../GameObject.zig");
const objects = @import("../objects.zig");
const scene = @import("../scene.zig");
const Vec2 = @import("../Vec2.zig");

const Allocator = std.mem.Allocator;
const pi = math.pi;

const Gun = @This();

const turning_speed = pi * 2.0;

game_object: GameObject,

center: *const Vec2,
radius: f32,
target_angle: f32 = 0.0,

pub fn init(gpa: Allocator, parent: *const GameObject) GameObject.UpdateError!*Gun {
    const outp = try gpa.create(Gun);
    errdefer gpa.destroy(outp);

    const gun_texture = try game.texture_manager.load(gpa, "gun");

    outp.* = .{
        .game_object = .{
            .transform = .{
                .scale = .{
                    .x = @as(f32, @floatFromInt(gun_texture.width)) * game.units_per_pixel,
                    .y = @as(f32, @floatFromInt(gun_texture.height)) * game.units_per_pixel,
                },
            },

            .update = update,
            .deinit = deinit,

            .draw_order = .foreground,
            .draw = .{ .texture_offset = .{
                .texture = gun_texture,
                .offset = .{
                    .x = 0.0,
                    .y = @as(f32, @floatFromInt(gun_texture.height)) / 2.0 * game.units_per_pixel + game.units_per_pixel,
                },
            } },
        },
        .center = &parent.transform.position,
        .radius = parent.transform.scale.abs().maxDimension(),
    };

    try scene.addGameObject(gpa, &outp.game_object);
    errdefer scene.removeGameObject(*outp.game_object);

    return outp;
}

fn update(go: *GameObject, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    _ = gpa;

    const gun: *Gun = @fieldParentPtr("game_object", go);
    const transform = &gun.game_object.transform;

    const previous_angle = transform.rotation;
    const delta_angle: f32 = blk: {
        var guess = gun.target_angle - previous_angle;
        while (guess >= pi) : (guess -= 2.0 * pi) {}
        while (guess <= -pi) : (guess += 2.0 * pi) {}
        break :blk guess;
    };
    transform.rotation += math.clamp(math.sign(delta_angle) * turning_speed * dt, -@abs(delta_angle), @abs(delta_angle));

    const position_offset: Vec2 = .fromPolar(transform.rotation, gun.radius);
    transform.position = gun.center.add(position_offset);
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const gun: *Gun = @fieldParentPtr("game_object", go);
    gpa.destroy(gun);
}

pub fn shoot(gun: *Gun, gpa: Allocator, velocity: f32, lifetime: f32) GameObject.UpdateError!*objects.Bullet {
    // TODO: Add logic for having to wait and such here.
    return try objects.Bullet.init(gpa, velocity, lifetime, gun.game_object.transform.position, gun.game_object.transform.rotation);
}
