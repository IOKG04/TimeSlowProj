const std = @import("std");

const GameObject = @import("../GameObject.zig");
const parts = @import("parts.zig");
const scene = @import("../scene.zig");
const Vec2 = @import("../Vec2.zig");

const Allocator = std.mem.Allocator;

const Bullet = @This();

pub const size: f32 = 0.1;

game_object: GameObject,
velocity: f32,
timer: parts.Timer,

pub fn init(gpa: Allocator, velocity: f32, lifetime: f32, position: Vec2, rotation: f32) GameObject.UpdateError!*Bullet {
    const outp = try gpa.create(Bullet);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .transform = .{
                .position = position,
                .rotation = rotation,
                .scale = .{ .x = size, .y = size },
            },

            .update = update,
            .deinit = deinit,

            .draw = .{ .circle = .white },

            .collider = .{ .circle = .{} },
            .collision_layer = .{
                .projectiles = true,
            },
            .onCollision = GameObject.useful.on_collision.selfDestruct,

            .metadata = .{
                .movability = .bullet,
            },
        },
        .velocity = velocity,
        .timer = .init(lifetime, false),
    };

    try scene.addGameObject(gpa, &outp.game_object);
    errdefer scene.removeGameObject(*outp.game_object);

    return outp;
}

fn update(go: *GameObject, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    _ = gpa;
    const bullet: *Bullet = @fieldParentPtr("game_object", go);
    const transform = &bullet.game_object.transform;

    transform.position = transform.position.add(Vec2.fromPolar(transform.rotation, bullet.velocity).scale(dt));

    if (bullet.timer.update(dt)) {
        scene.removeGameObject(go);
    }
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const bullet: *Bullet = @fieldParentPtr("game_object", go);
    gpa.destroy(bullet);
}
