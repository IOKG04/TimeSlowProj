const std = @import("std");
const raylib = @import("raylib");
const Vec2 = @import("Vec2");
const Collision = @import("Collision");
const options = @import("options");

const game = @import("../game.zig");
const GameObject = @import("../GameObject.zig");
const objects = @import("../objects.zig");
const scene = @import("../scene.zig");

const Allocator = std.mem.Allocator;

const Player = @This();

const velocity = 2.5;

game_object: GameObject,

gun: *objects.Gun,

dbg_click_start: Vec2 = undefined,

pub fn init(gpa: Allocator) GameObject.UpdateError!*Player {
    const outp = try gpa.create(Player);
    errdefer gpa.destroy(outp);

    outp.* = .{
        .game_object = .{
            .update = update,
            .deinit = deinit,

            .draw_order = .foreground,
            .draw = .{ .texture = try game.texture_manager.load(gpa, "player") },

            .collider = .{ .rounded_rectangle = .{
                .radius = options.units_per_pixel * 4.0,
            } },
            .collision_layer = .{
                .movement = true,
                .projectiles = true,
                .background = true,
            },
            .onCollision = onCollision,

            .metadata = .{
                .movability = .normal,
            },
        },
        .gun = undefined,
    };

    try scene.addGameObject(gpa, &outp.game_object);
    errdefer scene.removeGameObject(&outp.game_object);

    outp.gun = try objects.Gun.init(gpa, &outp.game_object);
    errdefer scene.removeGameObject(&outp.gun.game_object);

    return outp;
}

fn update(go: *GameObject, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    const player: *Player = @fieldParentPtr("game_object", go);
    const transform = &player.game_object.transform;

    if (scene.control_mode.game_object == .player) {
        try updateControlled(player, gpa, dt);
    }

    // The following code is only for debugging purposes
    // and to be removed whenever I get level loading to work.

    const mouse_pos_raylib = raylib.getMousePosition();
    const world_mouse_pos_raylib = raylib.getScreenToWorld2D(mouse_pos_raylib, scene.camera);
    const world_mouse_pos: Vec2 = .fromRaylib(world_mouse_pos_raylib);
    const phi = world_mouse_pos.subtract(transform.position).angle();
    _ = phi;

    if (raylib.isKeyPressed(.space)) {
        _ = try objects.dbg.Timer.init(gpa, 1.0, transform.position);
    }
    if (raylib.isKeyPressed(.kp_add)) {
        _ = try objects.dbg.Box.init(gpa, world_mouse_pos);
    }

    if (raylib.isMouseButtonPressed(.right) or raylib.isMouseButtonPressed(.middle)) player.dbg_click_start = world_mouse_pos;
    if (raylib.isMouseButtonReleased(.right)) {
        const radius = player.dbg_click_start.subtract(world_mouse_pos).len() * 2.0;
        if (radius > 0.0) {
            _ = try objects.dbg.Wall.init(gpa, player.dbg_click_start, .{ .circle = radius });
        }
    }
    if (raylib.isMouseButtonReleased(.middle)) {
        const size_signed = player.dbg_click_start.subtract(world_mouse_pos);
        if (size_signed.x != 0.0 and size_signed.y != 0.0) {
            const center = world_mouse_pos.add(size_signed.scale(0.5));
            _ = try objects.dbg.Wall.init(gpa, center, .{ .rectangle = size_signed.abs() });
        }
    }

    if (raylib.isKeyDown(.kp_9)) transform.rotation += std.math.pi / 2.0 * dt;
    if (raylib.isKeyDown(.kp_7)) transform.rotation -= std.math.pi / 2.0 * dt;

    if (raylib.isKeyPressed(.kp_enter)) {
        const font = raylib.getFontDefault() catch return error.Generic;
        _ = try objects.dbg.PushableText.init(gpa, "text :3", font, world_mouse_pos);
    }

    scene.camera.target = transform.position.toRaylib();
}
fn updateControlled(player: *Player, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    const go = &player.game_object;
    const transform = &go.transform;

    const mouse_pos_raylib = raylib.getMousePosition();
    const world_mouse_pos_raylib = raylib.getScreenToWorld2D(mouse_pos_raylib, scene.camera);
    const world_mouse_pos: Vec2 = .fromRaylib(world_mouse_pos_raylib);
    const phi = world_mouse_pos.subtract(transform.position).angle();

    var speed: Vec2 = .zero;
    if (raylib.isKeyDown(.a)) speed.x -= 1;
    if (raylib.isKeyDown(.d)) speed.x += 1;
    if (raylib.isKeyDown(.w)) speed.y -= 1;
    if (raylib.isKeyDown(.s)) speed.y += 1;
    speed = speed.normalizeSafe() orelse .zero;
    transform.position = transform.position.add(speed.scale(dt * velocity));

    player.gun.target_angle = phi;

    if (raylib.isMouseButtonPressed(.left)) {
        _ = try player.gun.shoot(gpa, velocity * 2.0, 5.0);
    }
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const player: *Player = @fieldParentPtr("game_object", go);
    gpa.destroy(player);
}

fn onCollision(self: *GameObject, other: *const GameObject, collision_info: Collision, gpa: Allocator) GameObject.UpdateError!void {
    _ = gpa;

    const player: *Player = @fieldParentPtr("game_object", self);

    const movement_factor: f32 = switch (other.metadata.movability) {
        .bullet => 0.0,
        .normal => collision_info.depth / 2.0,
        .immovable, .wall => collision_info.depth,
    };
    player.game_object.transform.position = player.game_object.transform.position.add(collision_info.normal.scale(movement_factor));

    //@import("../main.zig").log.debug("{d} {d}\t{d}", .{ collision_info.normal.x, collision_info.normal.y, collision_info.depth });
}
