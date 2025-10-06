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

pub fn init(gpa: Allocator) Allocator.Error!*Player {
    const outp = try gpa.create(Player);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .update = update,
            .deinit = deinit,
            .draw_order = .foreground,
            .draw = .{ .circle_dbg = .red },
        },
    };

    return outp;
}

fn update(go: *GameObject, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    const player: *Player = @fieldParentPtr("game_object", go);
    const transform = &player.game_object.transform;

    if (raylib.isKeyDown(.a)) transform.position.x -= dt * velocity;
    if (raylib.isKeyDown(.d)) transform.position.x += dt * velocity;
    if (raylib.isKeyDown(.w)) transform.position.y -= dt * velocity;
    if (raylib.isKeyDown(.s)) transform.position.y += dt * velocity;

    const mouse_pos = raylib.getMousePosition();
    const world_mouse_pos = raylib.getScreenToWorld2D(mouse_pos, game.camera);
    const internal_world_mouse_pos: Vec2 = .fromRaylib(world_mouse_pos);
    const phi = internal_world_mouse_pos.subtract(transform.position).angle();
    transform.rotation = phi;

    if (raylib.isKeyPressed(.space)) {
        const dbg_timer = try objects.DbgTimer.init(gpa, 1.0, transform.position);
        errdefer dbg_timer.game_object.deinit(&dbg_timer.game_object, gpa);
        try scene.addGameObject(gpa, &dbg_timer.game_object);
    }
    if (raylib.isMouseButtonPressed(.left)) {
        const bullet = try objects.Bullet.init(gpa, velocity * 2.0, 5.0, transform.position, transform.rotation);
        errdefer bullet.game_object.deinit(&bullet.game_object, gpa);
        try scene.addGameObject(gpa, &bullet.game_object);
    }
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const player: *Player = @fieldParentPtr("game_object", go);
    gpa.destroy(player);
}
