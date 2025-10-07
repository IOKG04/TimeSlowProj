const std = @import("std");
const raylib = @import("raylib");

const GameObject = @import("GameObject.zig");
const Vec2 = @import("Vec2.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const log = @import("main.zig").log;

var game_objects: ArrayList(*GameObject) = .empty;
var to_add: ArrayList(*GameObject) = .empty;
var to_remove: ArrayList(*GameObject) = .empty;

/// Scene takes ownership of `game_object`.
/// Will only take effect when `update` is called.
pub fn addGameObject(gpa: Allocator, game_object: *GameObject) Allocator.Error!void {
    try to_add.append(gpa, game_object);
}
/// If scene owns `game_object`, it will also be removed.
/// Will only take effect when `update` is called.
pub fn removeGameObject(gpa: Allocator, game_object: *GameObject) Allocator.Error!void {
    try to_remove.append(gpa, game_object);
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
    outer_remove: for (to_remove.items) |tr| {
        const idx = blk: {
            for (game_objects.items, 0..) |go, i| {
                if (go == tr) break :blk i;
            }
            continue :outer_remove;
        };
        const removed = game_objects.swapRemove(idx);
        removed.deinit(removed, gpa);
        log.debug("removed game_object {d}", .{idx});
    }
    to_remove.deinit(gpa);
    to_remove = .empty;

    if (to_add.items.len >= 1) {
        errdefer {
            for (to_add.items) |go| {
                go.deinit(go, gpa);
            }
        }
        try game_objects.appendSlice(gpa, to_add.items);
        log.debug("added game_object {d} - {d}", .{game_objects.items.len - to_add.items.len, game_objects.items.len - 1});
    }
    to_add.deinit(gpa);
    to_add = .empty;

    for (game_objects.items) |go| {
        if (go.paused) continue;
        const position = go.transform.position;
        const distance_from_cog = position.subtract(center_of_gravity).len();
        const time_stretch = @exp2(time_stretch_factor * distance_from_cog);
        try go.update(go, gpa, dt * time_stretch);
    }

    for (game_objects.items, 0..) |self, i| {
        if (self.paused or self.collider == .none or self.collision_layer.isNone()) continue;
        for (game_objects.items[(i + 1)..]) |other| {
            if (other.paused or other.collider == .none or other.collision_layer.isNone()) continue;

            const cinfo_self: GameObject.CollisionInfo, const cinfo_other: GameObject.CollisionInfo = blk: {
                const layers = self.collision_layer.collidingLayers(other.collision_layer) orelse continue;

                switch (self.collider) {
                    .circle => |sc_transform| switch (other.collider) {
                        .circle => |oc_transform| {
                            const sc_position = self.transform.position.add(sc_transform.position);
                            const oc_position = other.transform.position.add(oc_transform.position);
                            const dst = sc_position.subtract(oc_position).len();
                            const max_dst = (self.transform.scale.x * sc_transform.scale.x + other.transform.scale.x * oc_transform.scale.x) / 2.0;
                            const overlap = max_dst - dst;
                            if (overlap <= 0) continue else {
                                break :blk .{
                                    .{
                                        .layers = layers,
                                        .normal = sc_position.subtract(oc_position).normalizeSafe(),
                                        .depth = overlap,
                                    },
                                    .{
                                        .layers = layers,
                                        .normal = oc_position.subtract(sc_position).normalizeSafe(),
                                        .depth = overlap,
                                    },
                                };
                            }
                        },
                        .rectangle => log.err("colliding rectangles not yet implemented", .{}),
                        .none => unreachable,
                    },
                    .rectangle => log.err("colliding rectangles not yet implemented", .{}),
                    .none => unreachable,
                }

                continue;
            };

            try self.onCollision(self, other, cinfo_self, gpa);
            try other.onCollision(other, self, cinfo_other, gpa);
        }
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
                inline .circle, .circle_dbg => |color| {
                    const r = go.transform.scale.x / 2.0;
                    const center = go.transform.position;
                    const phi = go.transform.rotation;

                    raylib.drawCircleV(center.toRaylib(), r, color);

                    if (go.draw == .circle_dbg) raylib.drawLineV(center.toRaylib(), center.add(.fromPolar(phi, r * 1.5)).toRaylib(), color);
                },
            }
        }
    }
}
