const std = @import("std");
const math = std.math;
const raylib = @import("raylib");
const options = @import("options");

const collision_logic = @import("collision_logic.zig");
const GameObject = @import("GameObject.zig");
const Vec2 = @import("Vec2.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const log = @import("main.zig").log;

var game_objects: ArrayList(RemovableGameObject) = .empty;
var to_add: ArrayList(RemovableGameObject) = .empty;

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
}

/// Updates scene and game objects.
///
/// If `time_stretch_factor` is positive,
/// further objects are faster,
/// if it's zero, they'll all move the same,
/// if it's negative, they'll move slower.
pub fn update(gpa: Allocator, dt: f32, center_of_gravity: Vec2, time_stretch_factor: f32) UpdateError!void {
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

    for (game_objects.items) |rgo| {
        const go = rgo.game_object;
        if (go.paused) continue;
        const position = go.transform.position;
        const distance_from_cog = position.subtract(center_of_gravity).len();
        const time_stretch = @exp2(time_stretch_factor * distance_from_cog);
        try go.update(go, gpa, dt * time_stretch);
    }

    for (game_objects.items, 0..) |self_rgo, i| {
        const self = self_rgo.game_object;
        if (self.paused) continue;
        const self_layered_collider = collision_logic.LayeredCollider.fromGameObject(self.*) orelse continue;
        for (game_objects.items[(i + 1)..]) |other_rgo| {
            const other = other_rgo.game_object;
            if (other.paused) continue;
            const other_layered_collider = collision_logic.LayeredCollider.fromGameObject(other.*) orelse continue;

            const cinfo_self: GameObject.CollisionInfo, const cinfo_other: GameObject.CollisionInfo = collision_logic.getCollisionInfos(self_layered_collider, other_layered_collider) orelse continue; // Possibly add `@branchHint(.likely);` to the `continue` branch, considering most objects aren't colliding.

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
        for (game_objects.items) |rgo| {
            const go = rgo.game_object;
            if (go.draw_order != do) continue;

            drawObject(go.transform, go.draw);
        }
    }
}
fn drawObject(transform: GameObject.Transform, draw_object: GameObject.DrawObject) void {
    switch (draw_object) {
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
            texture.drawPro(
                .{
                    .x = 0,
                    .y = 0,
                    .width = @floatFromInt(texture.width),
                    .height = @floatFromInt(texture.height),
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

        .none => {},
    }
}

pub fn drawColliders() void {
    if (!options.draw_colliders) comptime unreachable; // This function doesn't need to exist if the option is off.

    for (game_objects.items) |rgo| {
        const go = rgo.game_object;
        const collider = (collision_logic.LayeredCollider.fromGameObject(go.*) orelse continue).collider;
        switch (collider) {
            .circle => |circle| {
                raylib.drawCircleLinesV(circle.position.toRaylib(), circle.radius, .green);
            },
            .rectangle => |rectangle| {
                const tr = rectangle.position.add(rectangle.scale.multiply(.{ .x = 0.5, .y = 0.5 }));
                const br = rectangle.position.add(rectangle.scale.multiply(.{ .x = 0.5, .y = -0.5 }));
                const tl = rectangle.position.add(rectangle.scale.multiply(.{ .x = -0.5, .y = 0.5 }));
                const bl = rectangle.position.add(rectangle.scale.multiply(.{ .x = -0.5, .y = -0.5 }));
                raylib.drawLineV(tr.toRaylib(), br.toRaylib(), .green);
                raylib.drawLineV(tr.toRaylib(), tl.toRaylib(), .green);
                raylib.drawLineV(bl.toRaylib(), br.toRaylib(), .green);
                raylib.drawLineV(bl.toRaylib(), tl.toRaylib(), .green);
            },
            .rounded_rectangle => |rounded_rectangle| {
                const size = rounded_rectangle.scale.subtract(.{ .x = 2.0 * rounded_rectangle.radius, .y = 2.0 * rounded_rectangle.radius });
                const tr = rounded_rectangle.position.add(size.multiply(.{ .x = 0.5, .y = 0.5 }));
                const br = rounded_rectangle.position.add(size.multiply(.{ .x = 0.5, .y = -0.5 }));
                const tl = rounded_rectangle.position.add(size.multiply(.{ .x = -0.5, .y = 0.5 }));
                const bl = rounded_rectangle.position.add(size.multiply(.{ .x = -0.5, .y = -0.5 }));
                for ([4]Vec2{ tr, tl, bl, br }, [4]Vec2{ tl, bl, br, tr }, [4]f32{ 0.0, 0.5, 1.0, 1.5 }) |corner, next, corner_angle_part| {
                    raylib.drawCircleSectorLines(
                        corner.toRaylib(),
                        rounded_rectangle.radius,
                        math.pi * (corner_angle_part + 0.0) * math.deg_per_rad,
                        math.pi * (corner_angle_part + 0.5) * math.deg_per_rad,
                        4,
                        .green,
                    );
                    const corner_ext = corner.add(.fromPolar(math.pi * (corner_angle_part + 0.5), rounded_rectangle.radius));
                    const next_ext = next.add(.fromPolar(math.pi * (corner_angle_part + 0.5), rounded_rectangle.radius));
                    raylib.drawLineV(corner_ext.toRaylib(), next_ext.toRaylib(), .green);
                }
            },
            .none => unreachable,
        }
    }
}

const RemovableGameObject = struct {
    game_object: *GameObject,
    removed: bool = false,
};
