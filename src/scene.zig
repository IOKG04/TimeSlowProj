const std = @import("std");
const raylib = @import("raylib");

const GameObject = @import("GameObject.zig");
const Vec2 = @import("Vec2.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const log = @import("main.zig").log;

var game_objects: ArrayList(*GameObject) = .empty;
var to_add: ArrayList(*GameObject) = .empty;
var to_remove: ArrayList(usize) = .empty;

/// Scene takes ownership of `game_object`.
/// Will only take effect when `update` is called.
pub fn addGameObject(gpa: Allocator, game_object: *GameObject) Allocator.Error!void {
    errdefer game_object.deinit(game_object, gpa);
    try to_add.append(gpa, game_object);
}
/// `game_object` will definitely be deinitialized.
/// If scene owns `game_object`, it will also be removed.
/// Will only take effect when `update` is called.
pub fn removeGameObject(gpa: Allocator, game_object: *GameObject) Allocator.Error!void {
    game_object.deinit(gpa);
    const idx = blk: {
        for (game_objects.items, 0..) |go, i| {
            if (go == game_object) break :blk i;
        }
        return;
    };
    try to_remove.append(gpa, idx);
}

/// Deinitializes all game objects and the list containing them.
pub fn deinit(gpa: Allocator) void {
    for (game_objects.items) |go| {
        go.deinit(go, gpa);
    }
    game_objects.deinit(gpa);
    game_objects = .empty;

    for (to_add.items) |go| {
        go.deinit(go, gpa);
    }
    to_add.deinit(gpa);
    to_add = .empty;

    to_remove.deinit(gpa);
    to_remove = .empty;
}

/// Updates scene and game objects.
///
/// If `time_stretch_factor` is positive,
/// further objects are faster,
/// if it's zero, they'll all move the same,
/// if it's negative, they'll move slower.
pub fn update(gpa: Allocator, dt: f32, center_of_gravity: Vec2, time_stretch_factor: f32) UpdateError!void {
    { // do this to ensure the game objects to add get deinitialized even if the append fails
        errdefer {
            for (to_add.items) |go| {
                go.deinit(go, gpa);
            }
        }
        try game_objects.appendSlice(gpa, to_add.items);
    }
    to_add.deinit(gpa);
    to_add = .empty;

    for (to_remove.items) |tr| {
        _ = game_objects.swapRemove(tr);
    }
    to_remove.deinit(gpa);
    to_remove = .empty;

    for (game_objects.items) |go| {
        if (go.paused) continue;
        const position = go.transform.position;
        const distance_from_cog = position.subtract(center_of_gravity).len();
        const time_stretch = @exp(time_stretch_factor * distance_from_cog);
        try go.update(go, gpa, dt * time_stretch);
    }
}
pub const UpdateError = GameObject.UpdateError || Allocator.Error;

/// Draws game objects in scene.
pub fn draw() void {
    const draw_order: [3]GameObject.DrawOrder = .{
        .background,
        .default,
        .foreground,
    };
    for (draw_order) |do| {
        for (game_objects.items) |go| {
            if (go.draw_order != do) continue;

            switch (go.draw) {
                .none => {},
                .texture => log.err("drawing textures not yet implemented", .{}),
                .circle => |color| raylib.drawCircleV(go.transform.position.toRaylib(), go.transform.scale.x / 2.0, color),
            }
        }
    }
}
