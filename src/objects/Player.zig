const std = @import("std");
const raylib = @import("raylib");

const game = @import("../game.zig");
const GameObject = @import("../GameObject.zig");
const objects = @import("../objects.zig");
const scene = @import("../scene.zig");
const Vec2 = @import("../Vec2.zig");

const Allocator = std.mem.Allocator;

const Player = @This();

const velocity = 2.5;

game_object: GameObject,

dbg_click_start: Vec2 = undefined,

pub fn init(gpa: Allocator) Allocator.Error!*Player {
    const outp = try gpa.create(Player);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .update = update,
            .deinit = deinit,

            .draw_order = .foreground,
            .draw = .{ .circle_dbg = .red },

            .collider = .{ .circle = .{} },
            .collision_layer = .{
                .movement = true,
                .projectiles = true,
            },
            .onCollision = onCollision,

            .metadata = .{
                .movability = .normal,
            },
        },
    };

    return outp;
}

fn update(go: *GameObject, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    const player: *Player = @fieldParentPtr("game_object", go);
    const transform = &player.game_object.transform;

    var speed: Vec2 = .zero;
    if (raylib.isKeyDown(.a)) speed.x -= 1;
    if (raylib.isKeyDown(.d)) speed.x += 1;
    if (raylib.isKeyDown(.w)) speed.y -= 1;
    if (raylib.isKeyDown(.s)) speed.y += 1;
    speed = speed.normalizeSafe() orelse .zero;
    transform.position = transform.position.add(speed.scale(dt * velocity));

    const mouse_pos = raylib.getMousePosition();
    const world_mouse_pos = raylib.getScreenToWorld2D(mouse_pos, game.camera);
    const internal_world_mouse_pos: Vec2 = .fromRaylib(world_mouse_pos);
    const phi = internal_world_mouse_pos.subtract(transform.position).angle();
    transform.rotation = phi;

    if (raylib.isMouseButtonPressed(.left)) {
        const bullet_position = transform.position.add(.{
            .x = @cos(transform.rotation) * (transform.scale.x / 2.0 + objects.Bullet.size),
            .y = @sin(transform.rotation) * (transform.scale.x / 2.0 + objects.Bullet.size),
        });
        const bullet = try objects.Bullet.init(gpa, velocity * 2.0, 5.0, bullet_position, transform.rotation);
        errdefer bullet.game_object.deinit(&bullet.game_object, gpa);
        try scene.addGameObject(gpa, &bullet.game_object);
    }

    // The following code is only for debugging purposes
    // and to be removed whenever I get level loading to work.

    if (raylib.isKeyPressed(.space)) {
        const timer = try objects.dbg.Timer.init(gpa, 1.0, transform.position);
        errdefer timer.game_object.deinit(&timer.game_object, gpa);
        try scene.addGameObject(gpa, &timer.game_object);
    }

    if (raylib.isMouseButtonPressed(.right) or raylib.isMouseButtonPressed(.middle)) player.dbg_click_start = internal_world_mouse_pos;
    if (raylib.isMouseButtonReleased(.right)) {
        const radius = player.dbg_click_start.subtract(internal_world_mouse_pos).len() * 2.0;
        const wall_circle = try objects.dbg.WallCircle.init(gpa, player.dbg_click_start, radius);
        errdefer wall_circle.game_object.deinit(&wall_circle.game_object, gpa);
        try scene.addGameObject(gpa, &wall_circle.game_object);
    }
    if (raylib.isMouseButtonReleased(.middle)) {
        const size_signed = player.dbg_click_start.subtract(internal_world_mouse_pos);
        const center = internal_world_mouse_pos.add(size_signed.scale(0.5));
        const wall_rectangle = try objects.dbg.WallRectangle.init(gpa, center, size_signed.abs());
        errdefer wall_rectangle.game_object.deinit(&wall_rectangle.game_object, gpa);
        try scene.addGameObject(gpa, &wall_rectangle.game_object);
    }
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const player: *Player = @fieldParentPtr("game_object", go);
    gpa.destroy(player);
}

fn onCollision(self: *GameObject, other: *const GameObject, collision_info: GameObject.CollisionInfo, gpa: Allocator) GameObject.UpdateError!void {
    _ = gpa;

    const player: *Player = @fieldParentPtr("game_object", self);

    const movement_factor: f32 = switch (other.metadata.movability) {
        .bullet => 0.0,
        .normal => collision_info.depth / 2.0,
        .immovable, .wall => collision_info.depth,
    };
    player.game_object.transform.position = player.game_object.transform.position.add(collision_info.normal.scale(movement_factor));
}
