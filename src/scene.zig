const std = @import("std");
const math = std.math;
const raylib = @import("raylib");
const options = @import("options");
const Vec2 = @import("Vec2");
const Collision = @import("Collision");
const LevelBackground = @import("LevelBackground");

const collision_logic = @import("collision_logic.zig");
const GameObject = @import("GameObject.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const log = std.log.scoped(.scene);

var background: ?LevelBackground = null;

var game_objects: ArrayList(RemovableGameObject) = .empty;
var to_add: ArrayList(RemovableGameObject) = .empty;

/// While currently this is public,
/// this should be replaced with a
/// camera controller some day.
pub var camera: raylib.Camera2D = .{
    .offset = .{ .x = @abs(options.window_w) / 2, .y = @abs(options.window_h) / 2 },
    .target = .{ .x = 0.0, .y = 0.0 },
    .rotation = 0.0,
    .zoom = @as(f32, @floatFromInt(options.window_h)) / 8.0,
};
/// `null` means no time stretching.
pub var center_of_gravity: ?*const Vec2 = null;
/// If positive, further objects are faster,
/// if zero, they'll all move the same,
/// if negative, they'll move slower.
pub var time_stretch_factor: f32 = -0.1;

/// The currently used control scheme.
///
/// If a game object's `update` function
/// gets called, the active field must
/// be `game_object`.
pub var control_mode: union (enum) {
    game_object: enum {
        /// Normal four-directional top-down
        /// player control scheme.
        player,
    },
    // TODO: textbox controls, etc.
} = .{ .game_object = .player };

/// Scene takes ownership of `game_object`.
/// Will only take effect when `update` is called.
///
/// Adding the same game object twice is IB.
pub fn addGameObject(gpa: Allocator, game_object: *GameObject) Allocator.Error!void {
    assert(not_owned: { // This will hopefully be optimized out..
        for (to_add.items) |rgo| {
            if (rgo.game_object == game_object) break :not_owned false;
        }
        for (game_objects.items) |rgo| {
            if (rgo.game_object == game_object) break :not_owned false;
        }
        break :not_owned true;
    });
    try to_add.append(gpa, .{ .game_object = game_object });
}
/// If scene owns `game_object`, it will be removed.
/// Will only take effect when `update` is called.
pub fn removeGameObject(game_object: *GameObject) void {
    for (game_objects.items) |*rgo| {
        if (rgo.game_object == game_object) {
            rgo.removed = true;
            return;
        }
    }
    for (to_add.items) |*rgo| {
        if (rgo.game_object == game_object) {
            rgo.removed = true;
            return;
        }
    }
}

/// Unload current background and replace it with
/// the one at `path`.
///
/// Returns an `UpdateError` so it can be easily
/// used from `update` functions.
pub fn loadBackground(gpa: Allocator, path: []const u8, origin: Vec2) GameObject.UpdateError!void {
    unloadBackground(gpa);
    background = LevelBackground.load(gpa, path, origin) catch |err| switch (err) {
        error.LoadTexture => return error.LoadTexture,
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.Generic,
    };
}
/// Unloads all resources associated with the current background.
pub fn unloadBackground(gpa: Allocator) void {
    if (background) |bg| {
        bg.unload(gpa);
    }
    background = null;
}

/// Deinitializes all game objects and the list containing them.
pub fn deinit(gpa: Allocator) void {
    for (game_objects.items) |rgo| {
        const go = rgo.game_object;
        go.deinit(go, gpa);
    }
    game_objects.deinit(gpa);
    game_objects = .empty;

    for (to_add.items) |rgo| {
        const go = rgo.game_object;
        go.deinit(go, gpa);
    }
    to_add.deinit(gpa);
    to_add = .empty;

    unloadBackground(gpa);

    control_mode = .{ .game_object = .player };
}

/// Updates scene and processes added and removed game objects.
pub fn update(gpa: Allocator, dt: f32) UpdateError!void {
    // Add game objects first, then remove them. This
    // should keep it from doing weird behaviour if
    // an object is both added and removed during the
    // same frame.
    if (to_add.items.len >= 1) {
        errdefer {
            for (to_add.items) |rgo| {
                const go = rgo.game_object;
                go.deinit(go, gpa);
            }
        }
        try game_objects.appendSlice(gpa, to_add.items);
        log.debug("added game_object {d} - {d}", .{game_objects.items.len - to_add.items.len, game_objects.items.len - 1});
    }
    to_add.deinit(gpa);
    to_add = .empty;

    { // remove removed objects
        var i: usize = 0;
        while (i < game_objects.items.len) {
            const rgo = game_objects.items[i];
            if (!rgo.removed) {
                i += 1;
                continue;
            }
            rgo.game_object.deinit(rgo.game_object, gpa);
            _ = game_objects.swapRemove(i);
            log.debug("removed game_object {d}", .{i});
        }
    }

    switch (control_mode) {
        .game_object => try updateGameObjects(gpa, dt),
    }
}
pub fn updateGameObjects(gpa: Allocator, dt: f32) UpdateError!void {
    assert(control_mode == .game_object);

    // Update game objects.
    for (game_objects.items) |rgo| {
        const go = rgo.game_object;
        if (go.paused) continue;
        const time_stretch: f32 = blk: {
            const cog = (center_of_gravity orelse break :blk 1).*;
            const position = go.transform.position;
            const distance_from_cog = position.subtract(cog).len();
            break :blk @exp2(time_stretch_factor * distance_from_cog);
        };
        try go.update(go, gpa, dt * time_stretch);
    }

    // Resolve collisions with background.
    if (background) |bg| {
        for (game_objects.items) |rgo| {
            const go = rgo.game_object;
            if (go.paused) continue;
            const go_layered_collider = collision_logic.LayeredCollider.fromGameObject(go.*) orelse continue;

            var max_depth: f32 = 0.0;
            var max_depth_idx: ?usize = null;
            var max_collision: ?Collision = null;

            for (0..bg.colliders.len) |idx| {
                const bg_collider = bg.getColliderIdx(idx);
                const bg_layered_collider: collision_logic.LayeredCollider = .{
                    .collider = bg_collider,
                    .layer = .background_preset,
                };

                const go_collision_info: Collision, _ = collision_logic.getCollisions(go_layered_collider, bg_layered_collider) orelse continue;

                if (go_collision_info.depth > max_depth) {
                    max_depth = go_collision_info.depth;
                    max_depth_idx = idx;
                    max_collision = go_collision_info;
                }
            }

            if (max_depth_idx) |idx| {
                const bg_as_go: GameObject = .{
                    .collider = bg.getColliderIdx(idx),
                    .collision_layer = .background_preset,
                    .metadata = .{
                        .movability = .wall,
                        .is_background = true,
                    },

                    .update = GameObject.no.update,
                    .deinit = GameObject.no.deinit,
                };
                try go.onCollision(go, &bg_as_go, max_collision.?, gpa);
            }
        }
    }

    // Resolve collisions.
    for (game_objects.items, 0..) |self_rgo, i| {
        const self = self_rgo.game_object;
        if (self.paused) continue;
        const self_layered_collider = collision_logic.LayeredCollider.fromGameObject(self.*) orelse continue;

        for (game_objects.items[(i + 1)..]) |other_rgo| {
            const other = other_rgo.game_object;
            if (other.paused) continue;
            const other_layered_collider = collision_logic.LayeredCollider.fromGameObject(other.*) orelse continue;

            const cinfo_self: Collision, const cinfo_other: Collision = collision_logic.getCollisions(self_layered_collider, other_layered_collider) orelse continue; // Possibly add `@branchHint(.likely);` to the `continue` branch, considering most objects aren't colliding.

            try self.onCollision(self, other, cinfo_self, gpa);
            try other.onCollision(other, self, cinfo_other, gpa);
        }
    }
}
pub const UpdateError = GameObject.UpdateError || Allocator.Error;

/// Draws all game objects in scene.
pub fn draw() void {
    camera.begin();
    defer camera.end();

    for (GameObject.DrawOrder.draw_order) |do| {
        for (game_objects.items) |rgo| {
            const go = rgo.game_object;
            if (go.draw_order != do) continue;

            drawObject(go);
        }
    }

    if (background) |bg| {
        bg.texture.drawEx(bg.origin.toRaylib(), 0.0, options.units_per_pixel, .white);
    }
}
fn drawObject(go: *GameObject) void {
    const transform = go.transform;
    const draw_object = go.draw;

    draw_switch: switch (draw_object) {
        .none => {},

        .texture => |texture| {
            texture.drawPro(
                .{
                    .x = 0,
                    .y = 0,
                    .width = @floatFromInt(texture.width),
                    .height = @floatFromInt(texture.height),
                },
                .{
                    .x = transform.position.x,
                    .y = transform.position.y,
                    .width = transform.scale.x,
                    .height = transform.scale.y,
                },
                transform.scale.scale(0.5).toRaylib(),
                transform.rotation * std.math.deg_per_rad,
                .white,
            );
        },
        .texture_transformed => |texture_transformed| {
            const texture = texture_transformed.texture;
            const texture_transform: GameObject.Transform = .{
                .position = texture_transformed.transform.position.multiply(transform.scale).rotate(transform.rotation).add(transform.position),
                .rotation = texture_transformed.transform.rotation + transform.rotation,
                .scale = texture_transformed.transform.scale.multiply(transform.scale),
            };
            const flipped = texture_transformed.flipped;
            texture.drawPro(
                .{
                    .x = 0,
                    .y = 0,
                    .width = @floatFromInt(if (flipped.horizontal) -texture.width else texture.width),
                    .height = @floatFromInt(if (flipped.vertical) -texture.height else texture.height),
                },
                .{
                    .x = texture_transform.position.x,
                    .y = texture_transform.position.y,
                    .width = texture_transform.scale.x,
                    .height = texture_transform.scale.y,
                },
                texture_transform.scale.scale(0.5).toRaylib(),
                texture_transform.rotation * std.math.deg_per_rad,
                .white,
            );
        },

        inline .circle, .circle_dbg => |color| {
            const r = transform.scale.x / 2.0;
            const center = transform.position;
            const phi = transform.rotation;

            raylib.drawCircleV(center.toRaylib(), r, color);

            if (draw_object == .circle_dbg) raylib.drawLineV(center.toRaylib(), center.add(.fromPolar(phi, r * 1.5)).toRaylib(), color);
        },
        .rectangle => |color| {
            raylib.drawRectanglePro(
                .{
                    .x = transform.position.x,
                    .y = transform.position.y,
                    .width = transform.scale.x,
                    .height = transform.scale.y,
                },
                transform.scale.scale(0.5).toRaylib(),
                transform.rotation * std.math.deg_per_rad,
                color,
            );
        },

        .custom => |custom| {
            const result = custom(go);
            assert(result != .custom);
            continue :draw_switch result;
        },
    }
}

pub fn drawColliders() void {
    camera.begin();
    defer camera.end();

    if (background) |bg| {
        for (0..bg.colliders.len) |idx| {
            const collider = bg.getColliderIdx(idx);
            collider.draw(.red);
        }
    }

    for (game_objects.items) |rgo| {
        const go = rgo.game_object;
        const collider = (collision_logic.LayeredCollider.fromGameObject(go.*) orelse continue).collider;
        collider.draw(.green);
    }
}

const RemovableGameObject = struct {
    game_object: *GameObject,
    removed: bool = false,
};
