const std = @import("std");
const raylib = @import("raylib");

const GameObject = @import("../GameObject.zig");

const Allocator = std.mem.Allocator;

const Player = @This();

const velocity = 1.0;

game_object: GameObject,

pub fn init(gpa: Allocator) Allocator.Error!*Player {
    const outp = try gpa.create(Player);
    errdefer gpa.destroy(outp);

    outp.game_object = .{
        .update = update,
        .deinit = deinit,
        .draw_order = .foreground,
        .draw = .{ .circle = .red },
    };

    return outp;
}

fn update(go: *GameObject, gpa: Allocator, dt: f32) GameObject.UpdateError!void {
    const player: *Player = @fieldParentPtr("game_object", go);

    if (raylib.isKeyDown(.a)) player.game_object.transform.position.x -= dt * velocity;
    if (raylib.isKeyDown(.d)) player.game_object.transform.position.x += dt * velocity;
    if (raylib.isKeyDown(.w)) player.game_object.transform.position.y -= dt * velocity;
    if (raylib.isKeyDown(.s)) player.game_object.transform.position.y += dt * velocity;

    if (raylib.isKeyPressed(.space)) {
        const dbg_timer = try @import("DbgTimer.zig").init(gpa, 1.0);
        errdefer dbg_timer.game_object.deinit(&dbg_timer.game_object, gpa);
        dbg_timer.game_object.transform.position = player.game_object.transform.position;
        try @import("../scene.zig").addGameObject(gpa, &dbg_timer.game_object);
    }
}

fn deinit(go: *GameObject, gpa: Allocator) void {
    const player: *Player = @fieldParentPtr("game_object", go);
    gpa.destroy(player);
}
